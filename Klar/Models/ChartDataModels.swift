import Foundation

struct CategorySpend: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
    let budget: Double
    let previousAmount: Double

    init(category: String, amount: Double, budget: Double = 0, previousAmount: Double = 0) {
        self.category = category
        self.amount = amount
        self.budget = budget
        self.previousAmount = previousAmount
    }
}

struct DailySpend: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
    let categories: [CategorySpend]
}

struct MonthlyRank: Identifiable {
    let id = UUID()
    let month: Date
    let category: String
    let rank: Int
    let amount: Double
}
