import SwiftUI

struct ConflictResolverView: View {
    @Binding var conflicts: [(new: StatementParser.ParsedRow, existing: Transaction)]
    let onResolve: ([StatementParser.ParsedRow]) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex = 0
    @State private var resolved: [StatementParser.ParsedRow] = []

    private var currentConflict: (new: StatementParser.ParsedRow, existing: Transaction)? {
        guard currentIndex < conflicts.count else { return nil }
        return conflicts[currentIndex]
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("RESOLVE CONFLICTS")
                    .font(KlarFonts.heading(18))
                    .foregroundStyle(KlarColors.primary)
                Spacer()
                Text("\(currentIndex + 1) of \(conflicts.count)")
                    .font(KlarFonts.label(13))
                    .foregroundStyle(KlarColors.secondary)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(KlarColors.secondary)
                        .font(.system(size: 24))
                }
            }
            .padding(.top, 24)

            Text("We found a potential duplicate. Choose which to keep or merge them.")
                .font(KlarFonts.body(14))
                .foregroundStyle(KlarColors.secondary)

            if let conflict = currentConflict {
                HStack(spacing: 12) {
                    // New transaction card
                    newTransactionCard(conflict.new, label: "NEW IMPORT")
                    // Existing transaction card
                    existingTransactionCard(conflict.existing, label: "ALREADY EXISTS")
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(KlarColors.positive)
                    Text("All conflicts resolved!")
                        .font(KlarFonts.heading(18))
                        .foregroundStyle(KlarColors.primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer()

            if currentConflict != nil {
                HStack(spacing: 12) {
                    Button {
                        // Keep the new import (add it)
                        if let conflict = currentConflict {
                            resolved.append(conflict.new)
                        }
                        advanceOrFinish()
                    } label: {
                        Text("Keep New")
                            .font(KlarFonts.label(13))
                            .foregroundStyle(KlarColors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(KlarColors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button {
                        // Skip — keep existing only (don't add new)
                        advanceOrFinish()
                    } label: {
                        Text("Skip")
                            .font(KlarFonts.label(13))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(KlarColors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button {
                        // Keep both (add the new one alongside)
                        if let conflict = currentConflict {
                            resolved.append(conflict.new)
                        }
                        advanceOrFinish()
                    } label: {
                        Text("Keep Both")
                            .font(KlarFonts.label(13))
                            .foregroundStyle(KlarColors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(KlarColors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            } else {
                Button {
                    onResolve(resolved)
                    dismiss()
                } label: {
                    Text("Done")
                        .font(KlarFonts.label(14))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(KlarColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .background(KlarColors.background)
        .presentationDetents([.large])
    }

    private func advanceOrFinish() {
        withAnimation {
            currentIndex += 1
        }
    }

    private func newTransactionCard(_ row: StatementParser.ParsedRow, label: String) -> some View {
        let merchant = AutoCategorizer.extractMerchant(from: row.description)
        let category = AutoCategorizer.categorize(description: row.description, rules: [])

        return VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(KlarFonts.label(10))
                .tracking(1)
                .foregroundStyle(KlarColors.positive)

            Text(merchant.uppercased())
                .font(KlarFonts.heading(16))
                .foregroundStyle(KlarColors.primary)

            Text(row.type == .income
                ? CurrencyHelper.formatSigned(row.amount)
                : CurrencyHelper.formatSigned(-row.amount))
                .font(KlarFonts.display(22))
                .monospacedDigit()
                .foregroundStyle(row.type == .income ? KlarColors.positive : KlarColors.negative)

            Text(formatDate(row.date))
                .font(KlarFonts.label(11))
                .foregroundStyle(KlarColors.secondary)

            CategoryPill(name: category, color: KlarColors.categoryColor(for: category))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KlarColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func existingTransactionCard(_ txn: Transaction, label: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(KlarFonts.label(10))
                .tracking(1)
                .foregroundStyle(KlarColors.secondary)

            Text(txn.merchant.uppercased())
                .font(KlarFonts.heading(16))
                .foregroundStyle(KlarColors.primary)

            Text(CurrencyHelper.formatSigned(txn.amount))
                .font(KlarFonts.display(22))
                .monospacedDigit()
                .foregroundStyle(txn.amount >= 0 ? KlarColors.positive : KlarColors.negative)

            Text(formatDate(txn.date))
                .font(KlarFonts.label(11))
                .foregroundStyle(KlarColors.secondary)

            CategoryPill(name: txn.category, color: KlarColors.categoryColor(for: txn.category))

            Text(txn.account)
                .font(KlarFonts.label(10))
                .foregroundStyle(KlarColors.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KlarColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}
