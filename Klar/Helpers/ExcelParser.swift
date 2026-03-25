import Foundation
import Compression

/// Parses XLSX files using native Foundation APIs (no external dependencies).
/// XLSX files are ZIP archives containing XML. This parser extracts worksheets,
/// resolves shared strings, and returns headers + rows for TransactionMapper.
struct ExcelParser {

    // MARK: - Errors

    enum ExcelError: LocalizedError {
        case cannotOpenFile(String)
        case notAZipArchive
        case noWorksheets
        case corruptedXML(String)
        case noHeaderRow
        case decompressionFailed

        var errorDescription: String? {
            switch self {
            case .cannotOpenFile(let path):
                return "Cannot open Excel file at: \(path)"
            case .notAZipArchive:
                return "File is not a valid XLSX file (not a ZIP archive)."
            case .noWorksheets:
                return "The Excel file contains no worksheets with data."
            case .corruptedXML(let detail):
                return "Corrupted Excel XML: \(detail)"
            case .noHeaderRow:
                return "No header row found in the worksheet."
            case .decompressionFailed:
                return "Failed to decompress XLSX file contents."
            }
        }
    }

    /// Result of parsing — same shape as CSVParser for interoperability.
    struct ExcelResult {
        let headers: [String]
        let rows: [[String]]
        let sheetName: String
    }

    // MARK: - Public API

    /// Parses an XLSX file and returns the worksheet with the most data rows.
    static func parse(url: URL) throws -> ExcelResult {
        let data = try Data(contentsOf: url)

        // Verify ZIP magic bytes (PK\x03\x04)
        guard data.count >= 4,
              data[data.startIndex] == 0x50,
              data[data.startIndex + 1] == 0x4B else {
            throw ExcelError.notAZipArchive
        }

        // Extract all files from the ZIP archive
        let entries = try extractZIPEntries(from: data)

        // Parse shared strings (xl/sharedStrings.xml)
        let sharedStrings = parseSharedStrings(from: entries)

        // Get sheet names from workbook
        let sheetNames = parseWorkbookSheetNames(from: entries)

        // Find and parse all worksheet XMLs
        let worksheetEntries = entries.filter { key, _ in
            key.lowercased().hasPrefix("xl/worksheets/sheet") && key.lowercased().hasSuffix(".xml")
        }

        var bestResult: ExcelResult?
        var bestRowCount = 0

        for (path, xmlData) in worksheetEntries {
            let filename = (path as NSString).lastPathComponent
            let sheetIndex = extractSheetIndex(from: filename)
            let sheetName: String
            if let idx = sheetIndex, idx >= 1, idx <= sheetNames.count {
                sheetName = sheetNames[idx - 1]
            } else {
                sheetName = filename.replacingOccurrences(of: ".xml", with: "")
            }

            if let result = parseWorksheetXML(data: xmlData, sheetName: sheetName, sharedStrings: sharedStrings),
               result.rows.count > bestRowCount {
                bestResult = result
                bestRowCount = result.rows.count
            }
        }

        guard let result = bestResult else {
            throw ExcelError.noWorksheets
        }
        return result
    }

    // MARK: - ZIP Extraction (In-Memory)

