import SwiftUI

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
            // Header
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
                // Spacer for balance
                Color.clear.frame(width: 16, height: 16)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 20) {
                    // Type picker
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

                    // Amount
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

                    // Merchant
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

                    // Date
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

                    // Category
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

                    // Notes
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

            // Save button
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
