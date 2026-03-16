import Foundation

struct MockData {
    static let userName = "SID"

    static let calendar = Calendar.current

    static func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components) ?? Date()
    }

    static let transactions: [Transaction] = [
        Transaction(
            date: date(year: 2026, month: 3, day: 16),
            merchant: "Salary",
            amount: 250000,
            category: "Income",
            account: "HDFC Savings",
            type: .income,
            importSource: .csv,
            notes: "Monthly pay-check"
        ),
        Transaction(
            date: date(year: 2026, month: 3, day: 16),
            merchant: "Spotify",
            amount: -500,
            category: "Entertainment",
            account: "ICICI Credit",
            type: .expense,
            isRecurring: true,
            importSource: .csv,
            notes: "Monthly music subscription"
        ),
        Transaction(
            date: date(year: 2026, month: 3, day: 16),
            merchant: "Zomato",
            amount: -1254,
            category: "Food",
            account: "HDFC Savings",
            type: .expense,
            importSource: .csv,
            notes: "Food order"
        ),
        Transaction(
            date: date(year: 2026, month: 3, day: 16),
            merchant: "Petrol",
            amount: -2000,
            category: "Transport",
            account: "HDFC Savings",
            type: .expense,
            importSource: .manual,
            notes: "Fuel expense"
        ),
        Transaction(
            date: date(year: 2026, month: 3, day: 15),
            merchant: "H&M",
            amount: -9870,
            category: "Shopping",
            account: "ICICI Credit",
            type: .expense,
            importSource: .csv,
            notes: "Clothes"
        ),
        Transaction(
            date: date(year: 2026, month: 3, day: 15),
            merchant: "Petrol",
            amount: -2000,
            category: "Transport",
            account: "HDFC Savings",
            type: .expense,
            importSource: .manual,
            notes: "Fuel expense"
        ),
        Transaction(
            date: date(year: 2026, month: 3, day: 14),
            merchant: "Apollo Pharmacy",
            amount: -3700,
            category: "Health",
            account: "HDFC Savings",
            type: .expense,
            importSource: .manual,
            notes: "Medicine"
        ),
        Transaction(
            date: date(year: 2026, month: 3, day: 13),
            merchant: "Netflix",
            amount: -499,
            category: "Entertainment",
            account: "ICICI Credit",
            type: .expense,
            isRecurring: true,
            importSource: .csv,
            notes: "Monthly subscription"
        ),
        Transaction(
            date: date(year: 2026, month: 3, day: 12),
            merchant: "Amazon",
            amount: -6117,
            category: "Shopping",
            account: "ICICI Credit",
            type: .expense,
            importSource: .csv,
            notes: "Electronics"
        ),
        Transaction(
            date: date(year: 2026, month: 3, day: 11),
            merchant: "Uber",
            amount: -757,
            category: "Transport",
            account: "HDFC Savings",
            type: .expense,
            importSource: .manual,
            notes: "Cab ride"
        ),
        Transaction(
            date: date(year: 2026, month: 3, day: 10),
            merchant: "Electricity Bill",
            amount: -2800,
            category: "Utilities",
            account: "HDFC Savings",
            type: .expense,
            importSource: .csv,
            notes: "Monthly bill"
        ),
        Transaction(
            date: date(year: 2026, month: 3, day: 9),
            merchant: "Water Bill",
            amount: -700,
            category: "Utilities",
            account: "HDFC Savings",
            type: .expense,
            importSource: .csv,
            notes: "Monthly bill"
        ),
        Transaction(
            date: date(year: 2026, month: 3, day: 8),
            merchant: "FD Interest",
            amount: -19487,
            category: "Finance",
            account: "HDFC Savings",
            type: .expense,
            importSource: .csv,
            notes: "Fixed deposit"
        ),
        Transaction(
            date: date(year: 2026, month: 3, day: 7),
            merchant: "Swiggy",
            amount: -2580,
            category: "Food",
            account: "HDFC Savings",
            type: .expense,
            importSource: .manual,
            notes: "Food delivery"
        ),
        Transaction(
            date: date(year: 2026, month: 3, day: 6),
            merchant: "Internet Bill",
            amount: -2757,
            category: "Utilities",
            account: "HDFC Savings",
            type: .expense,
            importSource: .csv,
            notes: "Broadband"
        ),
        Transaction(
            date: date(year: 2026, month: 3, day: 5),
            merchant: "Freelance Payment",
            amount: 30700,
            category: "Income",
            account: "HDFC Savings",
            type: .income,
            importSource: .csv,
            notes: "Project payment"
        ),
        Transaction(
            date: date(year: 2026, month: 3, day: 4),
            merchant: "BookMyShow",
            amount: -1200,
            category: "Entertainment",
            account: "ICICI Credit",
            type: .expense,
            importSource: .manual,
            notes: "Movie tickets"
        ),
        Transaction(
            date: date(year: 2026, month: 3, day: 3),
            merchant: "Gym Membership",
            amount: -2557,
            category: "Health",
            account: "HDFC Savings",
            type: .expense,
            importSource: .csv,
            notes: "Monthly membership"
        ),
        Transaction(
            date: date(year: 2026, month: 3, day: 2),
            merchant: "Misc Purchase",
            amount: -1437,
            category: "Misc",
            account: "ICICI Credit",
            type: .expense,
            importSource: .manual,
            notes: "Miscellaneous"
        ),
        Transaction(
            date: date(year: 2026, month: 3, day: 1),
            merchant: "Croma",
            amount: -1622,
            category: "Food",
            account: "HDFC Savings",
            type: .expense,
            importSource: .csv,
            notes: "Groceries"
        ),
    ]

    static let accounts: [Account] = [
        Account(name: "HDFC Savings", type: .savings, balance: 330000),
        Account(name: "ICICI Credit", type: .credit, balance: -18186),
        Account(name: "Paytm Wallet", type: .wallet, balance: 2500),
    ]

    static let categories: [Category] = [
        Category(name: "Shopping", colorHex: "#A78BFA", sfSymbol: "bag.fill"),
        Category(name: "Entertainment", colorHex: "#FB923C", sfSymbol: "tv.fill"),
        Category(name: "Health", colorHex: "#34D399", sfSymbol: "heart.fill"),
        Category(name: "Finance", colorHex: "#60A5FA", sfSymbol: "banknote.fill"),
        Category(name: "Transport", colorHex: "#FBBF24", sfSymbol: "car.fill"),
        Category(name: "Utilities", colorHex: "#F472B6", sfSymbol: "bolt.fill"),
        Category(name: "Misc", colorHex: "#94A3B8", sfSymbol: "ellipsis.circle.fill"),
        Category(name: "Food", colorHex: "#F97316", sfSymbol: "fork.knife"),
        Category(name: "Income", colorHex: "#4ADE80", sfSymbol: "indianrupeesign.circle.fill"),
    ]

    static let subscriptions: [Subscription] = [
        Subscription(
            name: "Netflix",
            amount: 15135,
            billingCycle: .yearly,
            nextBillDate: date(year: 2026, month: 4, day: 12),
            category: "Entertainment"
        ),
        Subscription(
            name: "Klar Premium",
            amount: 499,
            billingCycle: .monthly,
            nextBillDate: date(year: 2026, month: 4, day: 1),
            category: "Finance"
        ),
        Subscription(
            name: "Health Insurance",
            amount: 15135,
            billingCycle: .yearly,
            nextBillDate: date(year: 2027, month: 2, day: 2),
            category: "Health"
        ),
    ]

    static let rules: [Rule] = [
        Rule(keyword: "zomato", targetCategory: "Food"),
        Rule(keyword: "swiggy", targetCategory: "Food"),
        Rule(keyword: "uber", targetCategory: "Transport"),
        Rule(keyword: "netflix", targetCategory: "Entertainment"),
        Rule(keyword: "spotify", targetCategory: "Entertainment"),
    ]

    static let categorySpend: [(String, Double)] = [
        ("Shopping", 15987),
        ("Entertainment", 5456),
        ("Health", 6257),
        ("Finance", 9757),
        ("Transport", 2757),
        ("Utilities", 6257),
        ("Misc", 1437),
        ("Food", 5456),
    ]

    static let totalIncome: Double = 230700
    static let totalExpense: Double = 115987
    static let totalBalance: Double = 175987
    static let burnRate: Double = 0.035
    static let burnAmount: Double = 35789
    static let budgetLimit: Double = 50000

    static let weeklySpend: [Double] = [3200, 5400, 2100, 8700, 4300, 6100, 5000]

    static let monthlyTrend: [Double] = [
        12000, 18000, 25000, 32000, 28000, 45000, 38000,
        52000, 48000, 55000, 62000, 58000, 72000, 68000,
        75000, 82000, 78000, 85000, 92000, 88000, 95000,
        72000, 68000, 85000, 92000, 88000, 95000, 98000,
    ]

    static let sixMonthAvg: [Double] = [
        15000, 20000, 28000, 35000, 32000, 48000, 42000,
        55000, 52000, 58000, 65000, 62000, 75000, 72000,
        78000, 85000, 82000, 88000, 95000, 92000, 98000,
        78000, 72000, 88000, 95000, 92000, 98000, 100000,
    ]

    static let uploadFiles: [UploadFile] = [
        UploadFile(name: "HdfcSavingsStatement.pdf", size: "20MB", fileType: "PDF", status: .success),
        UploadFile(name: "IciciCreditCard.csv", size: "1.2MB", fileType: "CSV", status: .needsReview),
    ]
}
