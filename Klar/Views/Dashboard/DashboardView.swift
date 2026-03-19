import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var accounts: [Account]
    @Query private var rules: [Rule]

    @AppStorage("userName") private var userName = "User"
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 50000

    @State private var selectedMonthOffset: Int = 0
    @State private var showAddTransaction = false
    @State private var showOCRScanner = false
    @Environment(\.modelContext) private var modelContext

    private var availableMonths: [(month: Int, year: Int, label: String)] {
        let cal = Calendar.current
        var seen: Set<String> = []
        var result: [(month: Int, year: Int, label: String)] = []
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"

        for txn in transactions {
            let m = cal.component(.month, from: txn.date)
            let y = cal.component(.year, from: txn.date)
            let key = "\(y)-\(m)"
            if !seen.contains(key) {
                seen.insert(key)
                var comps = DateComponents()
                comps.year = y
                comps.month = m
                comps.day = 1
                let label = cal.date(from: comps).map { f.string(from: $0).uppercased() } ?? key
                result.append((month: m, year: y, label: label))
            }
        }

        result.sort { ($0.year, $0.month) > ($1.year, $1.month) }

        // Always include current month
        let nowM = cal.component(.month, from: Date())
        let nowY = cal.component(.year, from: Date())
        if !result.contains(where: { $0.month == nowM && $0.year == nowY }) {
            var comps = DateComponents()
            comps.year = nowY
            comps.month = nowM
            comps.day = 1
            let label = cal.date(from: comps).map { f.string(from: $0).uppercased() } ?? "\(nowY)-\(nowM)"
            result.insert((month: nowM, year: nowY, label: label), at: 0)
        }

        return result
    }

    private var selectedMonth: (month: Int, year: Int) {
        let months = availableMonths
        let index = min(max(selectedMonthOffset, 0), months.count - 1)
        guard !months.isEmpty else {
            let cal = Calendar.current
            return (cal.component(.month, from: Date()), cal.component(.year, from: Date()))
        }
        return (months[index].month, months[index].year)
    }

    private var selectedMonthLabel: String {
        let months = availableMonths
        let index = min(max(selectedMonthOffset, 0), months.count - 1)
        guard !months.isEmpty else { return "" }
        return months[index].label
    }

    private var activeTransactions: [Transaction] {
        let cal = Calendar.current
        let (month, year) = selectedMonth
        return transactions.filter {
            cal.component(.month, from: $0.date) == month &&
            cal.component(.year, from: $0.date) == year
        }
    }

    private var totalIncome: Double {
        activeTransactions.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
    }

    private var totalExpense: Double {
        activeTransactions.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
    }

    private var totalBalance: Double {
        // Compute all-time balance per account, then sum
        // This reflects actual account balances, not just the selected month
        var accountBalances: [String: Double] = [:]
        for txn in transactions {
            accountBalances[txn.account, default: 0] += txn.amount
        }
        return accountBalances.values.reduce(0, +)
    }

    private var monthNetFlow: Double {
        totalIncome - totalExpense
    }

    private var categorySpend: [(String, Double)] {
        var dict: [String: Double] = [:]
        for txn in activeTransactions where txn.amount < 0 {
            dict[txn.category, default: 0] += abs(txn.amount)
        }
        return dict.sorted { $0.value > $1.value }
    }

    private var burnRate: Double {
        guard monthlyBudget > 0 else { return 0 }
        return totalExpense / monthlyBudget
    }

    private var accountBalances: [(name: String, type: AccountType, balance: Double)] {
        // Compute balance per account from all transactions
        var balances: [String: Double] = [:]
        for txn in transactions {
            balances[txn.account, default: 0] += txn.amount
        }
        // Match account types from Account model, default to .savings
        let accountTypeMap = Dictionary(uniqueKeysWithValues: accounts.map { ($0.name, $0.type) })
        return balances.map { name, balance in
            (name: name, type: accountTypeMap[name] ?? .savings, balance: balance)
        }.sorted { abs($0.balance) > abs($1.balance) }
    }

    private var weeklySpend: [Double] {
        let cal = Calendar.current
        let now = Date()
        var dailyTotals: [Double] = []
        for daysAgo in stride(from: 6, through: 0, by: -1) {
            let day = cal.date(byAdding: .day, value: -daysAgo, to: now)!
            let dayTotal = activeTransactions.filter { txn in
                txn.type == .expense && cal.isDate(txn.date, inSameDayAs: day)
            }.reduce(0) { $0 + abs($1.amount) }
            dailyTotals.append(dayTotal)
        }
        return dailyTotals
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Button {
                        showOCRScanner = true
                    } label: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(KlarColors.accent.opacity(0.15))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "doc.text.viewfinder")
                                    .font(.system(size: 18))
                                    .foregroundStyle(KlarColors.accent)
                            )
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("HELLO, \(userName.uppercased())")
                            .font(KlarFonts.display(22))
                            .foregroundStyle(KlarColors.primary)
                        Text("YOUR DASHBOARD")
                            .font(KlarFonts.label(12))
                            .tracking(1)
                            .foregroundStyle(KlarColors.secondary)
                    }

                    Spacer()

                    Button {
                        showAddTransaction = true
                    } label: {
                        Circle()
                            .stroke(KlarColors.searchHighlight, lineWidth: 2)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(KlarColors.searchHighlight)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                if transactions.isEmpty {
                    emptyState
                } else {
                    // Month Selector
                    if availableMonths.count > 1 {
                        HStack {
                            Button {
                                withAnimation {
                                    selectedMonthOffset = min(selectedMonthOffset + 1, availableMonths.count - 1)
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(selectedMonthOffset < availableMonths.count - 1 ? KlarColors.primary : KlarColors.inactive)
                            }
                            .disabled(selectedMonthOffset >= availableMonths.count - 1)

                            Spacer()
                            Text(selectedMonthLabel)
                                .font(KlarFonts.heading(16))
                                .foregroundStyle(KlarColors.primary)
                            Spacer()

                            Button {
                                withAnimation {
                                    selectedMonthOffset = max(selectedMonthOffset - 1, 0)
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(selectedMonthOffset > 0 ? KlarColors.primary : KlarColors.inactive)
                            }
                            .disabled(selectedMonthOffset <= 0)
                        }
                        .padding(.horizontal, 20)
                    }

                    // Total Balance Card
                    KlarCard(dashedBorder: true) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("TOTAL BALANCE")
                                    .font(KlarFonts.heading(20))
                                    .foregroundStyle(KlarColors.primary)
                                Spacer()
                                HStack(spacing: 4) {
                                    Text("ALL ACCOUNTS")
                                        .font(KlarFonts.label(11))
                                        .foregroundStyle(KlarColors.secondary)
                                }
                            }

                            HStack(spacing: 12) {
                                AnimatedNumber(
                                    value: totalBalance,
                                    font: KlarFonts.display(28),
                                    color: totalBalance >= 0 ? KlarColors.primary : KlarColors.negative
                                )

                                if monthNetFlow != 0 {
                                    Text(CurrencyHelper.formatSigned(monthNetFlow))
                                        .font(KlarFonts.label(12))
                                        .foregroundStyle(monthNetFlow >= 0 ? KlarColors.positive : KlarColors.negative)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background((monthNetFlow >= 0 ? KlarColors.positive : KlarColors.negative).opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }

                            // Per-account balances
                            if !accountBalances.isEmpty {
                                VStack(spacing: 6) {
                                    ForEach(accountBalances, id: \.name) { item in
                                        HStack(spacing: 8) {
                                            Image(systemName: item.type == .savings ? "banknote" : item.type == .credit ? "creditcard" : "wallet.pass")
                                                .font(.system(size: 11))
                                                .foregroundStyle(KlarColors.secondary)
                                            Text(item.name.uppercased())
                                                .font(KlarFonts.label(11))
                                                .foregroundStyle(KlarColors.secondary)
                                            Spacer()
                                            Text(CurrencyHelper.format(item.balance))
                                                .font(KlarFonts.label(12))
                                                .monospacedDigit()
                                                .foregroundStyle(item.balance >= 0 ? KlarColors.primary : KlarColors.negative)
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Net Flow
                    NetFlowCard(
                        totalIncome: totalIncome,
                        totalExpense: totalExpense,
                        balance: totalBalance,
                        categorySpend: categorySpend
                    )
                    .padding(.horizontal, 20)

                    // Category Breakdown
                    if !categorySpend.isEmpty {
                        CategoryBreakdownView(categorySpend: categorySpend)
                            .padding(.horizontal, 20)
                    }

                    // Burn Rate
                    BurnRateView(
                        rate: burnRate,
                        spent: totalExpense,
                        budget: monthlyBudget
                    )
                    .padding(.horizontal, 20)

                    // Account Snapshots
                    if !accountBalances.isEmpty {
                        AccountSnapshotsFromTransactions(
                            accountBalances: accountBalances,
                            weeklyData: weeklySpend
                        )
                    }
                }

                Spacer(minLength: 20)
            }
        }
        .background(KlarColors.background)
        .onAppear {
            autoSelectMonth()
        }
        .sheet(isPresented: $showAddTransaction) {
            AddTransactionSheet { transaction in
                modelContext.insert(transaction)
                try? modelContext.save()
                showAddTransaction = false
            }
        }
        .sheet(isPresented: $showOCRScanner) {
            OCRScannerSheet(rules: Array(rules)) { transaction in
                modelContext.insert(transaction)
                try? modelContext.save()
                showOCRScanner = false
            }
        }
    }

    private func autoSelectMonth() {
        // If current month has no data, auto-select the first month that does
        if activeTransactions.isEmpty && availableMonths.count > 1 {
            let cal = Calendar.current
            for (index, monthInfo) in availableMonths.enumerated() {
                let hasData = transactions.contains {
                    cal.component(.month, from: $0.date) == monthInfo.month &&
                    cal.component(.year, from: $0.date) == monthInfo.year
                }
                if hasData {
                    selectedMonthOffset = index
                    break
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(KlarColors.inactive)

            Text("No transactions yet")
                .font(KlarFonts.heading(18))
                .foregroundStyle(KlarColors.secondary)

            Text("Import a bank statement from the Import tab to get started.")
                .font(KlarFonts.body(14))
                .foregroundStyle(KlarColors.inactive)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .padding(.top, 60)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Add Transaction Sheet
struct AddTransactionSheet: View {
    let onAdd: (Transaction) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var merchant = ""
    @State private var amount = ""
    @State private var selectedType: TransactionType = .expense
    @State private var selectedCategory = "Shopping"
    @State private var date = Date()
    @State private var notes = ""
    @FocusState private var isAmountFocused: Bool

    let categoryNames = ["Food", "Transport", "Shopping", "Entertainment",
                         "Health", "Utilities", "Finance", "Misc", "Income"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(KlarColors.secondary)
                }
                Spacer()
                Text("ADD TRANSACTION")
                    .font(KlarFonts.heading(18))
                    .foregroundStyle(KlarColors.primary)
                Spacer()
                Color.clear.frame(width: 16, height: 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 0) {
                        ForEach(TransactionType.allCases, id: \.self) { type in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedType = type
                                    if type == .income { selectedCategory = "Income" }
                                    else if selectedCategory == "Income" { selectedCategory = "Shopping" }
                                }
                            } label: {
                                Text(type.rawValue.uppercased())
                                    .font(KlarFonts.label(12))
                                    .tracking(1)
                                    .foregroundStyle(selectedType == type ? .white : KlarColors.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        selectedType == type
                                        ? (type == .expense ? KlarColors.negative : KlarColors.positive)
                                        : Color.clear
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .background(KlarColors.surfaceElevated)
                    .clipShape(Capsule())

                    VStack(alignment: .leading, spacing: 6) {
                        Text("AMOUNT")
                            .font(KlarFonts.label(11))
                            .tracking(1)
                            .foregroundStyle(KlarColors.secondary)
                        HStack {
                            Text("₹")
                                .font(KlarFonts.display(28))
                                .foregroundStyle(KlarColors.primary)
                            TextField("0", text: $amount)
                                .font(KlarFonts.display(28))
                                .foregroundStyle(KlarColors.primary)
                                .keyboardType(.decimalPad)
                                .focused($isAmountFocused)
                        }
                        .padding(14)
                        .background(KlarColors.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("MERCHANT / DESCRIPTION")
                            .font(KlarFonts.label(11))
                            .tracking(1)
                            .foregroundStyle(KlarColors.secondary)
                        TextField("e.g. Swiggy, Amazon", text: $merchant)
                            .font(KlarFonts.body(15))
                            .foregroundStyle(KlarColors.primary)
                            .padding(14)
                            .background(KlarColors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("DATE")
                            .font(KlarFonts.label(11))
                            .tracking(1)
                            .foregroundStyle(KlarColors.secondary)
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .padding(10)
                            .background(KlarColors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("CATEGORY")
                            .font(KlarFonts.label(11))
                            .tracking(1)
                            .foregroundStyle(KlarColors.secondary)
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                        ], spacing: 10) {
                            ForEach(categoryNames, id: \.self) { name in
                                Button {
                                    selectedCategory = name
                                } label: {
                                    Text(name.uppercased())
                                        .font(KlarFonts.label(11))
                                        .foregroundStyle(selectedCategory == name ? .white : KlarColors.secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(selectedCategory == name ? KlarColors.categoryColor(for: name) : KlarColors.surfaceElevated)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOTES (OPTIONAL)")
                            .font(KlarFonts.label(11))
                            .tracking(1)
                            .foregroundStyle(KlarColors.secondary)
                        TextField("Add a note...", text: $notes)
                            .font(KlarFonts.body(14))
                            .foregroundStyle(KlarColors.primary)
                            .padding(14)
                            .background(KlarColors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 20)
            }

            Button {
                guard let amountValue = Double(amount), amountValue > 0, !merchant.isEmpty else { return }
                let txn = Transaction(
                    date: date,
                    merchant: merchant,
                    amount: selectedType == .income ? amountValue : -amountValue,
                    category: selectedCategory,
                    account: "Manual",
                    type: selectedType,
                    importSource: .manual,
                    notes: notes.isEmpty ? nil : notes
                )
                onAdd(txn)
            } label: {
                Text("Save Transaction")
                    .font(KlarFonts.label(14))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(KlarColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(KlarColors.background)
        .presentationDetents([.large])
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isAmountFocused = false }
                    .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - OCR Scanner Sheet
struct OCRScannerSheet: View {
    let rules: [Rule]
    let onAdd: (Transaction) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var scannedText = ""
    @State private var showScanner = false
    @State private var parsedMerchant = ""
    @State private var parsedAmount = ""
    @State private var parsedDate = Date()
    @State private var parsedCategory = "Misc"
    @State private var selectedType: TransactionType = .expense
    @FocusState private var isAmountFocused: Bool

    let categoryNames = ["Food", "Transport", "Shopping", "Entertainment",
                         "Health", "Utilities", "Finance", "Misc", "Income"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(KlarColors.secondary)
                }
                Spacer()
                Text("SCAN BILL")
                    .font(KlarFonts.heading(18))
                    .foregroundStyle(KlarColors.primary)
                Spacer()
                Button { showScanner = true } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(KlarColors.accent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            if scannedText.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(KlarColors.inactive)
                    Text("Scan a bill or receipt")
                        .font(KlarFonts.heading(16))
                        .foregroundStyle(KlarColors.secondary)
                    Text("Point your camera at a receipt to extract the amount and details automatically.")
                        .font(KlarFonts.label(12))
                        .foregroundStyle(KlarColors.inactive)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Button { showScanner = true } label: {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Open Scanner")
                        }
                        .font(KlarFonts.label(14))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(KlarColors.primary)
                        .clipShape(Capsule())
                    }
                    .padding(.top, 8)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("SCANNED TEXT")
                                .font(KlarFonts.label(11))
                                .tracking(1)
                                .foregroundStyle(KlarColors.secondary)
                            Text(String(scannedText.prefix(200)) + (scannedText.count > 200 ? "..." : ""))
                                .font(KlarFonts.label(11))
                                .foregroundStyle(KlarColors.inactive)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(KlarColors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        HStack(spacing: 0) {
                            ForEach(TransactionType.allCases, id: \.self) { type in
                                Button {
                                    withAnimation(.spring(response: 0.3)) { selectedType = type }
                                } label: {
                                    Text(type.rawValue.uppercased())
                                        .font(KlarFonts.label(12))
                                        .tracking(1)
                                        .foregroundStyle(selectedType == type ? .white : KlarColors.secondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(selectedType == type ? (type == .expense ? KlarColors.negative : KlarColors.positive) : Color.clear)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .background(KlarColors.surfaceElevated)
                        .clipShape(Capsule())

                        VStack(alignment: .leading, spacing: 6) {
                            Text("AMOUNT")
                                .font(KlarFonts.label(11))
                                .tracking(1)
                                .foregroundStyle(KlarColors.secondary)
                            HStack {
                                Text("₹").font(KlarFonts.heading(20)).foregroundStyle(KlarColors.primary)
                                TextField("0", text: $parsedAmount)
                                    .font(KlarFonts.heading(20))
                                    .foregroundStyle(KlarColors.primary)
                                    .keyboardType(.decimalPad)
                                    .focused($isAmountFocused)
                            }
                            .padding(14)
                            .background(KlarColors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("MERCHANT")
                                .font(KlarFonts.label(11))
                                .tracking(1)
                                .foregroundStyle(KlarColors.secondary)
                            TextField("Merchant name", text: $parsedMerchant)
                                .font(KlarFonts.body(15))
                                .foregroundStyle(KlarColors.primary)
                                .padding(14)
                                .background(KlarColors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("DATE")
                                .font(KlarFonts.label(11))
                                .tracking(1)
                                .foregroundStyle(KlarColors.secondary)
                            DatePicker("", selection: $parsedDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .padding(10)
                                .background(KlarColors.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("CATEGORY")
                                .font(KlarFonts.label(11))
                                .tracking(1)
                                .foregroundStyle(KlarColors.secondary)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(categoryNames, id: \.self) { name in
                                    Button { parsedCategory = name } label: {
                                        Text(name.uppercased())
                                            .font(KlarFonts.label(11))
                                            .foregroundStyle(parsedCategory == name ? .white : KlarColors.secondary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity)
                                            .background(parsedCategory == name ? KlarColors.categoryColor(for: name) : KlarColors.surfaceElevated)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Button {
                    guard let amountValue = Double(parsedAmount), amountValue > 0 else { return }
                    let merchant = parsedMerchant.isEmpty ? "Scanned Bill" : parsedMerchant
                    let txn = Transaction(
                        date: parsedDate,
                        merchant: merchant,
                        amount: selectedType == .income ? amountValue : -amountValue,
                        category: parsedCategory,
                        account: "Manual",
                        type: selectedType,
                        importSource: .manual,
                        notes: "OCR scan: " + String(scannedText.prefix(100))
                    )
                    onAdd(txn)
                } label: {
                    Text("Save Transaction")
                        .font(KlarFonts.label(14))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(KlarColors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .background(KlarColors.background)
        .presentationDetents([.large])
        .fullScreenCover(isPresented: $showScanner) {
            ScannerCameraView { text in
                scannedText = text
                parseScannedText(text)
                showScanner = false
            } onCancel: {
                showScanner = false
                if scannedText.isEmpty { dismiss() }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isAmountFocused = false }.fontWeight(.semibold)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if scannedText.isEmpty {
                    showScanner = true
                }
            }
        }
    }

    private func parseScannedText(_ text: String) {
        let lower = text.lowercased()

        let amountPatterns = [
            #"(?:₹|rs\.?|inr)\s*([\d,]+\.?\d*)"#,
            #"(?:total|amount|grand total|net|due)[:\s]*([\d,]+\.?\d*)"#,
            #"([\d,]+\.\d{2})"#
        ]
        for pattern in amountPatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matched = String(text[match])
                let digits = matched.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
                if let value = Double(digits), value > 0 {
                    parsedAmount = String(format: "%.0f", value)
                    break
                }
            }
        }

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.count > 2 }
        if let firstLine = lines.first {
            parsedMerchant = String(firstLine.prefix(40))
        }

        parsedCategory = AutoCategorizer.categorize(description: lower, rules: rules)
        if parsedCategory == "Income" { parsedCategory = "Misc" }
    }
}

// MARK: - VisionKit Document Scanner
import VisionKit
import Vision

struct ScannerCameraView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onCancel: onCancel)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: (String) -> Void
        let onCancel: () -> Void

        init(onScan: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onScan = onScan
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Capture images before dismissing (scan object may not be valid after dismiss)
            var images: [CGImage] = []
            for i in 0..<scan.pageCount {
                if let cgImage = scan.imageOfPage(at: i).cgImage {
                    images.append(cgImage)
                }
            }

            controller.dismiss(animated: true) { [self] in
                // Run OCR on background thread to avoid blocking UI
                DispatchQueue.global(qos: .userInitiated).async {
                    var fullText = ""
                    for cgImage in images {
                        let request = VNRecognizeTextRequest()
                        request.recognitionLevel = .accurate
                        let handler = VNImageRequestHandler(cgImage: cgImage)
                        try? handler.perform([request])
                        if let observations = request.results {
                            let pageText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                            fullText += pageText + "\n"
                        }
                    }
                    let result = fullText
                    DispatchQueue.main.async {
                        self.onScan(result)
                    }
                }
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) { self.onCancel() }
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true) { self.onCancel() }
        }
    }
}
