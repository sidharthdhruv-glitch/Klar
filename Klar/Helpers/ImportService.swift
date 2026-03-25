import Foundation

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

    // MARK: - Public API

    /// Imports transactions from a file URL. Auto-detects format and parses accordingly.
    /// Must be called from a background context (async).
    func importFile(at url: URL) async throws -> ImportResult {
        // Start accessing security-scoped resource
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let fileName = url.lastPathComponent

        // Detect file type by content (magic bytes), not just extension
        let fileType = Self.detectFileType(at: url)

        switch fileType {
        case .xlsx:
            return try await importExcel(url: url, fileName: fileName)
        case .csv:
            return try await importCSV(url: url, fileName: fileName)
        default:
            // Fallback: try CSV parsing for unknown types
            return try await importCSV(url: url, fileName: fileName)
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
