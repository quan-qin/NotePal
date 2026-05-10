import Foundation
import CoreGraphics

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var animationsEnabled: Bool {
        didSet { defaults.set(animationsEnabled, forKey: Keys.animationsEnabled) }
    }

    @Published var reducedMotionMode: Bool {
        didSet { defaults.set(reducedMotionMode, forKey: Keys.reducedMotionMode) }
    }

    @Published var muteNonCriticalDialogue: Bool {
        didSet { defaults.set(muteNonCriticalDialogue, forKey: Keys.muteNonCriticalDialogue) }
    }

    @Published var idleToSleepDuration: TimeInterval {
        didSet { defaults.set(idleToSleepDuration, forKey: Keys.idleToSleepDuration) }
    }

    @Published var reminderBubbleDuration: TimeInterval {
        didSet { defaults.set(reminderBubbleDuration, forKey: Keys.reminderBubbleDuration) }
    }

    @Published var generalBubbleDuration: TimeInterval {
        didSet { defaults.set(generalBubbleDuration, forKey: Keys.generalBubbleDuration) }
    }

    @Published var petSize: CGFloat {
        didSet { defaults.set(Double(petSize), forKey: Keys.petSize) }
    }

    @Published var selectedPetThemeID: String

    @Published private(set) var unlockedSpecialThemeIDs: Set<String> {
        didSet {
            defaults.set(Array(unlockedSpecialThemeIDs).sorted(), forKey: Keys.unlockedSpecialThemeIDs)
        }
    }

    var selectedPetTheme: PetTheme {
        guard
            let theme = PetTheme(storedValue: selectedPetThemeID),
            isUnlocked(theme)
        else {
            return .newton
        }

        return theme
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let unlockedThemeIDs = Set(
            (defaults.stringArray(forKey: Keys.unlockedSpecialThemeIDs) ?? []).map { id in
                PetTheme(storedValue: id)?.rawValue ?? id
            }
        )
        self.animationsEnabled = defaults.object(forKey: Keys.animationsEnabled) as? Bool ?? true
        self.reducedMotionMode = defaults.object(forKey: Keys.reducedMotionMode) as? Bool ?? false
        self.muteNonCriticalDialogue = defaults.object(forKey: Keys.muteNonCriticalDialogue) as? Bool ?? false
        self.idleToSleepDuration = defaults.object(forKey: Keys.idleToSleepDuration) as? TimeInterval ?? 300
        self.reminderBubbleDuration = defaults.object(forKey: Keys.reminderBubbleDuration) as? TimeInterval ?? 8
        self.generalBubbleDuration = defaults.object(forKey: Keys.generalBubbleDuration) as? TimeInterval ?? 4
        self.petSize = CGFloat(defaults.object(forKey: Keys.petSize) as? Double ?? 96)
        self.unlockedSpecialThemeIDs = unlockedThemeIDs
        self.selectedPetThemeID = PetTheme.newton.rawValue
        defaults.removeObject(forKey: Keys.selectedPetThemeID)
    }

    func isUnlocked(_ theme: PetTheme) -> Bool {
        guard theme.isSpecial else {
            return true
        }

        return theme.storedIDs.contains(where: unlockedSpecialThemeIDs.contains)
            && PetThemeCredentialStore.hasSavedKey(for: theme)
    }

    func selectTheme(_ theme: PetTheme) -> Bool {
        guard isUnlocked(theme) else {
            return false
        }

        selectedPetThemeID = theme.rawValue
        return true
    }

    func unlock(_ theme: PetTheme) {
        guard theme.isSpecial else {
            return
        }

        unlockedSpecialThemeIDs.insert(theme.rawValue)
    }
}

private enum Keys {
    static let animationsEnabled = "animationsEnabled"
    static let reducedMotionMode = "reducedMotionMode"
    static let muteNonCriticalDialogue = "muteNonCriticalDialogue"
    static let idleToSleepDuration = "idleToSleepDuration"
    static let reminderBubbleDuration = "reminderBubbleDuration"
    static let generalBubbleDuration = "generalBubbleDuration"
    static let petSize = "petSize"
    static let selectedPetThemeID = "selectedPetThemeID"
    static let unlockedSpecialThemeIDs = "unlockedSpecialThemeIDs"
}