    /// Extracts all files from a ZIP archive into a dictionary of path → Data.
    /// Works entirely in-memory — no temp files, no Process, fully iOS-compatible.
    private static func extractZIPEntries(from data: Data) throws -> [String: Data] {
        var entries: [String: Data] = [:]
        let bytes = [UInt8](data)
        var offset = 0

        while offset + 30 <= bytes.count {
            // Local file header signature: PK\x03\x04
            guard bytes[offset] == 0x50, bytes[offset + 1] == 0x4B,
                  bytes[offset + 2] == 0x03, bytes[offset + 3] == 0x04 else {
                break
            }

            let compressionMethod = readUInt16(bytes, at: offset + 8)
            var compressedSize = Int(readUInt32(bytes, at: offset + 18))
            let uncompressedSize = Int(readUInt32(bytes, at: offset + 22))
            let nameLength = Int(readUInt16(bytes, at: offset + 26))
            let extraLength = Int(readUInt16(bytes, at: offset + 28))

            let nameStart = offset + 30
            guard nameStart + nameLength <= bytes.count else { break }

            let nameData = Data(bytes[nameStart..<(nameStart + nameLength)])
            guard let name = String(data: nameData, encoding: .utf8) else {
                offset = nameStart + nameLength + extraLength + compressedSize
                continue
            }

            let dataStart = nameStart + nameLength + extraLength

            // Handle data descriptor (bit 3 of general purpose flags)
            let generalFlags = readUInt16(bytes, at: offset + 6)
            if generalFlags & 0x08 != 0 && compressedSize == 0 {
                // Data descriptor follows the compressed data — scan for next PK signature
                var scanOffset = dataStart
                while scanOffset + 4 <= bytes.count {
                    if bytes[scanOffset] == 0x50 && bytes[scanOffset + 1] == 0x4B {
                        break
                    }
                    scanOffset += 1
                }
                compressedSize = scanOffset - dataStart
                // Check for data descriptor header (optional PK\x07\x08 signature)
                if scanOffset >= dataStart + 16 {
                    let possibleSig = dataStart + compressedSize - 16
                    if bytes[possibleSig] == 0x50 && bytes[possibleSig + 1] == 0x4B &&
                       bytes[possibleSig + 2] == 0x07 && bytes[possibleSig + 3] == 0x08 {
                        compressedSize -= 16
                    }
                }
            }

            guard dataStart + compressedSize <= bytes.count else { break }

            // Skip directories
            if !name.hasSuffix("/") && compressedSize > 0 {
                let compressedData = Data(bytes[dataStart..<(dataStart + compressedSize)])

                if compressionMethod == 0 {
                    // Stored (no compression)
                    entries[name] = compressedData
                } else if compressionMethod == 8 {
                    // Deflate — decompress using Apple's Compression framework
                    if let decompressed = decompressDeflate(compressedData, expectedSize: max(uncompressedSize, compressedSize * 4)) {
                        entries[name] = decompressed
                    }
                }
            }

            offset = dataStart + compressedSize

            // Skip data descriptor if present
            if generalFlags & 0x08 != 0 {
                if offset + 4 <= bytes.count &&
                   bytes[offset] == 0x50 && bytes[offset + 1] == 0x4B &&
                   bytes[offset + 2] == 0x07 && bytes[offset + 3] == 0x08 {
                    offset += 16 // Signature + CRC + compressed + uncompressed sizes
                } else if offset + 12 <= bytes.count {
                    offset += 12 // CRC + compressed + uncompressed sizes (no signature)
                }
            }
        }

        return entries
    }

    /// Reads a little-endian UInt16 from a byte array.
    private static func readUInt16(_ bytes: [UInt8], at offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    /// Reads a little-endian UInt32 from a byte array.
    private static func readUInt32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | (UInt32(bytes[offset + 1]) << 8) |
        (UInt32(bytes[offset + 2]) << 16) | (UInt32(bytes[offset + 3]) << 24)
    }

    // MARK: - Deflate Decompression

    /// Decompresses raw deflate data using Apple's Compression framework.
    /// This is the correct approach for ZIP files which store raw deflate (RFC 1951),
    /// NOT zlib-wrapped data (RFC 1950).
    private static func decompressDeflate(_ compressedData: Data, expectedSize: Int) -> Data? {
        // Use a generous buffer — some files decompress to much larger sizes
        let bufferSize = max(expectedSize, compressedData.count * 8)
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }

        let decodedSize = compressedData.withUnsafeBytes { sourceBuffer -> Int in
            guard let baseAddress = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return compression_decode_buffer(
                destinationBuffer, bufferSize,
                baseAddress, compressedData.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard decodedSize > 0 else { return nil }
        return Data(bytes: destinationBuffer, count: decodedSize)
    }

    // MARK: - Shared Strings Parsing

    /// Parses xl/sharedStrings.xml to build the shared string table.
    private static func parseSharedStrings(from entries: [String: Data]) -> [String] {
        // Try both casing variants
        let key = entries.keys.first { $0.lowercased() == "xl/sharedstrings.xml" } ?? "xl/sharedStrings.xml"
        guard let data = entries[key] else { return [] }
        let parser = SharedStringsXMLParser(data: data)
        return parser.parse()
    }

    // MARK: - Workbook Parsing

    /// Parses xl/workbook.xml to get sheet names in order.
    private static func parseWorkbookSheetNames(from entries: [String: Data]) -> [String] {
        let key = entries.keys.first { $0.lowercased() == "xl/workbook.xml" } ?? "xl/workbook.xml"
        guard let data = entries[key] else { return [] }
        let parser = WorkbookXMLParser(data: data)
        return parser.parse()
    }

    /// Extracts the sheet number from a filename like "sheet1.xml" → 1
    private static func extractSheetIndex(from filename: String) -> Int? {
        let name = filename.replacingOccurrences(of: ".xml", with: "")
        let digits = name.filter { $0.isNumber }
        return Int(digits)
    }

    // MARK: - Worksheet XML Parsing

    /// Parses a single worksheet XML into headers + rows.
    private static func parseWorksheetXML(data: Data, sheetName: String, sharedStrings: [String]) -> ExcelResult? {
        let parser = WorksheetXMLParser(data: data, sharedStrings: sharedStrings)
        let allRows = parser.parse()

        guard !allRows.isEmpty else { return nil }

        // Normalize: pad all rows to the same column count
        let maxCols = allRows.map { $0.count }.max() ?? 0
        guard maxCols > 0 else { return nil }

        let normalized = allRows.map { row -> [String] in
            var padded = row
            while padded.count < maxCols { padded.append("") }
            return padded
        }

        // Find header row: first row with >= 3 non-empty cells
        guard let headerIdx = normalized.firstIndex(where: { row in
            row.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count >= 3
        }) else { return nil }

        let headers = normalized[headerIdx].map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let dataRows = Array(normalized[(headerIdx + 1)...]).filter { row in
            !row.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        }

        guard !dataRows.isEmpty else { return nil }

        return ExcelResult(headers: headers, rows: dataRows, sheetName: sheetName)
    }
}

// MARK: - XML Parsers

/// Parses xl/sharedStrings.xml to extract all <si> string items.
private class SharedStringsXMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var strings: [String] = []
    private var currentText = ""
    private var insideSI = false
    private var insideT = false

