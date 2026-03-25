import Foundation

/// Reusable date parsing utility that handles multiple Indian bank statement date formats,
/// including text-based dates (dd/MM/yyyy, dd-MM-yyyy) and Excel numeric serial dates.
enum DateParser {

    // MARK: - Public API

    /// Attempts to parse a date string using all known bank statement formats.
    /// Returns nil if no format matches.
    static func parse(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Try Excel numeric serial date first (e.g. 45678)
        if let serial = Double(trimmed), serial > 25569, serial < 80000 {
            return dateFromExcelSerial(serial)
        }

        // Try each text-based format
        for formatter in formatters {
            if let date = formatter.date(from: trimmed) {
                return fix2DigitYear(date)
            }
        }
        return nil
    }

    /// Parses an Excel numeric serial date (days since 1900-01-01, with the
    /// Lotus 1-2-3 leap year bug offset).
    static func dateFromExcelSerial(_ serial: Double) -> Date? {
        // Excel's epoch is 1900-01-01, but it incorrectly treats 1900 as a leap year.
        // Serial number 1 = 1900-01-01, and there's a phantom Feb 29 1900 at serial 60.
        // Subtract 2 to compensate (1 for zero-index, 1 for the bug after serial 60).
        let daysSinceEpoch = serial > 60 ? serial - 2 : serial - 1
        var components = DateComponents()
        components.year = 1900
        components.month = 1
        components.day = 1
        let calendar = Calendar(identifier: .gregorian)
        guard let epoch = calendar.date(from: components) else { return nil }
        return calendar.date(byAdding: .day, value: Int(daysSinceEpoch), to: epoch)
    }

    // MARK: - Supported Formats

    /// All date formats commonly found in Indian bank statements, ordered by frequency.
    private static let formats: [String] = [
        "dd/MM/yyyy",
        "dd-MM-yyyy",
        "dd/MM/yy",
        "dd-MM-yy",
        "yyyy-MM-dd",
        "yyyy/MM/dd",
        "dd MMM yyyy",       // 05 Jan 2026
        "dd-MMM-yyyy",       // 05-Jan-2026
        "dd MMM yy",         // 05 Jan 26
        "dd-MMM-yy",         // 05-Jan-26
        "MM/dd/yyyy",        // US format fallback
        "dd.MM.yyyy",        // European dot format
    ]

    private static let formatters: [DateFormatter] = formats.map { format in
        let f = DateFormatter()
        f.dateFormat = format
        f.locale = Locale(identifier: "en_IN")
        f.timeZone = TimeZone(identifier: "Asia/Kolkata")
        return f
    }

    // MARK: - Year Fixing

    /// Fixes 2-digit year dates. If the parsed year is before 2000, assume 2000s.
    /// E.g., "26" becomes 2026, not 1926.
    private static func fix2DigitYear(_ date: Date) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        if year < 100 {
            return calendar.date(byAdding: .year, value: 2000, to: date) ?? date
        }
        return date
    }
}
