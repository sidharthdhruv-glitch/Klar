import SwiftUI
import SwiftData

struct LedgerView: View {
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query private var categories: [Category]
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var isSelectMode = false
    @State private var selectedTransactions: Set<UUID> = []
    @State private var showCategoryPicker = false
    @State private var filteredResults: [Transaction]?
    @State private var showDeleteConfirmation = false
    @State private var transactionToDelete: Transaction?
    @State private var isRefreshing = false

    private var displayTransactions: [Transaction] {
        filteredResults ?? Array(transactions)
    }

    private var merchantSparklines: [String: [Double]] {
        var merchantTxns: [String: [Transaction]] = [:]
        for txn in transactions where txn.amount < 0 {
            merchantTxns[txn.merchant, default: []].append(txn)
        }
        var result: [String: [Double]] = [:]
        for (merchant, txns) in merchantTxns where txns.count >= 3 {
            let sorted = txns.sorted { $0.date < $1.date }
            result[merchant] = sorted.suffix(6).map { abs($0.amount) }
        }
        return result
    }

    private var groupedTransactions: [(String, [Transaction])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"

        let grouped = Dictionary(grouping: displayTransactions) { txn -> String in
            formatter.string(from: txn.date)
        }

        return grouped.sorted { pair1, pair2 in
            guard let d1 = pair1.value.first?.date, let d2 = pair2.value.first?.date else { return false }
            return d1 > d2
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    Text("THE ")
                        .font(KlarFonts.serifItalic(28))
                        .foregroundStyle(KlarColors.secondary)
                    Text("LEDGER")
                        .font(KlarFonts.display(28))
                        .foregroundStyle(KlarColors.primary)
                }
                .padding(.top, 16)

                // Smart Search
                KlarCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(KlarColors.searchHighlight)
                                .font(.system(size: 14))
                            Text("SMART SEARCH")
                                .font(KlarFonts.cardTitle())
                                .tracking(1.5)
                                .foregroundStyle(KlarColors.primary)
                        }

