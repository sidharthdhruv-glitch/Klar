import Foundation

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
        // XLSX = ZIP archive. Unzip to a temp directory and parse the XML inside.
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("klar_xlsx_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try unzipFile(at: url, to: tempDir)

        // Parse shared strings (xl/sharedStrings.xml)
        let sharedStrings = parseSharedStrings(in: tempDir)

        // Discover worksheets from xl/workbook.xml
        let sheetNames = parseWorkbookSheetNames(in: tempDir)

        // Parse each worksheet and pick the one with the most rows
        var bestResult: ExcelResult?
        var bestRowCount = 0

        let worksheetsDir = tempDir.appendingPathComponent("xl/worksheets")
        let sheetFiles = (try? FileManager.default.contentsOfDirectory(
            at: worksheetsDir, includingPropertiesForKeys: nil
        )) ?? []

        for sheetFile in sheetFiles where sheetFile.pathExtension == "xml" {
            let sheetIndex = extractSheetIndex(from: sheetFile.lastPathComponent)
            let sheetName = (sheetIndex != nil && sheetIndex! <= sheetNames.count)
                ? sheetNames[sheetIndex! - 1]
                : sheetFile.deletingPathExtension().lastPathComponent

            if let result = try parseWorksheetXML(at: sheetFile,
                                                   sheetName: sheetName,
                                                   sharedStrings: sharedStrings),
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

    // MARK: - ZIP Extraction

    /// Unzips a file using the built-in `unzip` command (available on all Apple platforms).
    private static func unzipFile(at source: URL, to destination: URL) throws {
        // Verify it looks like a ZIP (PK magic bytes)
        let data = try Data(contentsOf: source, options: .mappedIfSafe)
        guard data.count >= 4 else { throw ExcelError.cannotOpenFile(source.path) }
        let magic = [UInt8](data.prefix(4))
        guard magic[0] == 0x50, magic[1] == 0x4B else {
            throw ExcelError.notAZipArchive
        }

        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        // Use Process to unzip (available on iOS simulator / macOS; for device,
        // we fall back to manual ZIP parsing below)
        #if targetEnvironment(simulator) || os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", "-q", source.path, "-d", destination.path]
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw ExcelError.cannotOpenFile(source.path)
        }
        #else
        // On-device: use Foundation's built-in decompression
        try unzipManually(data: data, to: destination)
        #endif
    }

    /// Manual ZIP extraction using Foundation for on-device builds.
    /// Handles the basic ZIP local file header format used by XLSX files.
    private static func unzipManually(data: Data, to destination: URL) throws {
        var offset = 0
        let bytes = [UInt8](data)

        while offset + 30 <= bytes.count {
            // Check for local file header signature: PK\x03\x04
            guard bytes[offset] == 0x50, bytes[offset+1] == 0x4B,
                  bytes[offset+2] == 0x03, bytes[offset+3] == 0x04 else { break }

            let compressionMethod = UInt16(bytes[offset+8]) | (UInt16(bytes[offset+9]) << 8)
            let compressedSize = Int(UInt32(bytes[offset+18]) | (UInt32(bytes[offset+19]) << 8)
                | (UInt32(bytes[offset+20]) << 16) | (UInt32(bytes[offset+21]) << 24))
            let uncompressedSize = Int(UInt32(bytes[offset+22]) | (UInt32(bytes[offset+23]) << 8)
                | (UInt32(bytes[offset+24]) << 16) | (UInt32(bytes[offset+25]) << 24))
            let nameLength = Int(UInt16(bytes[offset+26]) | (UInt16(bytes[offset+27]) << 8))
            let extraLength = Int(UInt16(bytes[offset+28]) | (UInt16(bytes[offset+29]) << 8))

            let nameStart = offset + 30
            guard nameStart + nameLength <= bytes.count else { break }
            let nameData = Data(bytes[nameStart..<(nameStart + nameLength)])
            guard let name = String(data: nameData, encoding: .utf8) else {
                offset = nameStart + nameLength + extraLength + compressedSize
                continue
            }

            let dataStart = nameStart + nameLength + extraLength
            guard dataStart + compressedSize <= bytes.count else { break }

            let fileURL = destination.appendingPathComponent(name)

            if name.hasSuffix("/") {
                try FileManager.default.createDirectory(at: fileURL,
                    withIntermediateDirectories: true)
            } else {
                let dir = fileURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: dir,
                    withIntermediateDirectories: true)

                let compressedData = Data(bytes[dataStart..<(dataStart + compressedSize)])

                if compressionMethod == 0 {
                    // Stored (no compression)
                    try compressedData.write(to: fileURL)
                } else if compressionMethod == 8 {
                    // Deflate — use Foundation's decompression
                    // Add zlib header (0x78 0x01) for raw deflate data
                    var zlibData = Data([0x78, 0x01])
                    zlibData.append(compressedData)
                    if let decompressed = try? (zlibData as NSData).decompressed(using: .zlib) as Data {
                        try decompressed.write(to: fileURL)
                    } else if uncompressedSize == 0 {
                        // Empty file
                        try Data().write(to: fileURL)
                    }
                }
            }

            offset = dataStart + compressedSize
        }
    }

    // MARK: - Shared Strings Parsing

    /// Parses xl/sharedStrings.xml to build the shared string table.
    /// XLSX stores repeated strings once here and references them by index in cells.
    private static func parseSharedStrings(in directory: URL) -> [String] {
        let path = directory.appendingPathComponent("xl/sharedStrings.xml")
        guard let data = try? Data(contentsOf: path) else { return [] }

        let parser = SharedStringsXMLParser(data: data)
        return parser.parse()
    }

    // MARK: - Workbook Parsing

    /// Parses xl/workbook.xml to get sheet names in order.
    private static func parseWorkbookSheetNames(in directory: URL) -> [String] {
        let path = directory.appendingPathComponent("xl/workbook.xml")
        guard let data = try? Data(contentsOf: path) else { return [] }

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

    /// Parses a single worksheet XML file into headers + rows.
    private static func parseWorksheetXML(at url: URL,
                                           sheetName: String,
                                           sharedStrings: [String]) throws -> ExcelResult? {
        guard let data = try? Data(contentsOf: url) else { return nil }

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

    private var rows: [[String]] = []        // Final output: array of rows, each row = array of cell values
    private var currentRowCells: [(col: Int, value: String)] = []
    private var currentCellRef = ""
    private var currentCellType = ""
    private var currentValue = ""
    private var insideV = false               // Inside <v> (value) element
    private var insideIS = false              // Inside <is> (inline string) element
    private var insideT = false              // Inside <t> (text) element within <is>
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
            // Resolve cell value
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
            // Convert sparse cells to a dense row array
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
