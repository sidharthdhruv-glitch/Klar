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

    /// Detects whether a file is XLSX or CSV/text based on content (magic bytes).
    /// Many Indian bank portals export HTML tables or CSV data with a .xls extension,
    /// so we always check the actual file content rather than trusting the extension.
    static func detectFileType(at url: URL) -> ImportSource {
        // Always check magic bytes first — file extensions can lie
        if let data = try? Data(contentsOf: url, options: .mappedIfSafe),
           data.count >= 4 {
            let header = [UInt8](data.prefix(4))
            // ZIP archive (PK\x03\x04) → real XLSX
            if header[0] == 0x50, header[1] == 0x4B, header[2] == 0x03, header[3] == 0x04 {
                return .xlsx
            }
        }
        // Everything else (CSV, .xls HTML tables, tab-delimited, etc.) → parse as CSV
        return .csv
    }

    // MARK: - CSV Import

    private func importCSV(url: URL, fileName: String) async throws -> ImportResult {
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) else {
            throw ImportError.unsupportedFormat("unknown encoding")
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Many Indian bank portals (HDFC, ICICI, SBI) export .xls files that are
        // actually HTML tables. Detect and parse HTML content.
        if trimmed.lowercased().contains("<table") || trimmed.lowercased().contains("<html") {
            return try importHTMLTable(content: trimmed, fileName: fileName)
        }

        let csvResult = try CSVParser.parse(content: content)
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

    // MARK: - HTML Table Import

    /// Parses HTML table content (common in .xls exports from Indian bank portals).
    /// Extracts <tr>/<td> content and maps it through TransactionMapper.
    private func importHTMLTable(content: String, fileName: String) throws -> ImportResult {
        var rows: [[String]] = []
        let tablePattern = try NSRegularExpression(pattern: "<tr[^>]*>(.*?)</tr>",
            options: [.caseInsensitive, .dotMatchesLineSeparators])
        let cellPattern = try NSRegularExpression(pattern: "<t[dh][^>]*>(.*?)</t[dh]>",
            options: [.caseInsensitive, .dotMatchesLineSeparators])

        let nsContent = content as NSString
        let trMatches = tablePattern.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

        for trMatch in trMatches {
            let trContent = nsContent.substring(with: trMatch.range(at: 1))
            let nsTR = trContent as NSString
            let cellMatches = cellPattern.matches(in: trContent, range: NSRange(location: 0, length: nsTR.length))

            var cells: [String] = []
            for cellMatch in cellMatches {
                var cellText = nsTR.substring(with: cellMatch.range(at: 1))
                // Strip nested HTML tags
                cellText = cellText.replacingOccurrences(of: "<[^>]+>", with: "",
                    options: .regularExpression)
                // Decode common HTML entities
                cellText = cellText
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&nbsp;", with: " ")
                    .replacingOccurrences(of: "&#160;", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                cells.append(cellText)
            }

            if !cells.allSatisfy({ $0.isEmpty }) {
                rows.append(cells)
            }
        }

        guard let headers = rows.first, !headers.isEmpty else {
            throw ImportError.emptyResult
        }

        let dataRows = Array(rows.dropFirst())
        let mapping = TransactionMapper.map(headers: headers, rows: dataRows)

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
