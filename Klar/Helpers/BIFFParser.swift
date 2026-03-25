import Foundation

/// Parses legacy .xls files (BIFF8 format inside OLE2 Compound File Binary Format).
/// This handles the binary Excel format used by Excel 97-2003 and commonly exported
/// by Indian bank portals (HDFC, ICICI, SBI, etc.)
struct BIFFParser {

    // MARK: - Errors

    enum BIFFError: LocalizedError {
        case notOLE2
        case corruptedFile(String)
        case noWorkbookStream
        case noData

        var errorDescription: String? {
            switch self {
            case .notOLE2:
                return "File is not a valid legacy Excel (.xls) file."
            case .corruptedFile(let detail):
                return "Corrupted .xls file: \(detail)"
            case .noWorkbookStream:
                return "No workbook data found in the .xls file."
            case .noData:
                return "The .xls file contains no data."
            }
        }
    }

    /// Result matches ExcelParser.ExcelResult for interoperability.
    struct BIFFResult {
        let headers: [String]
        let rows: [[String]]
        let sheetName: String
    }

    // MARK: - OLE2 Constants

    /// OLE2 Compound File magic bytes: D0 CF 11 E0 A1 B1 1A E1
    static let ole2Magic: [UInt8] = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]

    /// Checks if data starts with OLE2 magic bytes.
    static func isOLE2(_ data: Data) -> Bool {
        guard data.count >= 8 else { return false }
        return [UInt8](data.prefix(8)) == ole2Magic
    }

    // MARK: - BIFF Record Types

    private static let BOF: UInt16       = 0x0809
    private static let EOF_REC: UInt16   = 0x000A
    private static let SST: UInt16       = 0x00FC
    private static let CONTINUE: UInt16  = 0x003C
    private static let LABELSST: UInt16  = 0x00FD
    private static let LABEL: UInt16     = 0x0204
    private static let NUMBER: UInt16    = 0x0203
    private static let RK: UInt16        = 0x027E
    private static let MULRK: UInt16     = 0x00BD
    private static let BLANK: UInt16     = 0x0201
    private static let BOOLERR: UInt16   = 0x0205
    private static let BOUNDSHEET: UInt16 = 0x0085
    private static let FORMAT: UInt16    = 0x041E
    private static let FORMULA: UInt16   = 0x0006
    private static let STRING: UInt16    = 0x0207

    // MARK: - Public API

    static func parse(url: URL) throws -> BIFFResult {
        let data = try Data(contentsOf: url)
        guard isOLE2(data) else { throw BIFFError.notOLE2 }

        let bytes = [UInt8](data)

        // Extract the Workbook stream from the OLE2 container
        let workbookData = try extractWorkbookStream(bytes: bytes)

        // Parse BIFF records from the workbook stream
        let (sharedStrings, cells) = parseBIFFRecords(workbookData)

        // Convert sparse cells to dense rows
        return buildResult(sharedStrings: sharedStrings, cells: cells)
    }

    // MARK: - OLE2 Container Parsing

    /// Extracts the "Workbook" (or "Book") stream from an OLE2 compound file.
    private static func extractWorkbookStream(bytes: [UInt8]) throws -> [UInt8] {
        guard bytes.count >= 512 else { throw BIFFError.corruptedFile("File too small") }

        // Parse OLE2 header
        let sectorSizePower = readUInt16(bytes, at: 30)
        let sectorSize = 1 << Int(sectorSizePower) // Usually 512
        let miniSectorSizePower = readUInt16(bytes, at: 32)
        _ = 1 << Int(miniSectorSizePower) // Usually 64
        let fatSectorCount = Int(readUInt32(bytes, at: 44))
        let firstDirectorySector = Int(readUInt32(bytes, at: 48))
        let miniStreamCutoff = Int(readUInt32(bytes, at: 56))
        let firstMiniFATSector = Int(readUInt32(bytes, at: 60))
        _ = Int(readUInt32(bytes, at: 64))
        let firstDIFATSector = Int(readUInt32(bytes, at: 68))
        let difatSectorCount = Int(readUInt32(bytes, at: 72))

        // Read FAT sector IDs from header (first 109 entries at offset 76)
        var fatSectorIDs: [Int] = []
        for i in 0..<min(109, fatSectorCount) {
            let sectorID = Int(readUInt32(bytes, at: 76 + i * 4))
            if sectorID < 0xFFFFFFFE { fatSectorIDs.append(sectorID) }
        }

        // If more than 109 FAT sectors, follow the DIFAT chain
        if difatSectorCount > 0 && firstDIFATSector < 0xFFFFFFFE {
            var difatSector = firstDIFATSector
            for _ in 0..<difatSectorCount {
                let offset = sectorOffset(difatSector, sectorSize: sectorSize)
                guard offset + sectorSize <= bytes.count else { break }
                let entriesPerSector = sectorSize / 4 - 1 // Last 4 bytes = next DIFAT sector
                for j in 0..<entriesPerSector {
                    let sid = Int(readUInt32(bytes, at: offset + j * 4))
                    if sid < 0xFFFFFFFE { fatSectorIDs.append(sid) }
                }
                difatSector = Int(readUInt32(bytes, at: offset + entriesPerSector * 4))
                if difatSector >= 0xFFFFFFFE { break }
            }
        }

        // Build the FAT (File Allocation Table)
        var fat: [Int] = []
        for sectorID in fatSectorIDs {
            let offset = sectorOffset(sectorID, sectorSize: sectorSize)
            guard offset + sectorSize <= bytes.count else { continue }
            for j in stride(from: 0, to: sectorSize, by: 4) {
                fat.append(Int(readUInt32(bytes, at: offset + j)))
            }
        }

        // Read directory entries starting at firstDirectorySector
        let directoryData = readChain(startSector: firstDirectorySector, fat: fat,
                                       bytes: bytes, sectorSize: sectorSize)
        let entries = parseDirectoryEntries(directoryData)

        // Find the "Workbook" or "Book" entry
        guard let workbookEntry = entries.first(where: { entry in
            let name = entry.name.lowercased()
            return name == "workbook" || name == "book"
        }) else {
            throw BIFFError.noWorkbookStream
        }

        // Read the workbook stream
        if workbookEntry.size < miniStreamCutoff && workbookEntry.size > 0 {
            // Small stream — read from mini stream
            // First, get the root entry's stream (contains all mini-stream data)
            guard let rootEntry = entries.first else {
                throw BIFFError.corruptedFile("No root directory entry")
            }
            let rootStream = readChain(startSector: rootEntry.startSector, fat: fat,
                                        bytes: bytes, sectorSize: sectorSize)

            // Build mini FAT
            let miniFATData = readChain(startSector: firstMiniFATSector, fat: fat,
                                         bytes: bytes, sectorSize: sectorSize)
            var miniFAT: [Int] = []
            for j in stride(from: 0, to: miniFATData.count, by: 4) {
                guard j + 4 <= miniFATData.count else { break }
                miniFAT.append(Int(readUInt32LE(Array(miniFATData), at: j)))
            }

            let miniSectorSize = 1 << Int(miniSectorSizePower)
            return readMiniChain(startSector: workbookEntry.startSector,
                                  miniFAT: miniFAT,
                                  rootStream: rootStream,
                                  miniSectorSize: miniSectorSize,
                                  size: workbookEntry.size)
        } else {
            // Normal stream
            let data = readChain(startSector: workbookEntry.startSector, fat: fat,
                                  bytes: bytes, sectorSize: sectorSize)
            return Array(data.prefix(workbookEntry.size))
        }
    }

    /// Converts a sector ID to a byte offset (sector 0 starts after the 512-byte header).
    private static func sectorOffset(_ sectorID: Int, sectorSize: Int) -> Int {
        (sectorID + 1) * sectorSize
    }

    /// Reads a chain of sectors following the FAT.
    private static func readChain(startSector: Int, fat: [Int],
                                   bytes: [UInt8], sectorSize: Int) -> [UInt8] {
        var result: [UInt8] = []
        var sector = startSector
        var visited = Set<Int>() // Prevent infinite loops

        while sector >= 0 && sector < fat.count && !visited.contains(sector) {
            visited.insert(sector)
            let offset = sectorOffset(sector, sectorSize: sectorSize)
            guard offset + sectorSize <= bytes.count else { break }
            result.append(contentsOf: bytes[offset..<(offset + sectorSize)])
            sector = fat[sector]
            if sector >= 0xFFFFFFFE { break }
        }
        return result
    }

    /// Reads a chain of mini-sectors from the root stream.
    private static func readMiniChain(startSector: Int, miniFAT: [Int],
                                       rootStream: [UInt8], miniSectorSize: Int,
                                       size: Int) -> [UInt8] {
        var result: [UInt8] = []
        var sector = startSector
        var visited = Set<Int>()

        while sector >= 0 && sector < miniFAT.count && !visited.contains(sector) {
            visited.insert(sector)
            let offset = sector * miniSectorSize
            guard offset + miniSectorSize <= rootStream.count else { break }
            result.append(contentsOf: rootStream[offset..<(offset + miniSectorSize)])
            sector = miniFAT[sector]
            if sector >= 0xFFFFFFFE { break }
        }
        return Array(result.prefix(size))
    }

    // MARK: - Directory Entry Parsing

    private struct DirectoryEntry {
        let name: String
        let type: UInt8 // 1=storage, 2=stream, 5=root
        let startSector: Int
        let size: Int
    }

    /// Parses OLE2 directory entries (128 bytes each).
    private static func parseDirectoryEntries(_ data: [UInt8]) -> [DirectoryEntry] {
        var entries: [DirectoryEntry] = []
        let entrySize = 128

        for i in stride(from: 0, to: data.count, by: entrySize) {
            guard i + entrySize <= data.count else { break }

            let nameLen = Int(readUInt16LE(data, at: i + 64))
            guard nameLen > 0 && nameLen <= 64 else { continue }

            // Name is UTF-16LE encoded, nameLen includes null terminator (2 bytes)
            let actualLen = max(0, nameLen - 2)
            var name = ""
            for j in stride(from: 0, to: actualLen, by: 2) {
                let charCode = UInt16(data[i + j]) | (UInt16(data[i + j + 1]) << 8)
                if let scalar = Unicode.Scalar(charCode) {
                    name.append(Character(scalar))
                }
            }

            let type = data[i + 66]
            let startSector = Int(readUInt32LE(data, at: i + 116))
            let size = Int(readUInt32LE(data, at: i + 120))

            entries.append(DirectoryEntry(name: name, type: type,
                                           startSector: startSector, size: size))
        }
        return entries
    }

    // MARK: - BIFF Record Parsing

    /// A cell value with its row/column position.
    private struct CellValue {
        let row: Int
        let col: Int
        let value: String
    }

    /// Parses BIFF8 records from the workbook stream, extracting the shared string table
    /// and all cell values.
    private static func parseBIFFRecords(_ stream: [UInt8]) -> ([String], [CellValue]) {
        var sharedStrings: [String] = []
        var cells: [CellValue] = []
        var offset = 0
        var sstData: [UInt8] = [] // Accumulates SST data across CONTINUE records
        var readingSST = false
        var lastFormulaRow = 0
        var lastFormulaCol = 0

        while offset + 4 <= stream.count {
            let recordType = readUInt16LE(stream, at: offset)
            let recordLen = Int(readUInt16LE(stream, at: offset + 2))
            let dataStart = offset + 4
            let dataEnd = min(dataStart + recordLen, stream.count)
            let recordData = Array(stream[dataStart..<dataEnd])

            if recordType == CONTINUE && readingSST {
                // CONTINUE record extends the SST data
                sstData.append(contentsOf: recordData)
                offset = dataEnd
                continue
            } else {
                if readingSST {
                    // End of SST + CONTINUE sequence — parse accumulated data
                    sharedStrings = parseSST(sstData)
                    readingSST = false
                }
            }

            switch recordType {
            case SST:
                sstData = recordData
                readingSST = true

            case LABELSST:
                // Cell referencing shared string: row(2) + col(2) + xf(2) + sstIndex(4)
                if recordData.count >= 10 {
                    let row = Int(readUInt16LE(recordData, at: 0))
                    let col = Int(readUInt16LE(recordData, at: 2))
                    let sstIdx = Int(readUInt32LE(recordData, at: 6))
                    if sstIdx < sharedStrings.count {
                        cells.append(CellValue(row: row, col: col, value: sharedStrings[sstIdx]))
                    }
                }

            case LABEL:
                // Inline string cell: row(2) + col(2) + xf(2) + len(2) + string
                if recordData.count >= 8 {
                    let row = Int(readUInt16LE(recordData, at: 0))
                    let col = Int(readUInt16LE(recordData, at: 2))
                    let strLen = Int(readUInt16LE(recordData, at: 6))
                    if recordData.count >= 8 + strLen {
                        let str = readBIFFString(recordData, at: 6)
                        cells.append(CellValue(row: row, col: col, value: str))
                    }
                }

            case NUMBER:
                // Number cell: row(2) + col(2) + xf(2) + ieee(8)
                if recordData.count >= 14 {
                    let row = Int(readUInt16LE(recordData, at: 0))
                    let col = Int(readUInt16LE(recordData, at: 2))
                    let value = readDouble(recordData, at: 6)
                    cells.append(CellValue(row: row, col: col, value: formatNumber(value)))
                }

            case RK:
                // Compressed number: row(2) + col(2) + xf(2) + rk(4)
                if recordData.count >= 10 {
                    let row = Int(readUInt16LE(recordData, at: 0))
                    let col = Int(readUInt16LE(recordData, at: 2))
                    let value = decodeRK(readUInt32LE(recordData, at: 6))
                    cells.append(CellValue(row: row, col: col, value: formatNumber(value)))
                }

            case MULRK:
                // Multiple RK values in one row: row(2) + firstCol(2) + [xf(2)+rk(4)]... + lastCol(2)
                if recordData.count >= 6 {
                    let row = Int(readUInt16LE(recordData, at: 0))
                    let firstCol = Int(readUInt16LE(recordData, at: 2))
                    var pos = 4
                    var col = firstCol
                    while pos + 6 <= recordData.count - 2 { // -2 for lastCol
                        // Skip XF index (2 bytes)
                        let rkVal = decodeRK(readUInt32LE(recordData, at: pos + 2))
                        cells.append(CellValue(row: row, col: col, value: formatNumber(rkVal)))
                        pos += 6
                        col += 1
                    }
                }

            case FORMULA:
                // Formula cell: row(2) + col(2) + xf(2) + result(8) + options(2) + ...
                if recordData.count >= 14 {
                    let row = Int(readUInt16LE(recordData, at: 0))
                    let col = Int(readUInt16LE(recordData, at: 2))
                    lastFormulaRow = row
                    lastFormulaCol = col
                    // Check if result is a number or string marker
                    let byte6 = recordData[12]
                    let byte7 = recordData[13]
                    if byte6 != 0xFF || byte7 != 0xFF {
                        // Numeric result
                        let value = readDouble(recordData, at: 6)
                        cells.append(CellValue(row: row, col: col, value: formatNumber(value)))
                    }
                    // If byte6==0xFF, a STRING record follows with the string value
                }

            case STRING:
                // String result of a formula
                if recordData.count >= 3 {
                    let str = readBIFFString(recordData, at: 0)
                    cells.append(CellValue(row: lastFormulaRow, col: lastFormulaCol, value: str))
                }

            case BOOLERR:
                if recordData.count >= 8 {
                    let row = Int(readUInt16LE(recordData, at: 0))
                    let col = Int(readUInt16LE(recordData, at: 2))
                    let isError = recordData[7] != 0
                    if !isError {
                        let boolVal = recordData[6] != 0
                        cells.append(CellValue(row: row, col: col, value: boolVal ? "TRUE" : "FALSE"))
                    }
                }

            default:
                break
            }

            offset = dataEnd
        }

        // Handle SST that extends to end of stream
        if readingSST {
            sharedStrings = parseSST(sstData)
        }

        return (sharedStrings, cells)
    }

    // MARK: - SST (Shared String Table) Parsing

    /// Parses the Shared String Table data (may span SST + CONTINUE records).
    private static func parseSST(_ data: [UInt8]) -> [String] {
        guard data.count >= 8 else { return [] }

        let uniqueCount = Int(readUInt32LE(data, at: 4))
        var strings: [String] = []
        var offset = 8

        for _ in 0..<uniqueCount {
            guard offset + 3 <= data.count else { break }
            let str = readBIFFUnicodeString(data, at: &offset)
            strings.append(str)
        }

        return strings
    }

    // MARK: - BIFF String Reading

    /// Reads a BIFF8 unicode string from data at the given offset.
    /// Format: charCount(2) + flags(1) + [richTextRuns(2)] + [extLen(4)] + characters
    private static func readBIFFUnicodeString(_ data: [UInt8], at offset: inout Int) -> String {
        guard offset + 3 <= data.count else {
            offset = data.count
            return ""
        }

        let charCount = Int(readUInt16LE(data, at: offset))
        let flags = data[offset + 2]
        offset += 3

        let isUTF16 = (flags & 0x01) != 0
        let hasRichText = (flags & 0x08) != 0
        let hasExtData = (flags & 0x04) != 0

        var richTextRuns = 0
        if hasRichText && offset + 2 <= data.count {
            richTextRuns = Int(readUInt16LE(data, at: offset))
            offset += 2
        }

        var extDataSize = 0
        if hasExtData && offset + 4 <= data.count {
            extDataSize = Int(readUInt32LE(data, at: offset))
            offset += 4
        }

        var result = ""
        if isUTF16 {
            let byteCount = charCount * 2
            for i in stride(from: 0, to: byteCount, by: 2) {
                guard offset + i + 2 <= data.count else { break }
                let charCode = UInt16(data[offset + i]) | (UInt16(data[offset + i + 1]) << 8)
                if let scalar = Unicode.Scalar(charCode) {
                    result.append(Character(scalar))
                }
            }
            offset += byteCount
        } else {
            for i in 0..<charCount {
                guard offset + i < data.count else { break }
                result.append(Character(UnicodeScalar(data[offset + i])))
            }
            offset += charCount
        }

        // Skip rich text formatting runs (4 bytes each)
        offset += richTextRuns * 4
        // Skip extended data
        offset += extDataSize

        return result
    }

    /// Reads a shorter BIFF string (used in LABEL records). Format: len(2) + flags(1) + chars
    private static func readBIFFString(_ data: [UInt8], at start: Int) -> String {
        var offset = start
        return readBIFFUnicodeString(data, at: &offset)
    }

    // MARK: - RK Value Decoding

    /// Decodes an RK-encoded number. RK is a compact representation:
    /// - Bit 0: 0=IEEE, 1=integer
    /// - Bit 1: 0=as-is, 1=divide by 100
    private static func decodeRK(_ rk: UInt32) -> Double {
        let isInteger = (rk & 0x02) != 0
        let divide100 = (rk & 0x01) != 0

        var value: Double
        if isInteger {
            // Signed 30-bit integer (top 30 bits)
            let intVal = Int32(bitPattern: rk & 0xFFFFFFFC) >> 2
            value = Double(intVal)
        } else {
            // IEEE 754 double with bottom 34 bits zeroed
            var bits: UInt64 = UInt64(rk & 0xFFFFFFFC) << 32
            value = withUnsafeBytes(of: &bits) { $0.load(as: Double.self) }
        }

        if divide100 { value /= 100.0 }
        return value
    }

    // MARK: - Result Building

    /// Converts sparse cell values to a structured result with headers and data rows.
    private static func buildResult(sharedStrings: [String], cells: [CellValue]) -> BIFFResult {
        guard !cells.isEmpty else {
            return BIFFResult(headers: [], rows: [], sheetName: "Sheet1")
        }

        let maxRow = cells.map { $0.row }.max() ?? 0
        let maxCol = cells.map { $0.col }.max() ?? 0

        // Build dense grid
        var grid = Array(repeating: Array(repeating: "", count: maxCol + 1),
                         count: maxRow + 1)
        for cell in cells {
            grid[cell.row][cell.col] = cell.value
        }

        // Remove completely empty rows
        let nonEmptyRows = grid.filter { row in
            !row.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        }

        guard !nonEmptyRows.isEmpty else {
            return BIFFResult(headers: [], rows: [], sheetName: "Sheet1")
        }

        // First non-empty row with ≥3 cells = headers
        guard let headerIdx = nonEmptyRows.firstIndex(where: { row in
            row.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count >= 3
        }) else {
            return BIFFResult(headers: nonEmptyRows[0], rows: Array(nonEmptyRows.dropFirst()),
                               sheetName: "Sheet1")
        }

        let headers = nonEmptyRows[headerIdx].map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let dataRows = Array(nonEmptyRows[(headerIdx + 1)...]).filter { row in
            !row.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
        }

        return BIFFResult(headers: headers, rows: dataRows, sheetName: "Sheet1")
    }

    // MARK: - Number Formatting

    /// Formats a double value for display, removing unnecessary trailing zeros.
    private static func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(format: "%.0f", value)
        }
        // Preserve up to 2 decimal places for currency
        let formatted = String(format: "%.2f", value)
        return formatted
    }

    // MARK: - Byte Reading Helpers

    private static func readUInt16(_ bytes: [UInt8], at offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    private static func readUInt32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | (UInt32(bytes[offset + 1]) << 8) |
        (UInt32(bytes[offset + 2]) << 16) | (UInt32(bytes[offset + 3]) << 24)
    }

    // Little-endian aliases (same as above, explicit naming for clarity)
    private static func readUInt16LE(_ bytes: [UInt8], at offset: Int) -> UInt16 {
        guard offset + 2 <= bytes.count else { return 0 }
        return UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    private static func readUInt32LE(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        guard offset + 4 <= bytes.count else { return 0 }
        return UInt32(bytes[offset]) | (UInt32(bytes[offset + 1]) << 8) |
        (UInt32(bytes[offset + 2]) << 16) | (UInt32(bytes[offset + 3]) << 24)
    }

    private static func readDouble(_ bytes: [UInt8], at offset: Int) -> Double {
        guard offset + 8 <= bytes.count else { return 0 }
        var value: Double = 0
        withUnsafeMutableBytes(of: &value) { ptr in
            for i in 0..<8 { ptr[i] = bytes[offset + i] }
        }
        return value
    }
}
