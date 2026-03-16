import SwiftUI
import UserNotifications

struct SubscriptionAuditView: View {
    @State private var subscriptions = MockData.subscriptions
    @State private var reminderStates: [UUID: Bool] = [:]

    var body: some View {
        KlarCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "SUBSCRIPTION AUDIT")

                ForEach(Array(subscriptions.enumerated()), id: \.element.id) { index, sub in
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Text(String(format: "%02d.", index + 1))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(KlarColors.secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(sub.name.uppercased())
                                    .font(KlarFonts.label(13))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)

                                CategoryPill(
                                    name: sub.category,
                                    color: KlarColors.categoryColor(for: sub.category)
                                )
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formatSubAmount(sub))
                                    .font(KlarFonts.label(13))
                                    .monospacedDigit()
                                    .foregroundStyle(KlarColors.negative)

                                Text("Next bill: \(formatNextBill(sub.nextBillDate))")
                                    .font(KlarFonts.label(10))
                                    .foregroundStyle(KlarColors.secondary)
                            }
                        }

                        HStack {
                            Text("Cancel Reminder")
                                .font(KlarFonts.label(11))
                                .foregroundStyle(KlarColors.secondary)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { reminderStates[sub.id] ?? sub.cancelReminderEnabled },
                                set: { newVal in
                                    reminderStates[sub.id] = newVal
                                    if newVal {
                                        scheduleReminder(for: sub)
                                    }
                                }
                            ))
                            .tint(KlarColors.positive)
                            .labelsHidden()
                        }
                        .padding(.top, 8)

                        if index < subscriptions.count - 1 {
                            Divider()
                                .background(KlarColors.barTrack)
                                .padding(.top, 12)
                        }
                    }
                }
            }
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
}
