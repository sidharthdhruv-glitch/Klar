import SwiftUI
import SwiftData
import UserNotifications

struct SubscriptionAuditView: View {
    @Query private var subscriptions: [Subscription]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddSubscription = false

    var body: some View {
        KlarCard(dashedBorder: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SectionHeader(title: "SUBSCRIPTION AUDIT")
                    Spacer()
                    Button {
                        showAddSubscription = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(KlarColors.primary)
                            .font(.system(size: 18))
                    }
                }

                if subscriptions.isEmpty {
                    VStack(spacing: 8) {
                        Text("No subscriptions tracked")
                            .font(KlarFonts.body(14))
                            .foregroundStyle(KlarColors.secondary)
                        Text("Add your recurring subscriptions to track billing dates.")
                            .font(KlarFonts.label(11))
                            .foregroundStyle(KlarColors.inactive)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else {
                    ForEach(Array(subscriptions.enumerated()), id: \.element.id) { index, sub in
                        VStack(spacing: 0) {
                            HStack(spacing: 12) {
                                Text(String(format: "%02d.", index + 1))
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(KlarColors.primary)

                                Text(sub.name.uppercased())
                                    .font(KlarFonts.heading(14))
                                    .foregroundStyle(KlarColors.primary)

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(formatSubAmount(sub))
                                        .font(KlarFonts.label(13))
                                        .monospacedDigit()
                                        .foregroundStyle(KlarColors.negative)

                                    Text("Next bill: \(formatNextBill(sub.nextBillDate))")
                                        .font(KlarFonts.label(10))
                                        .foregroundStyle(KlarColors.positive)
                                }
                            }

                            if index < subscriptions.count - 1 {
                                Divider()
                                    .background(KlarColors.barTrack)
                                    .padding(.top, 12)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelContext.delete(sub)
                                try? modelContext.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSubscription) {
            AddSubscriptionSheet()
        }
    }

    private func formatSubAmount(_ sub: Subscription) -> String {
        let formatted = CurrencyHelper.format(sub.amount)
        return "\(formatted)/\(sub.billingCycle == .monthly ? "Month" : "Year")"
    }

    private func formatNextBill(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd MMM ''yy"
        return f.string(from: date)
    }

    private func scheduleReminder(for sub: Subscription) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Subscription Reminder"
            content.body = "\(sub.name) billing in 3 days — \(CurrencyHelper.format(sub.amount))"
            content.sound = .default

            let reminderDate = Calendar.current.date(byAdding: .day, value: -3, to: sub.nextBillDate) ?? sub.nextBillDate
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: reminderDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: sub.id.uuidString, content: content, trigger: trigger)
            center.add(request)
        }
    }

    private func cancelReminder(for sub: Subscription) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [sub.id.uuidString])
    }
}

// MARK: - Add Subscription Sheet
struct AddSubscriptionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amount = ""
    @State private var billingCycle: BillingCycle = .monthly
    @State private var nextBillDate = Date()
    @State private var selectedCategory = "Entertainment"

    let categoryNames = ["Entertainment", "Health", "Finance", "Food", "Shopping", "Transport", "Utilities", "Misc"]

    var body: some View {
        VStack(spacing: 20) {
            Text("ADD SUBSCRIPTION")
                .font(KlarFonts.heading(18))
                .foregroundStyle(KlarColors.primary)
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("NAME")
                    .font(KlarFonts.label(11))
                    .tracking(1)
                    .foregroundStyle(KlarColors.secondary)
                TextField("e.g. Netflix, Spotify", text: $name)
                    .font(KlarFonts.body(14))
                    .foregroundStyle(KlarColors.primary)
                    .padding(14)
                    .background(KlarColors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("AMOUNT")
                    .font(KlarFonts.label(11))
                    .tracking(1)
                    .foregroundStyle(KlarColors.secondary)
                TextField("499", text: $amount)
                    .font(KlarFonts.body(14))
                    .foregroundStyle(KlarColors.primary)
                    .keyboardType(.decimalPad)
                    .padding(14)
                    .background(KlarColors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            HStack {
                Text("BILLING CYCLE")
                    .font(KlarFonts.label(11))
                    .tracking(1)
                    .foregroundStyle(KlarColors.secondary)
                Spacer()
                Picker("Cycle", selection: $billingCycle) {
                    Text("Monthly").tag(BillingCycle.monthly)
                    Text("Yearly").tag(BillingCycle.yearly)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            DatePicker("Next Bill Date", selection: $nextBillDate, displayedComponents: .date)
                .font(KlarFonts.body(14))
                .foregroundStyle(KlarColors.primary)

            VStack(alignment: .leading, spacing: 8) {
                Text("CATEGORY")
                    .font(KlarFonts.label(11))
                    .tracking(1)
                    .foregroundStyle(KlarColors.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(categoryNames, id: \.self) { cat in
                        Button {
                            selectedCategory = cat
                        } label: {
                            Text(cat.uppercased())
                                .font(KlarFonts.label(10))
                                .foregroundStyle(selectedCategory == cat ? .white : KlarColors.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(selectedCategory == cat ? KlarColors.categoryColor(for: cat) : KlarColors.surfaceElevated)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Spacer()

            Button {
                guard !name.isEmpty, let amountVal = Double(amount) else { return }
                let sub = Subscription(
                    name: name,
                    amount: amountVal,
                    billingCycle: billingCycle,
                    nextBillDate: nextBillDate,
                    category: selectedCategory
                )
                modelContext.insert(sub)
                try? modelContext.save()
                dismiss()
            } label: {
                Text("Add Subscription")
                    .font(KlarFonts.label(14))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(KlarColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 20)
        .background(KlarColors.background)
        .presentationDetents([.large])
    }
}
