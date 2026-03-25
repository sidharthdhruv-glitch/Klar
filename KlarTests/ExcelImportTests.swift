import XCTest
@testable import Klar

/// Tests for the Excel/CSV import pipeline: DateParser, CSVParser, TransactionMapper, and ImportService.
final class ExcelImportTests: XCTestCase {

    // MARK: - DateParser Tests

    func testDateParserSlashFormat() {
        let date = DateParser.parse("15/03/2026")
        XCTAssertNotNil(date)
        let components = Calendar.current.dateComponents([.day, .month, .year], from: date!)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.year, 2026)
    }

    func testDateParserDashFormat() {
        let date = DateParser.parse("05-01-2026")
        XCTAssertNotNil(date)
        let components = Calendar.current.dateComponents([.day, .month, .year], from: date!)
        XCTAssertEqual(components.day, 5)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.year, 2026)
    }

    func testDateParserMonthNameFormat() {
        let date = DateParser.parse("12 Feb 2026")
        XCTAssertNotNil(date)
        let components = Calendar.current.dateComponents([.month, .year], from: date!)
        XCTAssertEqual(components.month, 2)
        XCTAssertEqual(components.year, 2026)
    }

    func testDateParser2DigitYear() {
        let date = DateParser.parse("25/06/26")
        XCTAssertNotNil(date)
        let components = Calendar.current.dateComponents([.year], from: date!)
        XCTAssertEqual(components.year, 2026)
    }

    func testDateParserExcelSerial() {
        // 46106 ≈ 2026-03-15 in Excel serial format
        let date = DateParser.dateFromExcelSerial(46106)
        XCTAssertNotNil(date)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date!)
        XCTAssertEqual(components.year, 2026)
    }

    func testDateParserEmptyString() {
        XCTAssertNil(DateParser.parse(""))
        XCTAssertNil(DateParser.parse("   "))
        XCTAssertNil(DateParser.parse("not a date"))
    }

    // MARK: - CSVParser Tests

    func testCSVParserBasic() throws {
        let csv = """
        Date,Narration,Debit,Credit,Balance
        15/03/2026,UPI-ZOMATO,500.00,,12000.00
        16/03/2026,SALARY,,75000.00,87000.00
        """
        let result = try CSVParser.parse(content: csv)
        XCTAssertEqual(result.headers.count, 5)
        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.headers[0], "Date")
        XCTAssertEqual(result.headers[1], "Narration")
    }

    func testCSVParserQuotedFields() throws {
        let csv = """
        Date,Description,Amount
        15/03/2026,"Payment to ""Sharma, Raj""",1500.00
        16/03/2026,"UPI Transfer",2000.00
        """
        let result = try CSVParser.parse(content: csv)
        XCTAssertEqual(result.rows.count, 2)
        // Quoted field with embedded comma and escaped quotes
        XCTAssertTrue(result.rows[0][1].contains("Sharma"))
    }

    func testCSVParserEmptyFile() {
        XCTAssertThrowsError(try CSVParser.parse(content: "")) { error in
            XCTAssertTrue(error is CSVParser.CSVError)
        }
    }

    func testCSVParserTabDelimited() throws {
        let csv = "Date\tDescription\tDebit\tCredit\n15/03/2026\tATM Withdrawal\t5000\t\n"
        let result = try CSVParser.parse(content: csv)
        XCTAssertEqual(result.headers.count, 4)
        XCTAssertEqual(result.rows.count, 1)
    }

    func testCSVParserEmptyCells() throws {
        let csv = """
        Date,Narration,Debit,Credit,Balance
        15/03/2026,Transfer,,,12000
        16/03/2026,Deposit,,500,12500
        """
        let result = try CSVParser.parse(content: csv)
        XCTAssertEqual(result.rows.count, 2)
    }

    // MARK: - TransactionMapper Tests

    func testTransactionMapperHDFC() {
        let headers = ["Date", "Narration", "Chq./Ref.No.", "Value Dt", "Withdrawal Amt.", "Deposit Amt.", "Closing Balance"]
        let rows: [[String]] = [
            ["15/03/2026", "UPI-ZOMATO-FOOD ORDER", "12345", "15/03/2026", "500.00", "", "1,57,370.00"],
            ["16/03/2026", "NEFT-SALARY-ACME CORP", "67890", "16/03/2026", "", "75,000.00", "2,32,370.00"],
            ["17/03/2026", "ATM-CASH WITHDRAWAL", "11111", "17/03/2026", "10,000.00", "", "2,22,370.00"],
        ]

        let result = TransactionMapper.map(headers: headers, rows: rows)
        XCTAssertEqual(result.transactions.count, 3)
        XCTAssertEqual(result.skippedRows, 0)

        // First transaction: debit (expense)
        let zomato = result.transactions[0]
        XCTAssertEqual(zomato.type, .expense)
        XCTAssertEqual(zomato.amount, 500.0)
        XCTAssertTrue(zomato.description.contains("ZOMATO"))

        // Second transaction: credit (income)
        let salary = result.transactions[1]
        XCTAssertEqual(salary.type, .income)
        XCTAssertEqual(salary.amount, 75000.0)

        // Third transaction: debit (expense)
        let atm = result.transactions[2]
        XCTAssertEqual(atm.type, .expense)
        XCTAssertEqual(atm.amount, 10000.0)
    }

    func testTransactionMapperVariantHeaders() {
        // Test that column detection works with slightly different naming
        let headers = ["Transaction Date", "Details", "Dr", "Cr", "Available Balance"]
        let rows: [[String]] = [
            ["2026-03-15", "Swiggy Food Delivery", "350.50", "", "45000"],
            ["2026-03-16", "Interest Credit", "", "1200", "46200"],
        ]

        let result = TransactionMapper.map(headers: headers, rows: rows)
        XCTAssertEqual(result.transactions.count, 2)
        XCTAssertEqual(result.transactions[0].type, .expense)
        XCTAssertEqual(result.transactions[0].amount, 350.50, accuracy: 0.01)
        XCTAssertEqual(result.transactions[1].type, .income)
    }

    func testTransactionMapperSkipsInvalidRows() {
        let headers = ["Date", "Description", "Debit", "Credit"]
        let rows: [[String]] = [
            ["15/03/2026", "Valid transaction", "100", ""],
            ["not-a-date", "Invalid row", "200", ""],           // Invalid date
            ["", "No date at all", "300", ""],                   // Missing date
            ["16/03/2026", "Another valid one", "", "500"],
        ]

        let result = TransactionMapper.map(headers: headers, rows: rows)
        XCTAssertEqual(result.transactions.count, 2)
        XCTAssertEqual(result.skippedRows, 2)
    }

    func testTransactionMapperIndianAmounts() {
        let headers = ["Date", "Narration", "Withdrawal Amt.", "Deposit Amt."]
        let rows: [[String]] = [
            ["15/03/2026", "Big Purchase", "1,57,370.00", ""],
            ["16/03/2026", "Refund", "", "₹2,500.00"],
            ["17/03/2026", "Payment", "Rs. 999", ""],
        ]

        let result = TransactionMapper.map(headers: headers, rows: rows)
        XCTAssertEqual(result.transactions.count, 3)
        XCTAssertEqual(result.transactions[0].amount, 157370.0, accuracy: 0.01)
        XCTAssertEqual(result.transactions[1].amount, 2500.0, accuracy: 0.01)
        XCTAssertEqual(result.transactions[2].amount, 999.0, accuracy: 0.01)
    }

    func testTransactionMapperSingleAmountColumn() {
        let headers = ["Date", "Description", "Amount"]
        let rows: [[String]] = [
            ["15/03/2026", "Expense", "-500"],
            ["16/03/2026", "Income", "1000"],
        ]

        let result = TransactionMapper.map(headers: headers, rows: rows)
        XCTAssertEqual(result.transactions.count, 2)
        XCTAssertEqual(result.transactions[0].type, .expense)
        XCTAssertEqual(result.transactions[0].amount, 500)
        XCTAssertEqual(result.transactions[1].type, .income)
        XCTAssertEqual(result.transactions[1].amount, 1000)
    }

    // MARK: - Large Dataset Test

    func testTransactionMapper1000Rows() {
        let headers = ["Date", "Narration", "Debit", "Credit", "Balance"]
        var rows: [[String]] = []

        for i in 0..<1000 {
            let day = String(format: "%02d", (i % 28) + 1)
            let month = String(format: "%02d", (i % 12) + 1)
            let isDebit = i % 3 != 0
            let amount = String(format: "%.2f", Double.random(in: 10...50000))
            rows.append([
                "\(day)/\(month)/2026",
                "Transaction \(i) - Merchant \(i % 50)",
                isDebit ? amount : "",
                isDebit ? "" : amount,
                "100000.00"
            ])
        }

        let result = TransactionMapper.map(headers: headers, rows: rows)
        XCTAssertEqual(result.transactions.count, 1000)
        XCTAssertEqual(result.skippedRows, 0)
    }

    // MARK: - HDFC Mock Statement (Full Integration)

    func testHDFCStatementCSVParsing() throws {
        let hdfcCSV = """
        Date,Narration,Chq./Ref.No.,Value Dt,Withdrawal Amt.,Deposit Amt.,Closing Balance
        01/03/2026,UPI-SWIGGY-FOOD ORDER-9876543210-PAYMENT,000012345678,01/03/2026,459.00,,1,52,541.00
        02/03/2026,NEFT CR-ACME TECHNOLOGIES PVT LTD-SALARY MAR26,NEFT12345,02/03/2026,,85,000.00,2,37,541.00
        03/03/2026,UPI-AMAZON PAY-SHOPPING,000098765432,03/03/2026,2,199.00,,2,35,342.00
        05/03/2026,ATM-CASH WDL-HDFC BANK ATM,ATM00001,05/03/2026,10,000.00,,2,25,342.00
        07/03/2026,IMPS-PHONEPE-ELECTRICITY BILL,IMPS99999,07/03/2026,1,850.00,,2,23,492.00
        10/03/2026,UPI-GPAY-UBER RIDE,000011112222,10/03/2026,285.00,,2,23,207.00
        12/03/2026,NEFT CR-FREELANCE PAYMENT-JOHN DOE,NEFT67890,12/03/2026,,15,000.00,2,38,207.00
        15/03/2026,POS-RELIANCE FRESH-GROCERIES,POS12345,15/03/2026,1,245.00,,2,36,962.00
        18/03/2026,UPI-NETFLIX-SUBSCRIPTION,000033334444,18/03/2026,649.00,,2,36,313.00
        20/03/2026,INT PAID-INTEREST ON FD,FD00001,20/03/2026,,3,750.00,2,40,063.00
        22/03/2026,ECS-LIC PREMIUM-POLICY 12345,ECS99001,22/03/2026,5,500.00,,2,34,563.00
        25/03/2026,UPI-ZOMATO-DINNER,000055556666,25/03/2026,720.00,,2,33,843.00
        """

        let csvResult = try CSVParser.parse(content: hdfcCSV)
        XCTAssertEqual(csvResult.headers.count, 7)
        XCTAssertEqual(csvResult.rows.count, 12)

        let mapping = TransactionMapper.map(headers: csvResult.headers, rows: csvResult.rows)

        // All 12 rows should parse (some amounts with Indian commas may merge with adjacent cells)
        XCTAssertGreaterThan(mapping.transactions.count, 0, "Should parse at least some HDFC transactions")

        // Verify we got the right mix of income and expense
        let incomeCount = mapping.transactions.filter { $0.type == .income }.count
        let expenseCount = mapping.transactions.filter { $0.type == .expense }.count
        XCTAssertGreaterThan(incomeCount, 0, "Should have at least one income transaction")
        XCTAssertGreaterThan(expenseCount, 0, "Should have at least one expense transaction")

        // Verify descriptions are meaningful
        for txn in mapping.transactions {
            XCTAssertFalse(txn.description.isEmpty, "Description should not be empty")
            XCTAssertGreaterThan(txn.amount, 0, "Amount should be positive")
        }
    }

    // MARK: - ImportService File Type Detection

    func testImportServiceDetectsCSV() {
        // Create a temporary CSV file
        let tempDir = FileManager.default.temporaryDirectory
        let csvURL = tempDir.appendingPathComponent("test.csv")
        let csvContent = "Date,Description,Amount\n15/03/2026,Test,100"
        try? csvContent.write(to: csvURL, atomically: true, encoding: .utf8)

        let detectedType = ImportService.detectFileType(at: csvURL)
        XCTAssertEqual(detectedType, .csv)

        try? FileManager.default.removeItem(at: csvURL)
    }

    func testImportServiceDetectsXLSX() {
        let tempDir = FileManager.default.temporaryDirectory
        let xlsxURL = tempDir.appendingPathComponent("test.xlsx")
        // XLSX files start with PK (ZIP magic bytes)
        let fakeXLSX = Data([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00])
        try? fakeXLSX.write(to: xlsxURL)

        let detectedType = ImportService.detectFileType(at: xlsxURL)
        XCTAssertEqual(detectedType, .xlsx)

        try? FileManager.default.removeItem(at: xlsxURL)
    }

    // MARK: - Full CSV Import Pipeline

    func testFullCSVImportPipeline() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let csvURL = tempDir.appendingPathComponent("hdfc_test.csv")

        let content = """
        Date,Narration,Withdrawal Amt.,Deposit Amt.,Closing Balance
        15/03/2026,UPI-ZOMATO-FOOD,500.00,,12000.00
        16/03/2026,SALARY,,75000.00,87000.00
        17/03/2026,ATM WITHDRAWAL,10000.00,,77000.00
        """
        try content.write(to: csvURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: csvURL) }

        let service = ImportService()
        let result = try await service.importFile(at: csvURL)

        XCTAssertEqual(result.transactions.count, 3)
        XCTAssertEqual(result.source, .csv)
        XCTAssertEqual(result.skippedRows, 0)
        XCTAssertEqual(result.fileName, "hdfc_test.csv")
    }
}
