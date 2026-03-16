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

    private var displayTransactions: [Transaction] {
        filteredResults ?? Array(transactions)
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
            VStack(alignment: .leading, spacing: 12) {
                Text("THE LEDGER")
                    .font(KlarFonts.display(28))
                    .foregroundStyle(.white)

                // Smart Search
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkle")
                            .foregroundStyle(KlarColors.positive)
                            .font(.system(size: 14))

                        TextField("How much did I spend at Amazon in December?", text: $searchText)
                            .font(KlarFonts.body(14))
                            .foregroundStyle(.white)
                            .onSubmit {
                                performSmartSearch()
                            }
                            .onChange(of: searchText) { _, newValue in
                                if newValue.isEmpty {
                                    filteredResults = nil
                                }
                            }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(KlarColors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            filteredResults = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(KlarColors.secondary)
                        }
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                    Text("SMART SEARCH")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(KlarColors.positive)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(KlarColors.positive.opacity(0.1))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            if transactions.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 48))
                        .foregroundStyle(KlarColors.inactive)
                    Text("No transactions yet")
                        .font(KlarFonts.heading(18))
                        .foregroundStyle(KlarColors.secondary)
                    Text("Import a statement to see transactions here.")
                        .font(KlarFonts.body(14))
                        .foregroundStyle(KlarColors.inactive)
                }
                Spacer()
            } else {
                // Transaction Feed
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(Array(groupedTransactions.enumerated()), id: \.element.0) { sectionIndex, group in
                            Section {
                                ForEach(Array(group.1.enumerated()), id: \.element.id) { rowIndex, transaction in
                                    let globalIndex = globalIndexFor(sectionIndex: sectionIndex, rowIndex: rowIndex)
                                    TransactionRow(
                                        transaction: transaction,
                                        index: globalIndex,
                                        isSelectMode: isSelectMode,
                                        isSelected: selectedTransactions.contains(transaction.id)
                                    )
                                    .onTapGesture {
                                        if isSelectMode {
                                            toggleSelection(transaction.id)
                                        }
                                    }
                                    .onLongPressGesture {
                                        withAnimation {
                                            isSelectMode = true
                                            selectedTransactions.insert(transaction.id)
                                        }
                                        let impact = UIImpactFeedbackGenerator(style: .medium)
                                        impact.impactOccurred()
                                    }
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                            } header: {
                                dateHeader(group.0, isToday: isToday(group.1.first?.date))
                            }
                        }
                    }
                    .padding(.bottom, isSelectMode ? 80 : 100)
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
            }
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
        .font(KlarFonts.label(11))
        .tracking(1.5)
        .foregroundStyle(KlarColors.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
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

        // Parse for month names
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

    private var batchActionBar: some View {
        HStack {
            Text("\(selectedTransactions.count) Selected")
                .font(KlarFonts.label(14))
                .foregroundStyle(.white)
            Spacer()
            Button("Change Category") {
                showCategoryPicker = true
            }
            .font(KlarFonts.label(13))
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.white)
            .clipShape(Capsule())

            Button {
                withAnimation {
                    isSelectMode = false
                    selectedTransactions.removeAll()
                }
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

struct TransactionRow: View {
    let transaction: Transaction
    let index: Int
    let isSelectMode: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isSelectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .white : KlarColors.inactive)
                    .font(.system(size: 20))
            }

            Text(String(format: "%02d", index))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(KlarColors.secondary)

            let catColor = KlarColors.categoryColor(for: transaction.category)
            let catSymbol = categorySymbol(for: transaction.category)
            RoundedRectangle(cornerRadius: 8)
                .fill(catColor.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: catSymbol)
                        .font(.system(size: 14))
                        .foregroundStyle(catColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchant.uppercased())
                    .font(KlarFonts.label(13))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    CategoryPill(name: transaction.category, color: catColor)
                    if let notes = transaction.notes {
                        Text(notes.uppercased())
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(KlarColors.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(CurrencyHelper.formatSigned(transaction.amount))
                    .font(KlarFonts.label(14))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(transaction.amount >= 0 ? KlarColors.positive : KlarColors.negative)

                Text(transaction.account)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(KlarColors.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
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
                .foregroundStyle(.white)
                .padding(.top, 24)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ], spacing: 16) {
                ForEach(displayCategories, id: \.name) { cat in
                    Button {
                        onSelect(cat.name)
                    } label: {
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: cat.colorHex).opacity(0.2))
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
