import SwiftUI

struct WellnessReminderSection: View {
    @ObservedObject var wellnessReminderStore: WellnessReminderStore

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { timeline in
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.25, green: 0.58, blue: 0.36))

                    Text("养生提醒")
                        .font(.caption.weight(.semibold))

                    Spacer()
                }

                VStack(spacing: 8) {
                    ForEach(wellnessReminderStore.reminders) { reminder in
                        WellnessReminderRow(
                            reminder: reminder,
                            now: timeline.date,
                            wellnessReminderStore: wellnessReminderStore
                        )
                    }
                }
            }
            .padding(10)
            .background(sectionBackground)
        }
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

private struct WellnessReminderRow: View {
    let reminder: WellnessReminder
    let now: Date
    @ObservedObject var wellnessReminderStore: WellnessReminderStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Toggle(
                    reminder.title,
                    isOn: Binding(
                        get: { reminder.isEnabled },
                        set: { wellnessReminderStore.setEnabled(kind: reminder.kind, isEnabled: $0) }
                    )
                )
                .toggleStyle(.switch)
                .font(.caption)

                Spacer()
            }

            HStack {
                Stepper(
                    "每 \(formattedInterval(reminder.effectiveIntervalMinutes))",
                    value: Binding(
                        get: { reminder.effectiveIntervalMinutes },
                        set: { wellnessReminderStore.setInterval(kind: reminder.kind, minutes: $0) }
                    ),
                    in: 5...1440,
                    step: 5
                )
                .font(.caption2)
                .disabled(!reminder.isEnabled)
                .opacity(reminder.isEnabled ? 1 : 0.45)

                Spacer()

                if reminder.isEnabled {
                    Text("下次 \(countdownText(to: reminder.nextReminderAt, from: now))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
    }

    private func formattedInterval(_ minutes: Int) -> String {
        if minutes.isMultiple(of: 60) {
            let hours = minutes / 60
            return "\(hours) 小时"
        }

        return "\(minutes) 分钟"
    }

    private func countdownText(to date: Date, from now: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        if minutes > 0 {
            return "\(minutes)m \(remainingSeconds)s"
        }

        return "\(remainingSeconds)s"
    }
}
