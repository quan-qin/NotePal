import Foundation

@MainActor
final class PetInteractionManager: ObservableObject {
    @Published private(set) var state: PetState = .idle
    @Published private(set) var isHovering = false
    @Published private(set) var bounceToken = 0
    @Published private(set) var celebrateToken = 0

    var onSleep: (() -> Void)?

    private let settings: SettingsStore
    private var sleepTimer: Timer?
    private var temporaryTask: Task<Void, Never>?
    private var panelOpen = false
    private var reminderActive = false

    init(settings: SettingsStore) {
        self.settings = settings
        scheduleSleepTimer()
    }

    func userActivity() {
        if state == .sleeping {
            setTemporaryState(.happy, duration: 1.4)
        }

        scheduleSleepTimer()
    }

    func clicked() {
        userActivity()
        bounceToken += 1
        setTemporaryState(.focused, duration: 0.8)
    }

    func doubleClicked() {
        userActivity()
        bounceToken += 1
        setTemporaryState(.happy, duration: 1.8)
    }

    func rightClicked() {
        userActivity()
        setTemporaryState(.surprised, duration: 1.0)
    }

    func dragging() {
        userActivity()
        state = .focused
    }

    func dragEnded() {
        returnToBaseState()
    }

    func setHovering(_ hovering: Bool) {
        isHovering = hovering
        if hovering {
            userActivity()
        }
    }

    func setPanelOpen(_ isOpen: Bool) {
        panelOpen = isOpen
        userActivity()
        returnToBaseState()
    }

    func reminderStarted() {
        reminderActive = true
        userActivity()
        state = .reminding
    }

    func reminderAcknowledged() {
        reminderActive = false
        userActivity()
        returnToBaseState()
    }

    func todoCompleted() {
        userActivity()
        celebrateToken += 1
        setTemporaryState(.celebrating, duration: 2.0)
    }

    func saveFailed() {
        userActivity()
        setTemporaryState(.surprised, duration: 1.8)
    }

    private func setTemporaryState(_ newState: PetState, duration: TimeInterval) {
        temporaryTask?.cancel()
        state = newState

        temporaryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(duration * 1000)))
            guard !Task.isCancelled else { return }
            self?.returnToBaseState()
        }
    }

    private func returnToBaseState() {
        if reminderActive {
            state = .reminding
        } else if panelOpen {
            state = .thinking
        } else {
            state = .idle
        }
    }

    private func scheduleSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil

        guard settings.idleToSleepDuration > 0 else {
            return
        }

        let timer = Timer(timeInterval: settings.idleToSleepDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.enterSleep()
            }
        }
        timer.tolerance = min(10, settings.idleToSleepDuration * 0.1)
        RunLoop.main.add(timer, forMode: .common)
        sleepTimer = timer
    }

    private func enterSleep() {
        guard !panelOpen, !reminderActive else {
            scheduleSleepTimer()
            return
        }

        temporaryTask?.cancel()
        state = .sleeping
        onSleep?()
    }
}
