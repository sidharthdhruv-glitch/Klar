import SwiftUI

struct ConflictResolverView: View {
    @Environment(\.dismiss) private var dismiss

    let leftTransaction = MockData.transactions[2]
    let rightTransaction = MockData.transactions[6]

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("RESOLVE CONFLICT")
                    .font(KlarFonts.heading(18))
                    .foregroundStyle(.white)
                Spacer()
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

            // Side by side cards
            HStack(spacing: 12) {
                conflictCard(leftTransaction, label: "SOURCE A")
                conflictCard(rightTransaction, label: "SOURCE B")
            }

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Keep Left")
                        .font(KlarFonts.label(13))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(KlarColors.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Merge")
                        .font(KlarFonts.label(13))
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Keep Right")
                        .font(KlarFonts.label(13))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(KlarColors.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
        .background(KlarColors.background)
        .presentationDetents([.large])
    }

    private func conflictCard(_ txn: Transaction, label: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label)
                .font(KlarFonts.label(10))
                .tracking(1)
                .foregroundStyle(KlarColors.secondary)

            Text(txn.merchant.uppercased())
                .font(KlarFonts.heading(16))
                .foregroundStyle(.white)

            Text(CurrencyHelper.format(txn.amount))
                .font(KlarFonts.display(22))
                .monospacedDigit()
                .foregroundStyle(txn.amount >= 0 ? KlarColors.positive : KlarColors.negative)

            let formatter = DateFormatter()
            Text(formattedDate(txn.date))
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

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}