    init(data: Data) {
        self.data = data
    }

    func parse() -> [String] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return strings
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        if elementName == "si" {
            insideSI = true
            currentText = ""
        } else if elementName == "t" && insideSI {
            insideT = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideT {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        if elementName == "t" {
            insideT = false
        } else if elementName == "si" {
            strings.append(currentText)
            insideSI = false
        }
    }
}

/// Parses xl/workbook.xml to extract sheet names.
private class WorkbookXMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var sheetNames: [String] = []

    init(data: Data) {
        self.data = data
    }

    func parse() -> [String] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return sheetNames
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        if elementName == "sheet", let name = attributes["name"] {
            sheetNames.append(name)
        }
    }
}

/// Parses a worksheet XML (xl/worksheets/sheetN.xml) to extract cell values.
/// Handles shared string references (t="s"), inline strings, and direct values.
private class WorksheetXMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private let sharedStrings: [String]

    private var rows: [[String]] = []
    private var currentRowCells: [(col: Int, value: String)] = []
    private var currentCellRef = ""
    private var currentCellType = ""
    private var currentValue = ""
    private var insideV = false
    private var insideIS = false
    private var insideT = false
    private var inlineText = ""

    init(data: Data, sharedStrings: [String]) {
        self.data = data
        self.sharedStrings = sharedStrings
    }

    func parse() -> [[String]] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return rows
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        switch elementName {
        case "row":
            currentRowCells = []
        case "c":
            currentCellRef = attributes["r"] ?? ""
            currentCellType = attributes["t"] ?? ""
            currentValue = ""
            inlineText = ""
        case "v":
            insideV = true
        case "is":
            insideIS = true
        case "t":
            if insideIS { insideT = true }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if insideV {
            currentValue += string
        } else if insideT {
            inlineText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "v":
            insideV = false
        case "t":
            insideT = false
        case "is":
            insideIS = false
        case "c":
            let resolved: String
            if currentCellType == "s" {
                // Shared string reference
                if let idx = Int(currentValue), idx < sharedStrings.count {
                    resolved = sharedStrings[idx]
                } else {
                    resolved = currentValue
                }
            } else if currentCellType == "inlineStr" || !inlineText.isEmpty {
                resolved = inlineText
            } else {
                resolved = currentValue
            }

            if let colIndex = columnIndexFromRef(currentCellRef) {
                currentRowCells.append((col: colIndex, value: resolved))
            }
        case "row":
            if !currentRowCells.isEmpty {
                let maxCol = currentRowCells.map { $0.col }.max() ?? 0
                var row = Array(repeating: "", count: maxCol + 1)
                for cell in currentRowCells {
                    row[cell.col] = cell.value
                }
                rows.append(row)
            }
        default:
            break
        }
    }

    /// Converts a cell reference like "C5" to a zero-based column index (2).
    private func columnIndexFromRef(_ ref: String) -> Int? {
        let letters = ref.prefix(while: { $0.isLetter })
        guard !letters.isEmpty else { return nil }

        var index = 0
        for char in letters.uppercased() {
            guard let ascii = char.asciiValue, ascii >= 65, ascii <= 90 else { return nil }
            index = index * 26 + Int(ascii - 64)
        }
        return index - 1
    }
}