                        HStack {
                            TextField("\"How much did I spend at Amazon in December?\"", text: $searchText)
                                .font(KlarFonts.body(13))
                                .foregroundStyle(KlarColors.primary)
                                .onSubmit {
                                    performSmartSearch()
                                    HapticManager.light()
                                }
                                .onChange(of: searchText) { _, newValue in
                                    if newValue.isEmpty {
                                        filteredResults = nil
                                    }
                                }

                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                    filteredResults = nil
                                    HapticManager.light()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(KlarColors.secondary)
                                }
                            }

                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(KlarColors.secondary)
                                .font(.system(size: 16))
                        }
                        .padding(12)
                        .background(KlarColors.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 20)
            }

            if transactions.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                // Transaction Feed
                ScrollView {
                    // Pull to refresh indicator
                    GeometryReader { geo in
                        let offset = geo.frame(in: .named("scroll")).minY
                        Color.clear
                            .preference(key: ScrollOffsetKey.self, value: offset)
                    }
                    .frame(height: 0)

                    if isRefreshing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(KlarColors.accent)
                            Text("Refreshing...")
                                .font(KlarFonts.label(12))
                                .foregroundStyle(KlarColors.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(Array(groupedTransactions.enumerated()), id: \.element.0) { sectionIndex, group in
                            Section {
                                KlarCard {
                                    VStack(spacing: 0) {
                                        ForEach(Array(group.1.enumerated()), id: \.element.id) { rowIndex, transaction in
                                            TransactionRow(
                                                transaction: transaction,
                                                index: globalIndexFor(sectionIndex: sectionIndex, rowIndex: rowIndex),
                                                isSelectMode: isSelectMode,
                                                isSelected: selectedTransactions.contains(transaction.id),
                                                merchantSparkData: merchantSparklines[transaction.merchant]
                                            )
                                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                                Button(role: .destructive) {
                                                    withAnimation {
                                                        modelContext.delete(transaction)
                                                        try? modelContext.save()
                                                    }
                                                    HapticManager.medium()
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                                Button {
                                                    transactionToDelete = nil
                                                    selectedTransactions = [transaction.id]
                                                    showCategoryPicker = true
                                                    HapticManager.light()
                                                } label: {
                                                    Label("Category", systemImage: "tag")
                                                }
                                                .tint(KlarColors.accent)
                                            }
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    transactionToDelete = transaction
                                                    showDeleteConfirmation = true
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                                Button {
                                                    withAnimation {
                                                        isSelectMode = true
                                                        selectedTransactions.insert(transaction.id)
                                                    }
                                                    HapticManager.medium()
                                                } label: {
                                                    Label("Select", systemImage: "checkmark.circle")
                                                }
                                            }
                                            .onTapGesture {
                                                if isSelectMode {
                                                    toggleSelection(transaction.id)
                                                    HapticManager.selection()
                                                }
                                            }
                                            .onLongPressGesture {
                                                withAnimation {
                                                    isSelectMode = true
                                                    selectedTransactions.insert(transaction.id)
                                                }
                                                HapticManager.medium()
                                            }

                                            if rowIndex < group.1.count - 1 {
                                                Divider()
                                                    .background(KlarColors.border)
                                                    .padding(.horizontal, 4)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            } header: {
                                dateHeader(group.0, isToday: isToday(group.1.first?.date))
                            }
                        }
                    }
                    .padding(.bottom, isSelectMode ? 60 : 20)
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetKey.self) { offset in
                    if offset > 80 && !isRefreshing {
                        triggerRefresh()
                    }
                }
            }

            // Batch action bar
            if isSelectMode {
                batchActionBar
            }
        }
        .background(KlarColors.background)
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerSheet { category in
                updateSelectedTransactionsCategory(to: category)
                showCategoryPicker = false
                isSelectMode = false
                selectedTransactions.removeAll()
                HapticManager.success()
            }
        }
        .alert("Delete Transaction", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                transactionToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let txn = transactionToDelete {
                    withAnimation {
                        modelContext.delete(txn)
                        try? modelContext.save()
                    }
                    transactionToDelete = nil
                    HapticManager.medium()
                }
            }
        } message: {
            if let txn = transactionToDelete {
                Text("Delete \(txn.merchant) (\(CurrencyHelper.formatSigned(txn.amount)))?")
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            HStack(spacing: -8) {
                ForEach(["list.bullet.rectangle", "doc.text", "creditcard"], id: \.self) { icon in
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .frame(width: 44, height: 44)
                        .background(KlarColors.surfaceElevated)
                        .clipShape(Circle())
                }
            }

            Text("No transactions yet")
                .font(KlarFonts.heading(18))
                .foregroundStyle(KlarColors.primary)
            Text("Import a statement to see transactions here.")
                .font(KlarFonts.body(14))
                .foregroundStyle(KlarColors.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Pull to Refresh
    private func triggerRefresh() {
        isRefreshing = true
        HapticManager.light()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(KlarAnimation.springDefault) {
                isRefreshing = false
            }
            HapticManager.success()
        }
    }

    private func isToday(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private func globalIndexFor(sectionIndex: Int, rowIndex: Int) -> Int {
        var count = 0
        for i in 0..<sectionIndex {
            count += groupedTransactions[i].1.count
        }
        return count + rowIndex + 1
    }

    private func dateHeader(_ dateString: String, isToday: Bool) -> some View {
        HStack {
            if isToday {
                Text("TODAY, \(dateString.uppercased())")
            } else {
                Text(dateString.uppercased())
            }
        }
        .font(KlarFonts.heading(16))
        .foregroundStyle(KlarColors.primary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(KlarColors.background)
    }

    private func toggleSelection(_ id: UUID) {
        if selectedTransactions.contains(id) {
            selectedTransactions.remove(id)
            if selectedTransactions.isEmpty {
                withAnimation { isSelectMode = false }
            }
        } else {
            selectedTransactions.insert(id)
        }
    }

    private func performSmartSearch() {
        let query = searchText.lowercased()
        guard !query.isEmpty else {
            filteredResults = nil
            return
        }

        let months = ["january": 1, "february": 2, "march": 3, "april": 4,
                      "may": 5, "june": 6, "july": 7, "august": 8,
                      "september": 9, "october": 10, "november": 11, "december": 12]

        var monthFilter: Int?
        for (name, num) in months {
            if query.contains(name) {
                monthFilter = num
                break
            }
        }

        filteredResults = transactions.filter { txn in
            let matchesMerchant = txn.merchant.lowercased().contains(query)
            let matchesCategory = txn.category.lowercased().contains(query)
            let matchesNotes = (txn.notes ?? "").lowercased().contains(query)
            let matchesAccount = txn.account.lowercased().contains(query)

            let textMatch = matchesMerchant || matchesCategory || matchesNotes || matchesAccount

            if let month = monthFilter {
                let txnMonth = Calendar.current.component(.month, from: txn.date)
                return txnMonth == month || textMatch
            }

            return textMatch
        }
    }

    private func updateSelectedTransactionsCategory(to category: String) {
        for txn in transactions where selectedTransactions.contains(txn.id) {
            txn.category = category
        }
        try? modelContext.save()
    }

    private func deleteSelectedTransactions() {
        for txn in transactions where selectedTransactions.contains(txn.id) {
            modelContext.delete(txn)
        }
        try? modelContext.save()
        selectedTransactions.removeAll()
        withAnimation { isSelectMode = false }
        HapticManager.medium()
    }

    private var batchActionBar: some View {
        HStack {
            Text("\(selectedTransactions.count) Selected")
                .font(KlarFonts.label(14))
                .foregroundStyle(KlarColors.primary)
            Spacer()

            Button {
                deleteSelectedTransactions()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                    Text("Delete")
                        .font(KlarFonts.label(13))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(KlarColors.negative)
                .clipShape(Capsule())
            }

            Button("Category") {
                showCategoryPicker = true
                HapticManager.light()
            }
            .font(KlarFonts.label(13))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(KlarColors.accent)
            .clipShape(Capsule())

            Button {
                withAnimation {
                    isSelectMode = false
                    selectedTransactions.removeAll()
                }
                HapticManager.light()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(KlarColors.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(KlarColors.surface)
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Transaction Row (Task 9: Redesigned)
struct TransactionRow: View {
    let transaction: Transaction
    let index: Int
    let isSelectMode: Bool
    let isSelected: Bool
    var merchantSparkData: [Double]? = nil

    var body: some View {
        HStack(spacing: 12) {
            if isSelectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? KlarColors.accent : KlarColors.inactive)
                    .font(.system(size: 20))
            }

            // Category icon
            let catColor = KlarColors.categoryColor(for: transaction.category)
            RoundedRectangle(cornerRadius: 8)
                .fill(catColor.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: categorySymbol(for: transaction.category))
                        .font(.system(size: 14))
                        .foregroundStyle(catColor)
                )

            // Merchant + category pill
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant.uppercased())
                    .font(KlarFonts.label(13))
                    .fontWeight(.bold)
                    .foregroundStyle(KlarColors.primary)
                    .lineLimit(1)

                CategoryPill(name: transaction.category, color: catColor)
            }

            Spacer()

            // Sparkline for frequent merchants
            if let sparkData = merchantSparkData, sparkData.count >= 3 {
                SparklineView(
                    data: sparkData,
                    trendColor: KlarColors.negative,
                    height: 20,
                    lineWidth: 1.2,
                    showGradientFill: false,
                    showEndDot: true
                )
                .frame(width: 50)
            }

            // Amount + date
            VStack(alignment: .trailing, spacing: 4) {
                Text(CurrencyHelper.formatSigned(transaction.amount))
                    .font(KlarFonts.label(14))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(transaction.amount >= 0 ? KlarColors.positive : KlarColors.negative)

                Text(formatDate(transaction.date))
                    .font(KlarFonts.label(10))
                    .foregroundStyle(KlarColors.secondary)
            }
        }
        .padding(.vertical, 10)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM"
        return f.string(from: date)
    }

    private func categorySymbol(for category: String) -> String {
        switch category.lowercased() {
        case "shopping": return "bag.fill"
        case "entertainment": return "tv.fill"
        case "health": return "heart.fill"
        case "finance": return "banknote.fill"
        case "transport": return "car.fill"
        case "utilities": return "bolt.fill"
        case "misc": return "ellipsis.circle.fill"
        case "food": return "fork.knife"
        case "income": return "indianrupeesign.circle.fill"
        default: return "circle.fill"
        }
    }
}

struct CategoryPickerSheet: View {
    let onSelect: (String) -> Void
    @Query private var categories: [Category]

    private var displayCategories: [Category] {
        if categories.isEmpty {
            return DefaultData.categories
        }
        return Array(categories)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("CHANGE CATEGORY")
                .font(KlarFonts.heading(18))
                .foregroundStyle(KlarColors.primary)
                .padding(.top, 24)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 16) {
                ForEach(displayCategories, id: \.name) { cat in
                    Button {
                        onSelect(cat.name)
                        HapticManager.medium()
                    } label: {
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: cat.colorHex).opacity(0.15))
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Image(systemName: cat.sfSymbol)
                                        .foregroundStyle(Color(hex: cat.colorHex))
                                )

                            Text(cat.name.uppercased())
                                .font(KlarFonts.label(10))
                                .tracking(0.5)
                                .foregroundStyle(KlarColors.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(KlarColors.background)
        .presentationDetents([.medium])
    }
}
