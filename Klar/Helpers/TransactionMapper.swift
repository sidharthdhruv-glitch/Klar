import Foundation

/// Maps raw spreadsheet rows (headers + cell values) into ParsedRow objects.
/// Uses fuzzy header matching to auto-detect column positions for Indian bank statements.
struct TransactionMapper {

    // MARK: - Column Role Detection

    /// The role of each column, detected from header text.
    enum ColumnRole {
        case date
        case description
        case debit
        case credit
        case amount       // Single amount column (debit/credit combined)
        case balance
        case ignored
    }

    /// Mapping result returned to callers.
    struct MappingResult {
        let transactions: [StatementParser.ParsedRow]
        let skippedRows: Int
        let warnings: [String]
        let totalRows: Int
    }

    // MARK: - Header Keyword Maps

    /// Keywords that identify each column role. Case-insensitive matching.
    private static let dateKeywords = ["date", "txn date", "transaction date", "trans date",
                                        "value date", "posting date", "txn_date", "valuedate"]
    private static let descriptionKeywords = ["narration", "description", "particulars", "details",
                                               "remarks", "transaction details", "narrative",
                                               "merchant", "payee", "reference"]
    private static let debitKeywords = ["debit", "withdrawal", "dr", "debit amount",
                                         "withdrawal amount", "dr.", "debit(inr)", "withdrawals"]
    private static let creditKeywords = ["credit", "deposit", "cr", "credit amount",
                                          "deposit amount", "cr.", "credit(inr)", "deposits"]
    private static let amountKeywords = ["amount", "transaction amount", "txn amount"]
    private static let balanceKeywords = ["balance", "closing balance", "running balance",
                                           "available balance", "bal"]

    // MARK: - Public API

    /// Maps raw spreadsheet data (headers + rows of strings) to transactions.
    /// Auto-detects column positions using fuzzy header matching.
    static func map(headers: [String], rows: [[String]]) -> MappingResult {
        let columnMap = detectColumns(headers: headers)

        // Validate we have minimum required columns
        let hasDate = columnMap.contains(where: { $0.value == .date })
        let hasDescription = columnMap.contains(where: { $0.value == .description })
        let hasAmount = columnMap.contains(where: {
            $0.value == .debit || $0.value == .credit || $0.value == .amount
        })

        var warnings: [String] = []
        if !hasDate { warnings.append("No date column detected. Rows without dates will be skipped.") }
        if !hasDescription { warnings.append("No description/narration column detected.") }
        if !hasAmount { warnings.append("No amount column detected.") }

        var transactions: [StatementParser.ParsedRow] = []
        var skipped = 0

        for row in rows {
            if let parsed = parseRow(row, columnMap: columnMap) {
                transactions.append(parsed)
            } else {
                skipped += 1
            }
        }

        return MappingResult(
            transactions: transactions,
            skippedRows: skipped,
            warnings: warnings,
            totalRows: rows.count
        )
    }

    // MARK: - Column Detection

    /// Builds a mapping of column index → role by fuzzy-matching header text.
    private static func detectColumns(headers: [String]) -> [Int: ColumnRole] {
        var map: [Int: ColumnRole] = [:]

        for (index, header) in headers.enumerated() {
            let normalized = header.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: ".", with: "")

            if matchesAny(normalized, keywords: dateKeywords) {
                // Only take the first date column as the primary date
                if !map.values.contains(.date) {
                    map[index] = .date
                }
            } else if matchesAny(normalized, keywords: debitKeywords) {
                map[index] = .debit
            } else if matchesAny(normalized, keywords: creditKeywords) {
                map[index] = .credit
            } else if matchesAny(normalized, keywords: amountKeywords) {
                // Only use "amount" if we haven't found separate debit/credit
                if !map.values.contains(.debit) && !map.values.contains(.credit) {
                    map[index] = .amount
                }
            } else if matchesAny(normalized, keywords: balanceKeywords) {
                map[index] = .balance
            } else if matchesAny(normalized, keywords: descriptionKeywords) {
                // Take the first description column
                if !map.values.contains(.description) {
                    map[index] = .description
                }
            } else {
                map[index] = .ignored
            }
        }

