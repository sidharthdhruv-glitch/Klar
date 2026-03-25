import Foundation
import SwiftData

enum TransactionType: String, Codable, CaseIterable {
    case income
    case expense
}

enum ImportSource: String, Codable, CaseIterable {
    case csv
    case pdf
    case xlsx
    case manual
}

enum AccountType: String, Codable, CaseIterable {
    case savings
    case credit
    case wallet
}

enum BillingCycle: String, Codable, CaseIterable {
    case monthly
    case yearly
}

@Model
class Transaction {
    var id: UUID
    var date: Date
    var merchant: String
    var amount: Double
    var category: String
    var account: String
    var type: TransactionType
    var isRecurring: Bool
    var importSource: ImportSource
    var isDuplicate: Bool
    var notes: String?

    init(
        id: UUID = UUID(),
        date: Date,
        merchant: String,
        amount: Double,
        category: String,
        account: String,
        type: TransactionType,
        isRecurring: Bool = false,
        importSource: ImportSource = .manual,
        isDuplicate: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.merchant = merchant
        self.amount = amount
        self.category = category
        self.account = account
        self.type = type
        self.isRecurring = isRecurring
        self.importSource = importSource
        self.isDuplicate = isDuplicate
        self.notes = notes
    }
}

@Model
class Account {
    var id: UUID
    var name: String
    var type: AccountType
    var balance: Double

    init(id: UUID = UUID(), name: String, type: AccountType, balance: Double) {
        self.id = id
        self.name = name
        self.type = type
        self.balance = balance
    }
}

@Model
class Category {
    var id: UUID
    var name: String
    var colorHex: String
    var sfSymbol: String

    init(id: UUID = UUID(), name: String, colorHex: String, sfSymbol: String) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.sfSymbol = sfSymbol
    }
}

@Model
class Rule {
    var id: UUID
    var keyword: String
    var targetCategory: String

    init(id: UUID = UUID(), keyword: String, targetCategory: String) {
        self.id = id
        self.keyword = keyword
        self.targetCategory = targetCategory
    }
}

@Model
class Subscription {
    var id: UUID
    var name: String
    var amount: Double
    var billingCycle: BillingCycle
    var nextBillDate: Date
    var category: String
    var cancelReminderEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double,
        billingCycle: BillingCycle,
        nextBillDate: Date,
        category: String,
        cancelReminderEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.billingCycle = billingCycle
        self.nextBillDate = nextBillDate
        self.category = category
        self.cancelReminderEnabled = cancelReminderEnabled
    }
}

enum UploadStatus: String {
    case parsing = "PARSING…"
    case success = "SUCCESS"
    case needsReview = "NEEDS REVIEW"
}
