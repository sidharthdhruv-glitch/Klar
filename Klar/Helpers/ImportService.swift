import Foundation
import UniformTypeIdentifiers

/// Orchestrates the Excel/CSV import pipeline.
/// Detects file type, delegates to the appropriate parser, maps to transactions,
/// and returns a unified result. All parsing runs off the main thread.
actor ImportService {

    // MARK: - Import Errors

    enum ImportError: LocalizedError {
        case unsupportedFormat(String)
        case emptyResult
        case missingRequiredColumns([String])
        case fileAccessDenied(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat(let ext):
                return "Unsupported file format: .\(ext). Please use .xlsx, .xls, or .csv files."
            case .emptyResult:
                return "No transactions found in the file. Please check the file contents."
            case .missingRequiredColumns(let missing):
                return "Missing required columns: \(missing.joined(separator: ", "))."
            case .fileAccessDenied(let path):
                return "Cannot access file at: \(path). Please try re-selecting the file."
            }
        }
    }

    // MARK: - Import Result

    struct ImportResult: Sendable {
        let transactions: [StatementParser.ParsedRow]
        let totalRowsParsed: Int
        let skippedRows: Int
        let warnings: [String]
        let source: ImportSource
        let fileName: String
    }

    // MARK: - Supported File Types

    /// UTTypes for the file picker.
    static let supportedTypes: [UTType] = [
        .commaSeparatedText,                     // .csv
        UTType("org.openxmlformats.spreadsheetml.sheet") ?? .data,  // .xlsx
        UTType("com.microsoft.excel.xls") ?? .data,                 // .xls
        .spreadsheet,                            // generic spreadsheet
    ]

    // MARK: - Public API

    /// Imports transactions from a file URL. Auto-detects format and parses accordingly.
    /// Must be called from a background context (async).
    func importFile(at url: URL) async throws -> ImportResult {
        // Start accessing security-scoped resource
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let ext = url.pathExtension.lowercased()
        let fileName = url.lastPathComponent

        switch ext {
        case "csv", "txt":
            return try await importCSV(url: url, fileName: fileName)
        case "xlsx":
            return try await importExcel(url: url, fileName: fileName)
        case "xls":
            // CoreXLSX doesn't support legacy .xls format.
            // Try parsing as CSV in case it's actually tab-separated or misnamed.
            return try await importCSV(url: url, fileName: fileName)
        default:
            throw ImportError.unsupportedFormat(ext)
        }
    }

    /// Detects whether a file is Excel or CSV based on content, not just extension.
    static func detectFileType(at url: URL) -> ImportSource {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "xlsx", "xls": return .xlsx
        case "csv", "txt": return .csv
        default:
            // Try reading magic bytes — XLSX files are ZIP archives starting with PK
            if let data = try? Data(contentsOf: url, options: .mappedIfSafe),
               data.count >= 4 {
                let pk: [UInt8] = [0x50, 0x4B, 0x03, 0x04]
                let header = [UInt8](data.prefix(4))
                if header == pk { return .xlsx }
            }
            return .csv
        }
    }

    // MARK: - CSV Import

    private func importCSV(url: URL, fileName: String) async throws -> ImportResult {
        let csvResult = try CSVParser.parse(url: url)
        let mapping = TransactionMapper.map(headers: csvResult.headers, rows: csvResult.rows)

        if mapping.transactions.isEmpty && mapping.totalRows > 0 {
            throw ImportError.emptyResult
        }

        return ImportResult(
            transactions: mapping.transactions,
            totalRowsParsed: mapping.totalRows,
            skippedRows: mapping.skippedRows,
            warnings: mapping.warnings,
            source: .csv,
            fileName: fileName
        )
    }

    // MARK: - Excel Import

    private func importExcel(url: URL, fileName: String) async throws -> ImportResult {
        let excelResult = try ExcelParser.parse(url: url)
        let mapping = TransactionMapper.map(headers: excelResult.headers, rows: excelResult.rows)

        if mapping.transactions.isEmpty && mapping.totalRows > 0 {
            throw ImportError.emptyResult
        }

        return ImportResult(
            transactions: mapping.transactions,
            totalRowsParsed: mapping.totalRows,
            skippedRows: mapping.skippedRows,
            warnings: mapping.warnings,
            source: .xlsx,
            fileName: fileName
        )
    }
}
