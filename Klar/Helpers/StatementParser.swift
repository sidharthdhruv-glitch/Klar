import Foundation
import PDFKit
import SwiftData

// MARK: - Statement Parser
/// Parses bank statements (PDF and CSV) into transactions with auto-categorization.
actor StatementParser {

    // MARK: - Parsed Row
    struct ParsedRow: Sendable {
        let date: Date
        let description: String
        let amount: Double
        let type: TransactionType
    }

    // MARK: - Parse Result
    struct ParseResult: Sendable {
        let transactions: [ParsedRow]
        let errors: [String]
        let fileName: String
    }

    // MARK: - Public API

    /// Parse a file at the given URL. Supports PDF and CSV.
    func parseFile(at url: URL, accountName: String) async throws -> ParseResult {
        let ext = url.pathExtension.lowercased()
        let fileName = url.lastPathComponent

        guard url.startAccessingSecurityScopedResource() else {
            throw ParserError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let data = try Data(contentsOf: url)

        switch ext {
        case "pdf":
            return try parsePDF(data: data, fileName: fileName)
        case "csv":
            return try parseCSV(data: data, fileName: fileName)
        default:
            throw ParserError.unsupportedFormat(ext)
        }
    }

    // MARK: - PDF Parsing

    private func parsePDF(data: Data, fileName: String) throws -> ParseResult {
        guard let document = PDFDocument(data: data) else {
            throw ParserError.invalidPDF
        }

        var allText = ""
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            if let pageText = page.string {
                allText += pageText + "\n"
            }
        }

        guard !allText.isEmpty else {
            throw ParserError.noTextContent
        }

        let lines = allText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var transactions: [ParsedRow] = []
        var errors: [String] = []

        for line in lines {
            if let parsed = parseTransactionLine(line) {
                transactions.append(parsed)
            }
        }

        if transactions.isEmpty {
            // Try tabular format — some statements have columns separated by multiple spaces
            let joined = lines.joined(separator: "\n")
            let tabularRows = parseTabularStatement(joined)
            transactions = tabularRows
        }

        if transactions.isEmpty {
            errors.append("Could not extract any transactions. The PDF format may not be supported.")
        }

        return ParseResult(transactions: transactions, errors: errors, fileName: fileName)
    }

    // MARK: - CSV Parsing

    private func parseCSV(data: Data, fileName: String) throws -> ParseResult {
        guard let content = String(data: data, encoding: .utf8) ??
                            String(data: data, encoding: .ascii) else {
            throw ParserError.invalidEncoding
        }

        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count > 1 else {
            throw ParserError.emptyFile
        }

        // Detect header and column mapping
        let header = lines[0].lowercased()
        let columnMap = detectCSVColumns(header: header)
        let separator = detectSeparator(line: lines[0])

        var transactions: [ParsedRow] = []
        var errors: [String] = []

        for i in 1..<lines.count {
            let fields = parseCSVLine(lines[i], separator: separator)
            if let row = mapCSVFields(fields: fields, columnMap: columnMap, lineNumber: i + 1) {
                transactions.append(row)
            } else {
                if fields.count > 1 {
                    errors.append("Line \(i + 1): Could not parse")
                }
            }
        }

        return ParseResult(transactions: transactions, errors: errors, fileName: fileName)
    }

    // MARK: - Line Parsing Helpers

    /// Attempts to parse a single text line as a transaction.
    /// Handles common bank statement formats:
    ///   "12/03/2026  NEFT-SALARY  250,000.00 Cr"
    ///   "15-Mar-2026  UPI/Zomato/12345  1,254.00  Dr"
    private func parseTransactionLine(_ line: String) -> ParsedRow? {
        // Try to find a date at the start
        guard let (date, remaining) = extractDate(from: line) else { return nil }

        // Try to find amount (with commas, decimals)
        guard let (amount, description, type) = extractAmount(from: remaining) else { return nil }

        let cleanDesc = description
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)

        guard !cleanDesc.isEmpty else { return nil }

        return ParsedRow(date: date, description: cleanDesc, amount: abs(amount), type: type)
    }

    /// Parse tabular bank statement text where rows have consistent column positions
    private func parseTabularStatement(_ text: String) -> [ParsedRow] {
        var results: [ParsedRow] = []
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            if let parsed = parseTransactionLine(line) {
                results.append(parsed)
            }
        }
        return results
    }

    // MARK: - Date Extraction

    private static let dateFormatters: [DateFormatter] = {
        let formats = [
            "dd/MM/yyyy", "dd-MM-yyyy", "MM/dd/yyyy",
            "dd/MM/yy", "dd-MM-yy",
            "dd-MMM-yyyy", "dd MMM yyyy", "dd-MMM-yy",
            "yyyy-MM-dd", "yyyy/MM/dd",
            "dd MMM yy", "MMM dd, yyyy",
        ]
        return formats.map { fmt in
            let f = DateFormatter()
            f.dateFormat = fmt
            f.locale = Locale(identifier: "en_IN")
            return f
        }
    }()

    private func extractDate(from line: String) -> (Date, String)? {
        // Try matching date patterns at start of line
        let datePatterns = [
            "\\d{2}[/-]\\d{2}[/-]\\d{4}",
            "\\d{2}[/-]\\d{2}[/-]\\d{2}",
            "\\d{2}[/-][A-Za-z]{3}[/-]\\d{4}",
            "\\d{2}[/-][A-Za-z]{3}[/-]\\d{2}",
            "\\d{2}\\s+[A-Za-z]{3}\\s+\\d{4}",
            "\\d{2}\\s+[A-Za-z]{3}\\s+\\d{2}",
            "\\d{4}[/-]\\d{2}[/-]\\d{2}",
            "[A-Za-z]{3}\\s+\\d{2},?\\s+\\d{4}",
        ]

        for pattern in datePatterns {
            guard let regex = try? NSRegularExpression(pattern: "^\\s*(\(pattern))"),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let range = Range(match.range(at: 1), in: line) else {
                continue
            }

            let dateStr = String(line[range]).trimmingCharacters(in: .whitespaces)
            for formatter in Self.dateFormatters {
                if let date = formatter.date(from: dateStr) {
                    let remaining = String(line[range.upperBound...])
                    return (date, remaining)
                }
            }
        }
        return nil
    }

    // MARK: - Amount Extraction

    private func extractAmount(from text: String) -> (Double, String, TransactionType)? {
        // Match amounts like: 1,254.00, 250000.00, 1254, etc.
        // Also look for Cr/Dr, +/- indicators
        let amountPattern = "([\\d,]+\\.?\\d*)\\s*(Cr|Dr|CR|DR|cr|dr)?\\s*$"

        // Also try: amount might be in middle with Cr/Dr
        let patterns = [
            // Amount at end with Cr/Dr
            "(.+?)\\s+([\\d,]+\\.?\\d*)\\s*(Cr|Dr|CR|DR|cr|dr)\\s*$",
            // Two amount columns (debit/credit) common in bank statements
            "(.+?)\\s+([\\d,]+\\.?\\d*)\\s+([\\d,]+\\.?\\d*)\\s*$",
            // Single amount at end
            "(.+?)\\s+(-?[\\d,]+\\.?\\d*)\\s*$",
            // Amount with prefix sign
            "(.+?)\\s+([+-]\\s*[\\d,]+\\.?\\d*)\\s*$",
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
                continue
            }

            let groupCount = match.numberOfRanges

            if groupCount == 4 {
                // Check if this is description + amount + Cr/Dr
                if let descRange = Range(match.range(at: 1), in: text),
                   let amtRange = Range(match.range(at: 2), in: text),
                   let typeRange = Range(match.range(at: 3), in: text) {

                    let desc = String(text[descRange])
                    let amtStr = String(text[amtRange]).replacingOccurrences(of: ",", with: "")
                    let typeStr = String(text[typeRange]).lowercased()

                    if let amount = Double(amtStr) {
                        let type: TransactionType = typeStr == "cr" ? .income : .expense
                        return (amount, desc, type)
                    }

                    // Could be two amount columns (debit | credit)
                    let secondAmtStr = String(text[typeRange]).replacingOccurrences(of: ",", with: "")
                    if let debit = Double(amtStr), debit > 0, let credit = Double(secondAmtStr), credit > 0 {
                        // If first column has value → debit, second → credit
                        return (debit, desc, .expense)
                    } else if let debit = Double(amtStr), debit > 0 {
                        return (debit, desc, .expense)
                    }
                }
            }

            if groupCount == 3 {
                if let descRange = Range(match.range(at: 1), in: text),
                   let amtRange = Range(match.range(at: 2), in: text) {
                    let desc = String(text[descRange])
                    var amtStr = String(text[amtRange])
                        .replacingOccurrences(of: ",", with: "")
                        .replacingOccurrences(of: " ", with: "")
                    let isNegative = amtStr.hasPrefix("-")
                    amtStr = amtStr.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "-", with: "")
                    if let amount = Double(amtStr), amount > 0 {
                        let type: TransactionType = isNegative ? .expense : .income
                        return (amount, desc, amount > 100000 && !isNegative ? .income : type)
                    }
                }
            }
        }
        return nil
    }

    // MARK: - CSV Helpers

    struct ColumnMap {
        var dateCol: Int?
        var descriptionCol: Int?
        var amountCol: Int?
        var debitCol: Int?
        var creditCol: Int?
        var balanceCol: Int?
    }

    private func detectSeparator(line: String) -> Character {
        let commaCount = line.filter { $0 == "," }.count
        let tabCount = line.filter { $0 == "\t" }.count
        let pipeCount = line.filter { $0 == "|" }.count
        let semiCount = line.filter { $0 == ";" }.count

        let max = max(commaCount, tabCount, pipeCount, semiCount)
        if max == tabCount { return "\t" }
        if max == pipeCount { return "|" }
        if max == semiCount { return ";" }
        return ","
    }

    private func detectCSVColumns(header: String) -> ColumnMap {
        var map = ColumnMap()
        let separator = detectSeparator(line: header)
        let cols = header.components(separatedBy: String(separator))
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }

        for (i, col) in cols.enumerated() {
            let c = col.lowercased()
            if c.contains("date") || c.contains("txn date") || c.contains("transaction date") || c.contains("value date") || c.contains("posting date") {
                if map.dateCol == nil { map.dateCol = i }
            }
            if c.contains("narration") || c.contains("description") || c.contains("particular") || c.contains("remark") || c.contains("detail") || c.contains("merchant") || c.contains("payee") || c.contains("transaction detail") {
                map.descriptionCol = i
            }
            if c == "amount" || c.contains("transaction amount") || c.contains("txn amount") {
                map.amountCol = i
            }
            if c.contains("debit") || c.contains("withdrawal") || c.contains("dr") {
                map.debitCol = i
            }
            if c.contains("credit") || c.contains("deposit") || c.contains("cr") {
                map.creditCol = i
            }
            if c.contains("balance") || c.contains("closing") {
                map.balanceCol = i
            }
        }

        // Fallback: if no description found, pick column after date
        if map.descriptionCol == nil, let dateCol = map.dateCol {
            if dateCol + 1 < cols.count {
                map.descriptionCol = dateCol + 1
            }
        }

        // Fallback: if no amount columns detected, try to guess
        if map.amountCol == nil && map.debitCol == nil && map.creditCol == nil {
            // Look for numeric columns (skip date and description)
            for (i, col) in cols.enumerated() {
                if i == map.dateCol || i == map.descriptionCol || i == map.balanceCol { continue }
                if col.contains("amount") || col.isEmpty {
                    map.amountCol = i
                    break
                }
            }
        }

        return map
    }

    private func parseCSVLine(_ line: String, separator: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == separator && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    private func mapCSVFields(fields: [String], columnMap: ColumnMap, lineNumber: Int) -> ParsedRow? {
        // Extract date
        var date: Date?
        if let col = columnMap.dateCol, col < fields.count {
            let dateStr = fields[col].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            for formatter in Self.dateFormatters {
                if let d = formatter.date(from: dateStr) {
                    date = d
                    break
                }
            }
        }
        guard let parsedDate = date else { return nil }

        // Extract description
        var description = "Unknown"
        if let col = columnMap.descriptionCol, col < fields.count {
            description = fields[col].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        guard !description.isEmpty else { return nil }

        // Extract amount
        var amount: Double = 0
        var type: TransactionType = .expense

        if let debitCol = columnMap.debitCol, let creditCol = columnMap.creditCol {
            let debitStr = cleanAmountString(debitCol < fields.count ? fields[debitCol] : "")
            let creditStr = cleanAmountString(creditCol < fields.count ? fields[creditCol] : "")
            let debit = Double(debitStr) ?? 0
            let credit = Double(creditStr) ?? 0

            if credit > 0 {
                amount = credit
                type = .income
            } else if debit > 0 {
                amount = debit
                type = .expense
            } else {
                return nil
            }
        } else if let amtCol = columnMap.amountCol, amtCol < fields.count {
            let amtStr = cleanAmountString(fields[amtCol])
            guard let val = Double(amtStr), val != 0 else { return nil }
            amount = abs(val)
            type = val > 0 ? .income : .expense
        } else {
            // Try all remaining columns for a numeric value
            for (i, field) in fields.enumerated() {
                if i == columnMap.dateCol || i == columnMap.descriptionCol || i == columnMap.balanceCol { continue }
                let cleaned = cleanAmountString(field)
                if let val = Double(cleaned), val != 0 {
                    amount = abs(val)
                    type = val >= 0 ? .expense : .income // Default to expense for positive in debit context
                    break
                }
            }
            if amount == 0 { return nil }
        }

        return ParsedRow(date: parsedDate, description: description, amount: amount, type: type)
    }

    private func cleanAmountString(_ str: String) -> String {
        str.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
           .replacingOccurrences(of: ",", with: "")
           .replacingOccurrences(of: "₹", with: "")
           .replacingOccurrences(of: "Rs.", with: "")
           .replacingOccurrences(of: "INR", with: "")
           .replacingOccurrences(of: " ", with: "")
    }
}

// MARK: - Auto-Categorizer

struct AutoCategorizer {
    /// Categorize a transaction description using rules, then keyword heuristics.
    static func categorize(description: String, rules: [Rule]) -> String {
        let lower = description.lowercased()

        // 1. Check user-defined rules first
        for rule in rules {
            if lower.contains(rule.keyword.lowercased()) {
                return rule.targetCategory
            }
        }

        // 2. Built-in keyword matching
        return keywordMatch(lower)
    }

    /// Extract a merchant name from a bank description
    static func extractMerchant(from description: String) -> String {
        var cleaned = description

        // Remove common UPI prefixes
        let upiPrefixes = ["UPI/", "UPI-", "NEFT/", "NEFT-", "IMPS/", "IMPS-", "POS/", "POS ",
                           "ATM/", "ATM-", "BIL/", "BIL-", "EMI/", "SI/", "ACH/"]
        for prefix in upiPrefixes {
            if cleaned.uppercased().hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
            }
        }

        // Remove reference numbers (sequences of digits > 6 chars)
        cleaned = cleaned.replacingOccurrences(
            of: "\\b\\d{6,}\\b", with: "", options: .regularExpression
        )

        // Remove trailing slashes, dashes, and clean up
        cleaned = cleaned.components(separatedBy: "/").first ?? cleaned
        cleaned = cleaned.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        // Capitalize nicely
        let words = cleaned.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if words.isEmpty { return description.prefix(30).trimmingCharacters(in: .whitespaces) }

        return words.prefix(3).map { word in
            if word.count <= 3 { return word.uppercased() }
            return word.prefix(1).uppercased() + word.dropFirst().lowercased()
        }.joined(separator: " ")
    }

    private static func keywordMatch(_ text: String) -> String {
        let foodKeywords = ["zomato", "swiggy", "food", "restaurant", "cafe", "pizza",
                            "burger", "domino", "mcdonald", "kfc", "starbucks", "dunkin",
                            "grocery", "grocer", "bigbasket", "blinkit", "instamart",
                            "zepto", "dmart", "supermarket", "bakery", "dairy", "meat",
                            "chicken", "fish", "vegetable", "fruit", "canteen", "mess",
                            "biryani", "dosa", "meals", "tiffin", "lunch", "dinner", "breakfast"]

        let transportKeywords = ["uber", "ola", "rapido", "petrol", "diesel", "fuel",
                                  "parking", "toll", "fastag", "metro", "railway", "irctc",
                                  "bus", "cab", "auto", "rickshaw", "car wash", "service station",
                                  "indian oil", "bharat petroleum", "hp petrol", "shell"]

        let shoppingKeywords = ["amazon", "flipkart", "myntra", "ajio", "meesho", "nykaa",
                                "h&m", "zara", "croma", "reliance digital", "vijay sales",
                                "shopping", "mall", "store", "fashion", "clothes", "shoes",
                                "electronics", "furniture", "ikea", "decathlon", "tata cliq"]

        let entertainmentKeywords = ["netflix", "spotify", "hotstar", "prime video", "youtube",
                                      "jio cinema", "zee5", "sony liv", "apple music",
                                      "bookmyshow", "pvr", "inox", "movie", "cinema", "theatre",
                                      "gaming", "playstation", "xbox", "steam", "concert"]

        let healthKeywords = ["pharmacy", "medical", "hospital", "doctor", "clinic",
                              "apollo", "medplus", "netmeds", "pharmeasy", "1mg",
                              "health", "gym", "fitness", "yoga", "lab", "diagnostic",
                              "insurance premium", "star health", "max bupa"]

        let utilityKeywords = ["electricity", "electric", "power", "bescom", "tata power",
                               "water bill", "gas bill", "internet", "broadband", "wifi",
                               "jio", "airtel", "vodafone", "bsnl", "phone", "mobile",
                               "recharge", "dth", "piped gas", "lpg", "maintenance", "society"]

        let financeKeywords = ["mutual fund", "sip", "fd ", "fixed deposit", "rd ",
                                "recurring deposit", "loan", "emi", "premium", "lic",
                                "investment", "stock", "share", "demat", "zerodha",
                                "groww", "kuvera", "ppf", "nps", "interest"]

        let incomeKeywords = ["salary", "credit interest", "refund", "cashback", "dividend",
                              "rent received", "freelance", "payment received", "bonus"]

        if incomeKeywords.contains(where: { text.contains($0) }) { return "Income" }
        if foodKeywords.contains(where: { text.contains($0) }) { return "Food" }
        if transportKeywords.contains(where: { text.contains($0) }) { return "Transport" }
        if shoppingKeywords.contains(where: { text.contains($0) }) { return "Shopping" }
        if entertainmentKeywords.contains(where: { text.contains($0) }) { return "Entertainment" }
        if healthKeywords.contains(where: { text.contains($0) }) { return "Health" }
        if utilityKeywords.contains(where: { text.contains($0) }) { return "Utilities" }
        if financeKeywords.contains(where: { text.contains($0) }) { return "Finance" }

        return "Misc"
    }
}

