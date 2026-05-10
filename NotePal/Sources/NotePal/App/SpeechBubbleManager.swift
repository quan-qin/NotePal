import Foundation

struct SpeechBubbleMessage {
    enum Kind {
        case greeting
        case reminder
        case completion
        case sleepy
        case error
        case mentor
    }

    var kind: Kind
    var text: String
    var duration: TimeInterval
    var isCritical: Bool
    var onClick: (() -> Void)?
}

@MainActor
final class SpeechBubbleManager {
    private let settings: SettingsStore
    private let presenter: (SpeechBubbleMessage, @escaping (Bool) -> Void) -> Void
    private let interruptCurrent: () -> Void
    private var queue: [SpeechBubbleMessage] = []
    private var isPresenting = false
    private var currentMessage: SpeechBubbleMessage?
    private var recentMessages: [String: Date] = [:]

    init(
        settings: SettingsStore,
        interruptCurrent: @escaping () -> Void = {},
        presenter: @escaping (SpeechBubbleMessage, @escaping (Bool) -> Void) -> Void
    ) {
        self.settings = settings
        self.interruptCurrent = interruptCurrent
        self.presenter = presenter
    }

    func enqueue(_ message: SpeechBubbleMessage) {
        guard message.isCritical || !settings.muteNonCriticalDialogue else {
            return
        }

        let now = Date()
        if let lastShown = recentMessages[message.text], now.timeIntervalSince(lastShown) < 5 {
            return
        }

        recentMessages[message.text] = now

        if message.isCritical {
            queue.removeAll { !$0.isCritical }
        } else if isMentorDialogue(message) {
            queue.removeAll { isMentorDialogue($0) }
        }

        queue.append(message)
        queue = Array(queue.suffix(4))

        if isMentorDialogue(message), isPresenting, currentMessage.map(isMentorDialogue) == true {
            interruptCurrent()
            return
        }

        if message.isCritical, isPresenting, currentMessage?.isCritical == false {
            interruptCurrent()
            return
        }

        presentNextIfNeeded()
    }

    private func presentNextIfNeeded() {
        guard !isPresenting, !queue.isEmpty else {
            return
        }

        isPresenting = true
        let message = queue.removeFirst()
        currentMessage = message

        presenter(message) { [weak self] clicked in
            Task { @MainActor in
                if clicked {
                    message.onClick?()
                }

                self?.currentMessage = nil
                self?.isPresenting = false
                self?.presentNextIfNeeded()
            }
        }
    }

    private func isMentorDialogue(_ message: SpeechBubbleMessage) -> Bool {
        if case .mentor = message.kind {
            return true
        }

        return false
    }
}