        return map
    }

    /// Checks if the normalized header text contains any of the keywords.
    private static func matchesAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains { keyword in
            text == keyword || text.contains(keyword)
        }
    }

    // MARK: - Row Parsing

    /// Parses a single row into a ParsedRow using the detected column mapping.
    /// Returns nil if the row lacks essential data (date or amount).
    private static func parseRow(_ cells: [String], columnMap: [Int: ColumnRole]) -> StatementParser.ParsedRow? {
        var dateValue: Date?
        var description = ""
        var debitAmount: Double?
        var creditAmount: Double?
        var singleAmount: Double?

        for (index, role) in columnMap {
            guard index < cells.count else { continue }
            let cell = cells[index].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cell.isEmpty else { continue }

            switch role {
            case .date:
                dateValue = DateParser.parse(cell)
            case .description:
                description = cell
            case .debit:
                debitAmount = parseAmount(cell)
            case .credit:
                creditAmount = parseAmount(cell)
            case .amount:
                singleAmount = parseAmount(cell)
            case .balance, .ignored:
                break
            }
        }

        // Must have a valid date
        guard let date = dateValue else { return nil }

        // Determine amount and type
        let amount: Double
        let type: TransactionType

        if let debit = debitAmount, debit > 0 {
            amount = debit
            type = .expense
        } else if let credit = creditAmount, credit > 0 {
            amount = credit
            type = .income
        } else if let single = singleAmount {
            // Negative values → expense, positive → income
            if single < 0 {
                amount = abs(single)
                type = .expense
            } else {
                amount = single
                type = .income
            }
        } else {
            // No valid amount found — skip this row
            return nil
        }

        // Clean up description
        let cleanDesc = description.isEmpty ? "Unknown Transaction" : cleanDescription(description)

        return StatementParser.ParsedRow(
            date: date,
            description: cleanDesc,
            amount: amount,
            type: type
        )
    }

    // MARK: - Amount Parsing

    /// Parses an amount string, handling Indian number formats (1,57,370.00),
    /// currency symbols (₹, Rs.), negative markers, and trailing Cr/Dr.
    private static func parseAmount(_ string: String) -> Double? {
        var cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned != "-", cleaned != "--" else { return nil }

        // Track if this should be negative
        var isNegative = false

        // Handle parenthesized negatives: (1,234.56)
        if cleaned.hasPrefix("(") && cleaned.hasSuffix(")") {
            cleaned = String(cleaned.dropFirst().dropLast())
            isNegative = true
        }

        // Handle trailing markers
        let upper = cleaned.uppercased()
        if upper.hasSuffix("DR") || upper.hasSuffix("DR.") || upper.hasSuffix("(-)") {
            isNegative = true
        }

        // Remove currency symbols and non-numeric chars (except digits, dots, commas, minus)
        cleaned = cleaned
            .replacingOccurrences(of: "₹", with: "")
            .replacingOccurrences(of: "Rs.", with: "")
            .replacingOccurrences(of: "Rs", with: "")
            .replacingOccurrences(of: "INR", with: "")
            .replacingOccurrences(of: "CR", with: "")
            .replacingOccurrences(of: "Cr", with: "")
            .replacingOccurrences(of: "DR", with: "")
            .replacingOccurrences(of: "Dr", with: "")
            .replacingOccurrences(of: "(-)", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .punctuationCharacters.subtracting(.init(charactersIn: ".-")))

        // Handle leading minus sign
        if cleaned.hasPrefix("-") {
            isNegative = true
            cleaned = String(cleaned.dropFirst())
        }

        // Remove thousands separators (commas in Indian format: 1,57,370.00)
        cleaned = cleaned.replacingOccurrences(of: ",", with: "")

        guard let value = Double(cleaned), value.isFinite else { return nil }
        return isNegative ? -value : value
    }

    // MARK: - Description Cleaning

    /// Cleans transaction descriptions by removing excessive whitespace and bank codes.
    private static func cleanDescription(_ text: String) -> String {
        // Collapse multiple spaces/tabs into single space
        let collapsed = text.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