// MARK: - Duplicate Detector

struct DuplicateDetector {
    /// Find potential duplicates among existing transactions.
    /// Two transactions are duplicates if they have the same date, similar amount, and similar merchant.
    static func findDuplicates(
        newTransactions: [StatementParser.ParsedRow],
        existing: [Transaction]
    ) -> [(new: StatementParser.ParsedRow, existing: Transaction)] {
        var duplicates: [(StatementParser.ParsedRow, Transaction)] = []

        for newTxn in newTransactions {
            for oldTxn in existing {
                let sameDate = Calendar.current.isDate(newTxn.date, inSameDayAs: oldTxn.date)
                let sameAmount = abs(newTxn.amount - abs(oldTxn.amount)) < 0.01
                let similarDesc = newTxn.description.lowercased().contains(oldTxn.merchant.lowercased()) ||
                                  oldTxn.merchant.lowercased().contains(newTxn.description.lowercased().prefix(5))

                if sameDate && sameAmount && similarDesc {
                    duplicates.append((newTxn, oldTxn))
                    break
                }
            }
        }

        return duplicates
    }
}

// MARK: - Parser Error

enum ParserError: LocalizedError {
    case accessDenied
    case unsupportedFormat(String)
    case invalidPDF
    case noTextContent
    case invalidEncoding
    case emptyFile

    var errorDescription: String? {
        switch self {
        case .accessDenied: return "Cannot access the file. Please try again."
        case .unsupportedFormat(let ext): return "Unsupported file format: .\(ext)"
        case .invalidPDF: return "Could not read the PDF file."
        case .noTextContent: return "The PDF contains no readable text. It may be a scanned document."
        case .invalidEncoding: return "Could not read the file encoding."
        case .emptyFile: return "The file appears to be empty."
        }
    }
}
