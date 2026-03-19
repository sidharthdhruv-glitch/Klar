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
        let source: ImportSource
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

        // Extract text page by page
        var allText = ""
        var perPageTexts: [String] = []
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            if let pageText = page.string {
                allText += pageText + "\n"
                perPageTexts.append(pageText)
            }
        }

        guard !allText.isEmpty else {
            throw ParserError.noTextContent
        }

        // Preprocess: split merged columns at date/number boundaries
        let preprocessed = preprocessText(allText)

        let lines = preprocessed.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Try ALL strategies and pick the one with the most results
        var bestTransactions: [ParsedRow] = []

        // Strategy 1: Column-aware parsing on full text
        let columnAware = parseColumnAware(lines: lines)
        if columnAware.count > bestTransactions.count {
            bestTransactions = columnAware
        }

        // Strategy 2: Page-by-page column-aware parsing (handles multi-page better)
        if perPageTexts.count > 1 {
            var pageByPage: [ParsedRow] = []
            for pageText in perPageTexts {
                let pagePreprocessed = preprocessText(pageText)
                let pageLines = pagePreprocessed.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                pageByPage.append(contentsOf: parseColumnAware(lines: pageLines))
            }
            if pageByPage.count > bestTransactions.count {
                bestTransactions = pageByPage
            }
        }

        // Strategy 3: Date-anchored parsing (scans entire text for date->amount patterns)
        let anchored = parseDateAnchored(text: preprocessed)
        if anchored.count > bestTransactions.count {
            bestTransactions = anchored
        }

        // Strategy 4: Line-by-line fallback
        let lineByLine = parseLineByLine(lines: lines)
        if lineByLine.count > bestTransactions.count {
            bestTransactions = lineByLine
        }

        var errors: [String] = []
        if bestTransactions.isEmpty {
            errors.append("Could not extract any transactions. The PDF format may not be supported.")
        }

        return ParseResult(transactions: bestTransactions, errors: errors, fileName: fileName, source: .pdf)
    }

    // MARK: - Text Preprocessing

    /// Splits merged column text at date and number boundaries.
    /// PDFKit often merges adjacent columns without spaces, e.g.:
    ///   "1,57,370.0002/02/2026" → "1,57,370.00\n02/02/2026"
    ///   "943.00157370.00" → "943.00 157370.00"
    private func preprocessText(_ text: String) -> String {
        var result = text

        // Split before date patterns that are stuck to preceding text (no whitespace separator)
        // e.g., "1,57,370.0002/02/2026" → "1,57,370.00\n02/02/2026"
        let dateStarts = [
            #"([^\s\n])(\d{2}[/-]\d{2}[/-]\d{4})"#,
            #"([^\s\n])(\d{2}[/-]\d{2}[/-]\d{2}(?!\d))"#,
            #"([^\s\n])(\d{2}[/-][A-Za-z]{3}[/-]\d{4})"#,
            #"([^\s\n])(\d{2}[/-][A-Za-z]{3}[/-]\d{2}(?!\d))"#,
        ]
        for pattern in dateStarts {
            result = result.replacingOccurrences(of: pattern, with: "$1\n$2", options: .regularExpression)
        }

        // Split between amounts stuck together: "943.001,57,370.00" → "943.00 1,57,370.00"
        // Bank amounts always have exactly 2 decimal places, so .XX followed by digit = boundary
        result = result.replacingOccurrences(
            of: #"(\.\d{2})(\d)"#, with: "$1 $2", options: .regularExpression
        )

        // Split where a digit runs into a letter: "943.00UPI" → "943.00 UPI"
        result = result.replacingOccurrences(
            of: #"(\d)([A-Za-z])"#, with: "$1 $2", options: .regularExpression
        )

        // Split where a letter runs into a date-like digit pair: "TRANSFER02/02" → "TRANSFER 02/02"
        result = result.replacingOccurrences(
            of: #"([A-Za-z])(\d{2}[/-])"#, with: "$1 $2", options: .regularExpression
        )

        return result
    }

    // MARK: - Table Layout Detection

    private struct TableLayout {
        let headerIndex: Int
        let numericColumnCount: Int // Expected trailing numeric columns (3 = debit+credit+balance, 2 = amount+balance)
        let hasDebitCredit: Bool    // Separate debit/credit columns detected
    }

    private func detectTableLayout(lines: [String]) -> TableLayout? {
        let headerKeywords: Set<String> = [
            "date", "narration", "description", "particulars", "particular",
            "withdrawal", "deposit", "debit", "credit", "balance",
            "amount", "chq", "ref", "value", "details", "transaction"
        ]

        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            let words = Set(
                lower.components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { !$0.isEmpty }
            )
            let matchCount = words.intersection(headerKeywords).count

            // Need at least 2 header keywords to consider it a table header
            guard matchCount >= 2 else { continue }

            let hasDebitCredit =
                (lower.contains("withdrawal") || lower.contains("debit") || lower.range(of: #"\bdr\b"#, options: .regularExpression) != nil) &&
                (lower.contains("deposit") || lower.contains("credit") || lower.range(of: #"\bcr\b"#, options: .regularExpression) != nil)
            let hasBalance = lower.contains("balance") || lower.contains("closing")

            let numCols: Int
            if hasDebitCredit && hasBalance {
                numCols = 3
            } else if hasDebitCredit || hasBalance {
                numCols = 2
            } else {
                numCols = 1
            }

            return TableLayout(
                headerIndex: index,
                numericColumnCount: numCols,
                hasDebitCredit: hasDebitCredit
            )
        }
        return nil
    }

    // MARK: - Column-Aware Parsing

    private func parseColumnAware(lines: [String]) -> [ParsedRow] {
        let layout = detectTableLayout(lines: lines)
        let startIndex = (layout?.headerIndex ?? -1) + 1
        let expectedNumCols = layout?.numericColumnCount ?? 2

        var transactions: [ParsedRow] = []
        var currentDate: Date?
        var currentDesc: String = ""
        var currentNumbers: [Double] = []
        var currentCrDr: String?

        func flushTransaction() {
            guard let date = currentDate, !currentNumbers.isEmpty else { return }

            var cleanDesc = cleanDescription(currentDesc)
            // Don't drop transactions just because description is empty --
            // use a placeholder so we preserve the date and amount
            if cleanDesc.isEmpty { cleanDesc = "Transaction" }

            let (amount, type) = resolveAmount(
                numbers: currentNumbers,
                crDr: currentCrDr,
                expectedColumns: expectedNumCols,
                hasDebitCredit: layout?.hasDebitCredit ?? false,
                description: cleanDesc
            )

            guard amount > 0.001 else { return }

            transactions.append(ParsedRow(date: date, description: cleanDesc, amount: amount, type: type))
        }

        for i in startIndex..<lines.count {
            let line = lines[i]

            // Skip separator lines, page headers/footers
            if isSeparatorLine(line) { continue }
            if isPageHeaderOrFooter(line) { continue }

            if let (date, remaining) = extractDate(from: line) {
                let (desc, nums, crdr) = extractTrailingNumbers(from: remaining)

                // RELAXED value date detection:
                // A line with a date is a VALUE DATE only when:
                //   1. The previous transaction has NO amounts AND this line has ONLY amounts (no description text)
                //   2. OR they share the exact same date and this line has no meaningful description
                let descTrimmed = desc.trimmingCharacters(in: .whitespaces)
                let descIsEmpty = descTrimmed.isEmpty ||
                                  descTrimmed.range(of: #"^[\d,.\s]+$"#, options: .regularExpression) != nil
                let prevHasNoAmounts = currentDate != nil && currentNumbers.isEmpty

                let isSameDate: Bool = {
                    guard let prev = currentDate else { return false }
                    return Calendar.current.isDate(prev, inSameDayAs: date)
                }()

                // Strict value date: only merge if previous txn truly needs amounts
                let isValueDate = (prevHasNoAmounts && descIsEmpty && !nums.isEmpty) ||
                                  (prevHasNoAmounts && isSameDate && descIsEmpty)

                if isValueDate {
                    // Merge into current transaction: add amounts
                    if !desc.isEmpty && !descIsEmpty {
                        currentDesc += " " + desc
                    }
                    currentNumbers.append(contentsOf: nums)
                    if let cr = crdr { currentCrDr = cr }
                } else {
                    // Genuine new transaction -- flush the previous one
                    flushTransaction()
                    currentDate = date
                    currentDesc = desc
                    currentNumbers = nums
                    currentCrDr = crdr
                }
            } else if currentDate != nil {
                // Continuation line (multi-line narration or additional numbers)
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Only skip lines that are clearly non-transaction metadata
                // Use strict check to avoid filtering real continuation content
                if looksLikeNonTransactionLine(trimmed) { continue }

                let (desc, nums, crdr) = extractTrailingNumbers(from: trimmed)
                if !desc.isEmpty {
                    currentDesc += " " + desc
                }
                if !nums.isEmpty {
                    // Keep collecting numbers (up to a generous limit)
                    if currentNumbers.count < expectedNumCols + 4 {
                        currentNumbers.append(contentsOf: nums)
                    }
                    if let cr = crdr { currentCrDr = cr }
                }
            }
        }

        // Flush last transaction
        flushTransaction()

        return transactions
    }

    // MARK: - Date-Anchored Parsing (Fallback Strategy)

    /// Scans the entire text for all date occurrences, then extracts transactions
    /// by looking at the text between consecutive transaction dates.
    /// This handles cases where PDFKit output doesn't have clean line breaks.
    private func parseDateAnchored(text: String) -> [ParsedRow] {
        struct DateOccurrence {
            let date: Date
            let startPosition: Int
            let endPosition: Int
        }

        let nsText = text as NSString
        let patterns = [
            "\\d{2}[/-]\\d{2}[/-]\\d{4}",
            "\\d{2}[/-]\\d{2}[/-]\\d{2}(?!\\d)",
            "\\d{2}[/-][A-Za-z]{3}[/-]\\d{4}",
            "\\d{2}[/-][A-Za-z]{3}[/-]\\d{2}(?!\\d)",
            "\\d{2}\\s+[A-Za-z]{3}\\s+\\d{4}",
            "\\d{2}\\s+[A-Za-z]{3}\\s+\\d{2}(?!\\d)",
        ]

        var allDates: [DateOccurrence] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                let dateStr = nsText.substring(with: match.range).trimmingCharacters(in: .whitespaces)
                for formatter in Self.dateFormatters {
                    if let date = formatter.date(from: dateStr) {
                        allDates.append(DateOccurrence(
                            date: fixCentury(date),
                            startPosition: match.range.location,
                            endPosition: match.range.location + match.range.length
                        ))
                        break
                    }
                }
            }
        }

        // Sort by position and remove overlapping
        allDates.sort { $0.startPosition < $1.startPosition }
        var filtered: [DateOccurrence] = []
        var lastEnd = -1
        for dp in allDates {
            if dp.startPosition >= lastEnd {
                filtered.append(dp)
                lastEnd = dp.endPosition
            }
        }
        allDates = filtered

        guard allDates.count >= 2 else { return [] }

        // Classify each date: does text after it look like a narration or just amounts?
        // Transaction dates have narration (letters) following them.
        // Value dates have only numbers following them.
        struct ClassifiedDate {
            let date: Date
            let startPosition: Int
            let endPosition: Int
            let isTransactionDate: Bool // true = starts a transaction, false = value date
        }

        var classified: [ClassifiedDate] = []
        for (idx, dp) in allDates.enumerated() {
            let lookAheadStart = dp.endPosition
            let lookAheadEnd = min(dp.endPosition + 60, idx + 1 < allDates.count ? allDates[idx + 1].startPosition : nsText.length)
            guard lookAheadStart < lookAheadEnd else {
                classified.append(ClassifiedDate(date: dp.date, startPosition: dp.startPosition, endPosition: dp.endPosition, isTransactionDate: false))
                continue
            }
            let afterText = nsText.substring(with: NSRange(location: lookAheadStart, length: lookAheadEnd - lookAheadStart))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // If what follows contains letters (narration), it's a transaction date
            // Allow leading whitespace/newlines before letters
            let hasLetters = afterText.range(of: #"[A-Za-z]{2,}"#, options: .regularExpression) != nil
            // Check if it's purely numeric (value date line with just amounts)
            let isPurelyNumeric = afterText.range(of: #"^[\d,.\s\-\+]+$"#, options: .regularExpression) != nil

            let isTransaction = hasLetters && !isPurelyNumeric
            classified.append(ClassifiedDate(date: dp.date, startPosition: dp.startPosition, endPosition: dp.endPosition, isTransactionDate: isTransaction))
        }

        // Build transactions: take text between consecutive transaction dates
        var transactions: [ParsedRow] = []

        // Collect indices of transaction dates
        var txnIndices: [Int] = []
        for (idx, cd) in classified.enumerated() {
            if cd.isTransactionDate {
                txnIndices.append(idx)
            }
        }

        for (ti, classifiedIdx) in txnIndices.enumerated() {
            let txnDate = classified[classifiedIdx].date
            let textStart = classified[classifiedIdx].endPosition

            // End of this transaction's text = start of the next transaction date
            let nextTxnStart: Int
            if ti + 1 < txnIndices.count {
                nextTxnStart = classified[txnIndices[ti + 1]].startPosition
            } else {
                nextTxnStart = nsText.length
            }

            guard textStart < nextTxnStart else { continue }

            let chunk = nsText.substring(with: NSRange(location: textStart, length: nextTxnStart - textStart))

            // Clean page headers/footers from the chunk
            let chunkLines = chunk.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !isPageHeaderOrFooter($0) && !isSeparatorLine($0) }
            let cleanedChunk = chunkLines.joined(separator: " ")

            let (desc, nums, crdr) = extractTrailingNumbers(from: cleanedChunk)

            if !nums.isEmpty {
                var cleanDesc = cleanDescription(desc)
                if cleanDesc.isEmpty { cleanDesc = "Transaction" }

                let (amount, type) = resolveAmount(
                    numbers: nums,
                    crDr: crdr,
                    expectedColumns: 2,
                    hasDebitCredit: false,
                    description: cleanDesc
                )

                if amount > 0.001 {
                    transactions.append(ParsedRow(date: txnDate, description: cleanDesc, amount: amount, type: type))
                }
            }
        }

        return transactions
    }

    // MARK: - Trailing Number Extraction

    /// Extracts numeric values from the trailing (right) side of a text string.
    /// Works right-to-left, stopping at the first non-numeric token.
    /// Handles Indian number formatting (1,57,370.00), Cr/Dr markers, and negative numbers
    /// in brackets like (1,234.56) or with (-) suffix.
    private func extractTrailingNumbers(from text: String) -> (description: String, numbers: [Double], crDr: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return ("", [], nil) }

        // Split into tokens by whitespace
        let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var numbers: [Double] = []
        var descEndIndex = tokens.count
        var crDr: String?

        for i in stride(from: tokens.count - 1, through: 0, by: -1) {
            let token = tokens[i]
            let lower = token.lowercased()

            // Check for Cr/Dr markers
            if lower == "cr" || lower == "dr" || lower == "cr." || lower == "dr." ||
               lower == "(cr)" || lower == "(dr)" {
                crDr = lower.contains("cr") ? "cr" : "dr"
                descEndIndex = i
                continue
            }

            // Strip brackets for negative numbers: (1,234.56) -> 1234.56
            var tokenCleaned = token
            var bracketNegative = false
            if tokenCleaned.hasPrefix("(") && tokenCleaned.hasSuffix(")") {
                tokenCleaned = String(tokenCleaned.dropFirst().dropLast())
                bracketNegative = true
            }
            // Handle (-) suffix: 1,234.56(-) -> 1234.56
            if tokenCleaned.hasSuffix("(-)") {
                tokenCleaned = String(tokenCleaned.dropLast(3))
                bracketNegative = true
            }

            // Check for number (Indian format: 1,57,370.00 or standard: 1,234.56 or plain: 943)
            let cleaned = tokenCleaned.replacingOccurrences(of: ",", with: "")
            let isNegative = cleaned.hasPrefix("-") || cleaned.hasPrefix("+")
            let absStr = isNegative ? String(cleaned.dropFirst()) : cleaned

            if absStr.range(of: #"^\d+\.?\d*$"#, options: .regularExpression) != nil,
               let num = Double(cleaned) {
                numbers.insert(abs(num), at: 0)
                if cleaned.hasPrefix("-") || bracketNegative { crDr = "dr" }
                if cleaned.hasPrefix("+") { crDr = "cr" }
                descEndIndex = i
            } else {
                break // Stop at first non-number token from the right
            }
        }

        let description = tokens[0..<descEndIndex].joined(separator: " ")
        return (description, numbers, crDr)
    }

    // MARK: - Amount Resolution

    /// Given the extracted trailing numbers and context, determine the actual transaction amount
    /// and whether it's income or expense.
    /// Key insight: In Indian bank statements, the LAST number is usually the running balance.
    /// Debit/Credit amounts come before the balance.
    private func resolveAmount(
        numbers: [Double],
        crDr: String?,
        expectedColumns: Int,
        hasDebitCredit: Bool,
        description: String
    ) -> (Double, TransactionType) {
        guard !numbers.isEmpty else { return (0, .expense) }

        // Check description for income hints
        let lower = description.lowercased()
        let incomeHints = ["salary", "credit", "neft cr", "imps cr", "deposit", "refund",
                           "cashback", "interest", "dividend", "received", "reversal",
                           "cash dep", "by transfer", "by clg"]
        let isLikelyIncome = crDr == "cr" || incomeHints.contains(where: { lower.contains($0) })
        let type: TransactionType = isLikelyIncome ? .income : .expense

        if numbers.count == 1 {
            return (numbers[0], type)
        }

        if numbers.count == 2 {
            let first = numbers[0]
            let second = numbers[1]

            // If one is 0, the other is debit or credit, and there's no balance column visible
            if first == 0 && second > 0 {
                return (second, .income)
            }
            if second == 0 && first > 0 {
                return (first, .expense)
            }

            // Heuristic: the larger number is likely the balance
            // In most cases, individual transaction < running balance
            if second > first * 2 {
                // First is transaction amount, second is balance
                return (first, type)
            } else if first > second * 2 {
                // First is balance, second is the transaction amount (unusual column order)
                return (second, type)
            }

            // Similar magnitude — assume first=amount, second=balance (standard order)
            return (first, type)
        }

        if numbers.count >= 3 {
            // Common layout: Debit, Credit, Balance (last is always balance)
            let debit = numbers[0]
            let credit = numbers[1]
            // Skip balance (last number)

            if debit > 0 && credit == 0 {
                return (debit, .expense)
            } else if credit > 0 && debit == 0 {
                return (credit, .income)
            } else if debit > 0 && credit > 0 {
                // Both non-zero — possible multi-column layout or parsing artifact
                // The non-balance column with the smaller value is likely the transaction
                let balance = numbers.last ?? 0
                if abs(balance - credit) < 1 || credit > debit * 5 {
                    // Credit looks like balance; debit is the transaction
                    return (debit, .expense)
                } else if abs(balance - debit) < 1 || debit > credit * 5 {
                    // Debit looks like balance; credit is the transaction
                    return (credit, .income)
                }
                // Default: smaller is the transaction
                return debit < credit ? (debit, .expense) : (credit, .income)
            }

            // All zeros except possibly the last — skip
            for num in numbers.dropLast() where num > 0 {
                return (num, type)
            }
        }

        return (numbers[0], .expense)
    }

    // MARK: - Description Cleaning

    private func cleanDescription(_ raw: String) -> String {
        var desc = raw.trimmingCharacters(in: .whitespaces)

        // Remove embedded value dates (dd/mm/yyyy, dd-mm-yyyy, dd-MMM-yy patterns)
        desc = desc.replacingOccurrences(
            of: #"\b\d{2}[/-]\d{2}[/-]\d{2,4}\b"#, with: " ", options: .regularExpression
        )
        desc = desc.replacingOccurrences(
            of: #"\b\d{2}[/-][A-Za-z]{3}[/-]\d{2,4}\b"#, with: " ", options: .regularExpression
        )

        // Remove alphanumeric bank reference codes (e.g., AXISP00768252541, YESB0APLUPI, UTIB0001394)
        // Pattern: 4+ uppercase letters followed by digits, or digits mixed with uppercase letters (min 8 chars)
        desc = desc.replacingOccurrences(
            of: #"\b[A-Z]{3,}[A-Z0-9]{5,}\b"#, with: "", options: .regularExpression
        )
        desc = desc.replacingOccurrences(
            of: #"\b[A-Z0-9]{8,}\b"#, with: "", options: .regularExpression
        )

        // Remove long reference numbers (6+ consecutive digits)
        desc = desc.replacingOccurrences(
            of: #"\b\d{6,}\b"#, with: "", options: .regularExpression
        )

        // Remove standalone numbers that look like amounts (e.g., "12,128.00", "1,111.00")
        desc = desc.replacingOccurrences(
            of: #"\b\d{1,3}(,\d{2,3})*\.\d{2}\b"#, with: "", options: .regularExpression
        )

        // Remove standalone short numbers (1-4 digits) that are likely day/ref fragments
        desc = desc.replacingOccurrences(
            of: #"(?<=\s|^)\d{1,4}(?=\s|$)"#, with: "", options: .regularExpression
        )

        // Remove common noise tokens
        let noiseTokens = ["Chq No.", "Chq.", "Ref No.", "Ref:", "MICR:", "IFSC:", "Txn#",
                           "THIS ST", "SENT", "RECEIVED", "USIN G", "USING"]
        for token in noiseTokens {
            desc = desc.replacingOccurrences(of: token, with: "", options: .caseInsensitive)
        }

        // Collapse multiple spaces and trim
        desc = desc.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        desc = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        desc = desc.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        return desc
    }

    // MARK: - Utility Helpers

    private func isSeparatorLine(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: " ", with: "")
        guard !stripped.isEmpty else { return true }
        return stripped.allSatisfy { "-=*_.|+".contains($0) }
    }

    private func isPageHeaderOrFooter(_ line: String) -> Bool {
        let lower = line.lowercased().trimmingCharacters(in: .whitespaces)
        // Only skip very clear non-transaction metadata lines
        if lower.contains("page ") && lower.contains(" of ") { return true }
        if lower.contains("statement of account") { return true }
        if lower.hasPrefix("opening balance") { return true }
        if lower.hasPrefix("closing balance") { return true }
        if lower.contains("this is a computer generated") { return true }
        if lower.contains("contents of this") { return true }
        // Only exact "account no" headers, not "account no" inside a transaction
        if lower.hasPrefix("account no") { return true }
        if lower.hasPrefix("a/c no") { return true }
        return false
    }

    private func looksLikeNonTransactionLine(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        // Only skip lines that clearly begin with non-transaction markers
        if lower.hasPrefix("opening balance") { return true }
        if lower.hasPrefix("closing balance") { return true }
        if lower.hasPrefix("statement summary") { return true }
        if lower.hasPrefix("account number") { return true }
        if lower.hasPrefix("customer id") { return true }
        if lower.hasPrefix("nomination") { return true }
        // Skip "total" only at start of line (not "Total Cab Fare" etc.)
        if lower.hasPrefix("total ") && !lower.contains("total cab") && !lower.contains("total amount") { return true }
        return false
    }

    /// Fallback: enhanced line-by-line parsing (uses same infrastructure)
    private func parseLineByLine(lines: [String]) -> [ParsedRow] {
        var transactions: [ParsedRow] = []
        for line in lines {
            if let parsed = parseTransactionLine(line) {
                transactions.append(parsed)
            }
        }
        return transactions
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

        return ParseResult(transactions: transactions, errors: errors, fileName: fileName, source: .csv)
    }

    // MARK: - Line Parsing (Fallback)

    /// Attempts to parse a single text line as a transaction using the improved
    /// trailing-number extraction approach.
    private func parseTransactionLine(_ line: String) -> ParsedRow? {
        guard let (date, remaining) = extractDate(from: line) else { return nil }

        let (desc, numbers, crDr) = extractTrailingNumbers(from: remaining)
        guard !numbers.isEmpty else { return nil }

        var cleanDesc = cleanDescription(desc)
        if cleanDesc.isEmpty { cleanDesc = "Transaction" }

        let (amount, type) = resolveAmount(
            numbers: numbers,
            crDr: crDr,
            expectedColumns: 2,
            hasDebitCredit: false,
            description: cleanDesc
        )

        guard amount > 0.001 else { return nil }

        return ParsedRow(date: date, description: cleanDesc, amount: amount, type: type)
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
            "\\d{2}[/-]\\d{2}[/-]\\d{2}(?!\\d)",
            "\\d{2}[/-][A-Za-z]{3}[/-]\\d{4}",
            "\\d{2}[/-][A-Za-z]{3}[/-]\\d{2}(?!\\d)",
            "\\d{2}\\s+[A-Za-z]{3}\\s+\\d{4}",
            "\\d{2}\\s+[A-Za-z]{3}\\s+\\d{2}(?!\\d)",
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
                    let fixedDate = fixCentury(date)
                    return (fixedDate, remaining)
                }
            }
        }
        return nil
    }

    /// Fix 2-digit year parsing: year 26 → 2026, not 0026
    private func fixCentury(_ date: Date) -> Date {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        if year < 100 {
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            components.year = year + 2000
            return calendar.date(from: components) ?? date
        }
        return date
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

    /// Extract a merchant name from a bank description.
    /// Handles Indian bank narration formats:
    ///   UPI-MERCHANT-upiaddr-BANKCODE-REFNUM
    ///   NEFT CR-REFNUM-SENDER NAME
    ///   POS REFNUM MERCHANT NAME
    ///   BIL/BPAY/REF/PAYEE
    ///   FT - CR - - ACJF... (fund transfers)
    static func extractMerchant(from description: String) -> String {
        var cleaned = description

        // Fix PDFKit text-split artifacts
        let splitFixes: [(String, String)] = [
            (#"TRANSACTI\s*ON"#, "TRANSACTION"),
            (#"US\s*ING"#, "USING"),
            (#"USIN\s*G"#, "USING"),
            (#"P\s*ARKS"#, "PARKS"),
            (#"LIMI\s*TED"#, "LIMITED"),
            (#"BROKING\s+LIMI\b"#, "BROKING LIMITED"),
            (#"PAY\s*MENT"#, "PAYMENT"),
            (#"TRANS\s*FER"#, "TRANSFER"),
            (#"REVER\s*SAL"#, "REVERSAL"),
            (#"SER\s*VICE"#, "SERVICE"),
            (#"PUR\s*CHASE"#, "PURCHASE"),
            (#"MCHUPI"#, "UPI"),
        ]
        for (pattern, replacement) in splitFixes {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: replacement, options: [.regularExpression, .caseInsensitive])
        }

        // Remove common transaction type prefixes
        let prefixes = ["UPI/", "UPI-", "NEFT/", "NEFT-", "NEFT CR-", "NEFT CR/", "NEFT DR-", "NEFT DR/",
                        "IMPS/", "IMPS-", "POS/", "POS ", "ATM/", "ATM-", "ATM ",
                        "BIL/", "BIL-", "BPAY/", "EMI/", "SI/", "ACH/", "ACH-",
                        "FT - CR - -", "FT - DR - -", "FT-CR-", "FT-DR-",
                        "FT - CR", "FT - DR", "FT-CR", "FT-DR",
                        "BY TRANSFER-", "BY CLG-", "TO TRANSFER-"]
        // Sort by length descending so longer prefixes match first
        let sortedPrefixes = prefixes.sorted { $0.count > $1.count }
        for prefix in sortedPrefixes {
            if cleaned.uppercased().hasPrefix(prefix.uppercased()) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                break // Only remove the first matching prefix
            }
        }

        // For UPI: split by - or / and take the merchant name part (usually 2nd segment)
        // Format: UPI-MERCHANT-upiaddr-BANKCODE-REFNUM
        if description.uppercased().hasPrefix("UPI") {
            let segments = cleaned.components(separatedBy: CharacterSet(charactersIn: "-/"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if let merchantSegment = segments.first(where: { segment in
                let s = segment.lowercased()
                // Skip segments that look like references, UPI addresses, or bank codes
                return !s.contains("@") &&
                       s.range(of: #"^\d+$"#, options: .regularExpression) == nil &&
                       s.range(of: #"^[A-Z]{3,}\d{4,}"#, options: .regularExpression) == nil &&
                       s.count > 2
            }) {
                cleaned = merchantSegment
            }
        }

        // Remove clear bank reference codes: 4+ letters followed by 5+ digits
        cleaned = cleaned.replacingOccurrences(
            of: #"\b[A-Z]{4,}\d{5,}\b"#, with: "", options: .regularExpression
        )
        // Remove very long alphanumeric codes (12+ chars, clearly references)
        cleaned = cleaned.replacingOccurrences(
            of: #"\b[A-Z0-9]{12,}\b"#, with: "", options: .regularExpression
        )

        // Remove reference numbers (8+ consecutive digits)
        cleaned = cleaned.replacingOccurrences(
            of: #"\b\d{8,}\b"#, with: "", options: .regularExpression
        )

        // Remove embedded amounts (e.g., "12,128.00")
        cleaned = cleaned.replacingOccurrences(
            of: #"\b\d{1,3}(,\d{2,3})*\.\d{2}\b"#, with: "", options: .regularExpression
        )

        // Remove UPI addresses (name@bank)
        cleaned = cleaned.replacingOccurrences(
            of: #"\S+@\S+"#, with: "", options: .regularExpression
        )

        // Remove noise fragments
        let noiseWords: Set<String> = ["sent", "received", "usin", "using", "this", "st",
                                        "cr", "dr", "ft", "acjf", "ach", "mb", "ib", "ob"]
        var words = cleaned.components(separatedBy: CharacterSet(charactersIn: "-/ "))
            .map { $0.trimmingCharacters(in: CharacterSet.alphanumerics.inverted) }
            .filter { !$0.isEmpty && !noiseWords.contains($0.lowercased()) }

        // Remove any remaining pure-digit words
        words = words.filter { $0.range(of: #"^\d+$"#, options: .regularExpression) == nil }

        if words.isEmpty {
            // Fallback: use first meaningful part of original
            let fallback = description.prefix(30).trimmingCharacters(in: .whitespaces)
            return fallback.isEmpty ? "Unknown" : fallback
        }

        // Capitalize nicely - take up to 3 meaningful words
        return words.prefix(3).map { word in
            if word.count <= 3 { return word.uppercased() }
            return word.prefix(1).uppercased() + word.dropFirst().lowercased()
        }.joined(separator: " ")
    }

    private static func keywordMatch(_ text: String) -> String {
        // Use word boundary matching to avoid false positives like "health" matching inside other words
        func containsWord(_ keyword: String) -> Bool {
            // For multi-word keywords, plain contains is fine
            if keyword.contains(" ") || keyword.contains("&") {
                return text.contains(keyword)
            }
            // For single words, match on word boundaries to avoid partial matches
            // e.g., "bus" shouldn't match "business", "auto" shouldn't match "autocomplete"
            if keyword.count <= 3 {
                // Short keywords: require word boundary
                return text.range(of: #"\b"# + NSRegularExpression.escapedPattern(for: keyword) + #"\b"#,
                                  options: .regularExpression) != nil
            }
            return text.contains(keyword)
        }

        let incomeKeywords = ["salary", "credit interest", "refund", "cashback", "dividend",
                              "rent received", "freelance", "payment received", "bonus",
                              "neft cr", "imps cr", "by transfer"]

        let foodKeywords = ["zomato", "swiggy", "food", "restaurant", "cafe", "pizza",
                            "burger", "domino", "mcdonald", "kfc", "starbucks", "dunkin",
                            "grocery", "grocer", "bigbasket", "blinkit", "instamart",
                            "zepto", "dmart", "supermarket", "bakery", "dairy", "meat",
                            "chicken", "fish", "vegetable", "fruit", "canteen", "mess",
                            "biryani", "dosa", "meals", "tiffin", "lunch", "dinner", "breakfast"]

        let transportKeywords = ["uber", "ola", "rapido", "petrol", "diesel", "fuel",
                                  "parking", "toll", "fastag", "metro", "railway", "irctc",
                                  "car wash", "service station",
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
                              "gym", "fitness", "yoga", "diagnostic",
                              "star health", "max bupa", "health insurance"]

        let utilityKeywords = ["electricity", "electric", "power", "bescom", "tata power",
                               "water bill", "gas bill", "internet", "broadband", "wifi",
                               "airtel", "vodafone", "bsnl", "phone", "mobile",
                               "recharge", "dth", "piped gas", "lpg", "maintenance", "society"]

        let financeKeywords = ["mutual fund", "sip", "fixed deposit",
                                "recurring deposit", "loan", "emi", "premium", "lic",
                                "investment", "stock", "share", "demat", "zerodha",
                                "groww", "kuvera", "ppf", "nps", "interest"]

        // Bank fees/charges
        let bankKeywords = ["hdfc bank", "icici bank", "sbi", "axis bank", "kotak",
                            "bank charge", "bank fee", "annual fee", "service charge",
                            "gst", "stamp duty", "bank limited"]

        if incomeKeywords.contains(where: { containsWord($0) }) { return "Income" }
        if foodKeywords.contains(where: { containsWord($0) }) { return "Food" }
        if transportKeywords.contains(where: { containsWord($0) }) { return "Transport" }
        if shoppingKeywords.contains(where: { containsWord($0) }) { return "Shopping" }
        if entertainmentKeywords.contains(where: { containsWord($0) }) { return "Entertainment" }
        if healthKeywords.contains(where: { containsWord($0) }) { return "Health" }
        if utilityKeywords.contains(where: { containsWord($0) }) { return "Utilities" }
        if financeKeywords.contains(where: { containsWord($0) }) { return "Finance" }
        if bankKeywords.contains(where: { containsWord($0) }) { return "Finance" }

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
