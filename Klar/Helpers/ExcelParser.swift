import Foundation
import CoreXLSX

/// Parses XLSX files using CoreXLSX. Reads all worksheets, handles shared strings,
/// and extracts cell values safely without skipping rows.
struct ExcelParser {

    /// Errors specific to Excel parsing.
    enum ExcelError: LocalizedError {
        case cannotOpenFile(String)
        case noWorksheets
        case emptyWorksheet
        case noHeaderRow
        case sharedStringsMissing

        var errorDescription: String? {
            switch self {
            case .cannotOpenFile(let path):
                return "Cannot open Excel file at: \(path)"
            case .noWorksheets:
                return "The Excel file contains no worksheets."
            case .emptyWorksheet:
                return "The worksheet is empty."
            case .noHeaderRow:
                return "No header row found in the worksheet."
            case .sharedStringsMissing:
                return "Shared strings table is missing from the Excel file."
            }
        }
    }

    /// Result of parsing an Excel file — same structure as CSVParser for interoperability.
    struct ExcelResult {
        let headers: [String]
        let rows: [[String]]
        let sheetName: String
    }

    // MARK: - Public API

    /// Parses all worksheets from an XLSX file and returns the one with the most data rows.
    /// This handles multi-sheet files where the statement may not be on the first sheet.
    static func parse(url: URL) throws -> ExcelResult {
        guard let file = XLSXFile(filepath: url.path) else {
            throw ExcelError.cannotOpenFile(url.path)
        }

        let sharedStrings = try file.parseSharedStrings()
        let workbooks = try file.parseWorkbooks()

        var bestResult: ExcelResult?
        var bestRowCount = 0

        for workbook in workbooks {
            for (name, path) in try file.parseWorksheetPathsAndNames(workbook: workbook) {
                let worksheet = try file.parseWorksheet(at: path)
                if let result = parseWorksheet(worksheet, sheetName: name ?? "Sheet",
                                                sharedStrings: sharedStrings),
                   result.rows.count > bestRowCount {
                    bestResult = result
                    bestRowCount = result.rows.count
                }
            }
        }

        guard let result = bestResult else {
            throw ExcelError.noWorksheets
        }
        return result
    }

    /// Parses all worksheets and returns results for each.
    static func parseAllSheets(url: URL) throws -> [ExcelResult] {
        guard let file = XLSXFile(filepath: url.path) else {
            throw ExcelError.cannotOpenFile(url.path)
        }

        let sharedStrings = try file.parseSharedStrings()
        let workbooks = try file.parseWorkbooks()
        var results: [ExcelResult] = []

        for workbook in workbooks {
            for (name, path) in try file.parseWorksheetPathsAndNames(workbook: workbook) {
                let worksheet = try file.parseWorksheet(at: path)
                if let result = parseWorksheet(worksheet, sheetName: name ?? "Sheet",
                                                sharedStrings: sharedStrings) {
                    results.append(result)
                }
            }
        }

        return results
    }

    // MARK: - Worksheet Parsing

    /// Extracts headers and data rows from a single worksheet.
    private static func parseWorksheet(_ worksheet: Worksheet,
                                        sheetName: String,
                                        sharedStrings: SharedStrings?) -> ExcelResult? {
        guard let rows = worksheet.data?.rows, !rows.isEmpty else { return nil }

        // Find the maximum column count across all rows for consistent padding
        let maxColumns = rows.map { $0.cells.count }.max() ?? 0
        guard maxColumns > 0 else { return nil }

        var allRowValues: [[String]] = []

        for row in rows {
            var values: [String] = Array(repeating: "", count: maxColumns)
            for cell in row.cells {
                guard let colIndex = columnIndex(from: cell.reference) else { continue }
                let value = cellValue(cell, sharedStrings: sharedStrings)
                if colIndex < maxColumns {
                    values[colIndex] = value
                }
            }
            allRowValues.append(values)
        }

        // Find the header row: first row that has at least 3 non-empty cells
        guard let headerIdx = allRowValues.firstIndex(where: { row in
            row.filter({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }).count >= 3
        }) else { return nil }

        let headers = allRowValues[headerIdx].map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let dataRows = Array(allRowValues[(headerIdx + 1)...]).filter { row in
            !row.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        }

        guard !dataRows.isEmpty else { return nil }

        return ExcelResult(headers: headers, rows: dataRows, sheetName: sheetName)
    }

    // MARK: - Cell Value Extraction

    /// Extracts the string value from a cell, resolving shared strings if needed.
    private static func cellValue(_ cell: Cell, sharedStrings: SharedStrings?) -> String {
        // Shared string type
        if cell.type == .sharedString,
           let stringIndex = cell.value.flatMap(Int.init),
           let sharedStrings = sharedStrings {
            let items = sharedStrings.items
            guard stringIndex < items.count else { return cell.value ?? "" }
            // Concatenate all text runs in the shared string
            let text = items[stringIndex].text
                ?? items[stringIndex].richText?.map { $0.text ?? "" }.joined()
                ?? ""
            return text
        }

        // Inline string
        if let inlineStr = cell.inlineString?.text {
            return inlineStr
        }

        // Direct value (number, formula result, etc.)
        return cell.value ?? ""
    }

    // MARK: - Column Index Mapping

    /// Converts an Excel cell reference (e.g. "C5") to a zero-based column index.
    private static func columnIndex(from reference: CellReference) -> Int? {
        let refString = reference.column.value
        var index = 0
        for char in refString.uppercased() {
            guard let asciiValue = char.asciiValue, asciiValue >= 65, asciiValue <= 90 else {
                return nil
            }
            index = index * 26 + Int(asciiValue - 64)
        }
        return index - 1 // Zero-based
    }
}
