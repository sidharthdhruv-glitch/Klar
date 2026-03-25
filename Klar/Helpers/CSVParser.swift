import Foundation

/// Lightweight CSV parser with no external dependencies.
/// Handles comma separation, quoted strings, embedded commas, newlines in quotes, and empty cells.
struct CSVParser {

    /// A single parsed row as an array of string cell values.
    typealias Row = [String]

    /// Errors specific to CSV parsing.
    enum CSVError: LocalizedError {
        case emptyFile
        case noHeaderRow
        case encodingError

        var errorDescription: String? {
            switch self {
            case .emptyFile: return "The CSV file is empty."
            case .noHeaderRow: return "No header row found in the CSV file."
            case .encodingError: return "Could not read the file. Unsupported text encoding."
            }
        }
    }

    /// Result of parsing a CSV file.
    struct CSVResult {
        let headers: [String]
        let rows: [Row]
    }

    // MARK: - Public API

    /// Parses a CSV file at the given URL. Auto-detects the delimiter.
    static func parse(url: URL) throws -> CSVResult {
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) else {
            throw CSVError.encodingError
        }
        return try parse(content: content)
    }

    /// Parses CSV content from a string. Auto-detects the delimiter.
    static func parse(content: String) throws -> CSVResult {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CSVError.emptyFile }

        let delimiter = detectDelimiter(trimmed)
        let allRows = parseRows(trimmed, delimiter: delimiter)

        guard let headers = allRows.first, !headers.isEmpty else {
            throw CSVError.noHeaderRow
        }

        let dataRows = Array(allRows.dropFirst()).filter { row in
            // Skip entirely empty rows
            !row.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        }

        return CSVResult(
            headers: headers.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
            rows: dataRows
        )
    }

    // MARK: - Delimiter Detection

    /// Detects the most likely delimiter by counting occurrences in the first few lines.
    private static func detectDelimiter(_ content: String) -> Character {
        let candidates: [Character] = [",", "\t", "|", ";"]
        // Sample the first 5 lines
        let sampleLines = content.components(separatedBy: .newlines).prefix(5).joined()

        var best: Character = ","
        var bestCount = 0
        for candidate in candidates {
            let count = sampleLines.filter { $0 == candidate }.count
            if count > bestCount {
                bestCount = count
                best = candidate
            }
        }
        return best
    }

    // MARK: - RFC 4180 Compliant Parsing

    /// Parses all rows respecting quoted fields (which may contain delimiters and newlines).
    private static func parseRows(_ content: String, delimiter: Character) -> [Row] {
        var rows: [Row] = []
        var currentRow: Row = []
        var currentField = ""
        var inQuotes = false
        let chars = Array(content)
        var i = 0

        while i < chars.count {
            let c = chars[i]

            if inQuotes {
                if c == "\"" {
                    // Check for escaped quote ("")
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                        continue
                    } else {
                        // End of quoted field
                        inQuotes = false
                        i += 1
                        continue
                    }
                } else {
                    currentField.append(c)
                    i += 1
                    continue
                }
            }

            // Not in quotes
            if c == "\"" {
                inQuotes = true
                i += 1
            } else if c == delimiter {
                currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
                i += 1
            } else if c == "\r" || c == "\n" {
                // Handle \r\n
                if c == "\r" && i + 1 < chars.count && chars[i + 1] == "\n" {
                    i += 1
                }
                currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
                rows.append(currentRow)
                currentRow = []
                i += 1
            } else {
                currentField.append(c)
                i += 1
            }
        }

        // Don't forget the last field/row
        currentRow.append(currentField.trimmingCharacters(in: .whitespaces))
        if !currentRow.allSatisfy({ $0.isEmpty }) {
            rows.append(currentRow)
        }

        return rows
    }
}
