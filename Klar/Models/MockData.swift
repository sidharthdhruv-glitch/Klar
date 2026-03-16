import Foundation

/// Default data used to seed categories and rules on first launch.
/// No mock transactions are created — all transaction data comes from actual imports.
struct DefaultData {

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

    static let rules: [Rule] = [
        Rule(keyword: "zomato", targetCategory: "Food"),
        Rule(keyword: "swiggy", targetCategory: "Food"),
        Rule(keyword: "uber", targetCategory: "Transport"),
        Rule(keyword: "ola", targetCategory: "Transport"),
        Rule(keyword: "netflix", targetCategory: "Entertainment"),
        Rule(keyword: "spotify", targetCategory: "Entertainment"),
        Rule(keyword: "amazon", targetCategory: "Shopping"),
        Rule(keyword: "flipkart", targetCategory: "Shopping"),
        Rule(keyword: "petrol", targetCategory: "Transport"),
        Rule(keyword: "electricity", targetCategory: "Utilities"),
        Rule(keyword: "pharmacy", targetCategory: "Health"),
        Rule(keyword: "salary", targetCategory: "Income"),
    ]
}
