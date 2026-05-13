import AppKit

@MainActor
final class NotePalAppDelegate: NSObject, NSApplicationDelegate {
    private let storage = LocalDataStore.shared
    private let settingsStore = SettingsStore.shared

    private var noteStore: NoteStore!
    private var todoStore: TodoStore!
    private var wellnessReminderStore: WellnessReminderStore!
    private var petInteractionManager: PetInteractionManager!
    private var speechBubbleManager: SpeechBubbleManager!
    private var petWindowController: PetWindowController!
    private var panelWindowController: PanelWindowController!
    private var speechBubbleWindowController: SpeechBubbleWindowController!
    private var reminderManager: ReminderManager!
    private var wellnessReminderManager: WellnessReminderManager!
    private var mentorDialogueManager: MentorDialogueManager!
    private var reminderWaitingForTodoOpen = false
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureApplicationIcon()
        configureMainMenu()

        noteStore = NoteStore(storage: storage)
        wellnessReminderStore = WellnessReminderStore(storage: storage)
        todoStore = TodoStore(storage: storage)
        petInteractionManager = PetInteractionManager(settings: settingsStore)

        panelWindowController = PanelWindowController(
            noteStore: noteStore,
            todoStore: todoStore,
            wellnessReminderStore: wellnessReminderStore,
            onVisibilityChanged: { [weak self] visible in
                self?.petInteractionManager.setPanelOpen(visible)
            }
        )

        speechBubbleWindowController = SpeechBubbleWindowController()
        speechBubbleManager = SpeechBubbleManager(
            settings: settingsStore,
            interruptCurrent: { [weak self] in
                self?.speechBubbleWindowController.interrupt()
            }
        ) { [weak self] message, completion in
            self?.presentSpeechBubble(message, completion: completion)
        }

        configureEventHandlers()

        petWindowController = PetWindowController(
            todoStore: todoStore,
            interactionManager: petInteractionManager,
            settingsStore: settingsStore,
            onTogglePanel: { [weak self] in
                self?.togglePanel()
            },
            onDoubleClick: { [weak self] in
                self?.showGreeting()
            },
            onNewNote: { [weak self] in
                self?.createNote()
            },
            onNewTodo: { [weak self] in
                self?.createTodo()
            },
            onShowNotes: { [weak self] in
                self?.showPanel(tab: .notes)
            },
            onHideNotes: { [weak self] in
                self?.hidePanel()
            },
            onPetMoved: { [weak self] petFrame in
                self?.syncAttachedWindows(relativeTo: petFrame)
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        configurePanelAutoHide()

        reminderManager = ReminderManager(todoStore: todoStore) { [weak self] message, dueTodos in
            self?.showReminder(message, dueTodos: dueTodos)
        }
        wellnessReminderManager = WellnessReminderManager(wellnessReminderStore: wellnessReminderStore) { [weak self] message, reminders in
            self?.showWellnessReminder(message, reminders: reminders)
        }
        mentorDialogueManager = MentorDialogueManager(
            themeProvider: { [settingsStore] in
                settingsStore.selectedPetTheme
            },
            onDialogue: { [weak self] phrase in
                self?.showMentorDialogue(phrase)
            }
        )

        petWindowController.show()
        reminderManager.start()
        wellnessReminderManager.start()
        mentorDialogueManager.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        reminderManager?.stop()
        wellnessReminderManager?.stop()
        mentorDialogueManager?.stop()
        removePanelAutoHideMonitors()
    }

    func applicationDidResignActive(_ notification: Notification) {
        hidePanel()
        petWindowController?.bringToFront()
    }

    private func configureEventHandlers() {
        petInteractionManager.onSleep = { [weak self] in
            self?.enqueueNonCriticalDialogue(
                self?.settingsStore.selectedPetTheme.sleepyPhrase ?? PetTheme.newton.sleepyPhrase,
                kind: .sleepy,
                duration: self?.settingsStore.generalBubbleDuration ?? 4
            )
        }

        noteStore.onError = { [weak self] message in
            self?.showSaveError(message)
        }

        todoStore.onError = { [weak self] message in
            self?.showSaveError(message)
        }

        wellnessReminderStore.onError = { [weak self] message in
            self?.showSaveError(message)
        }

        todoStore.onTodoCompleted = { [weak self] _ in
            self?.petInteractionManager.todoCompleted()
            self?.enqueueNonCriticalDialogue(
                self?.settingsStore.selectedPetTheme.completionPhrase ?? PetTheme.newton.completionPhrase,
                kind: .completion,
                duration: self?.settingsStore.generalBubbleDuration ?? 4
            )
        }
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu(title: "NotePal")

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "NotePal")
        appMenu.addItem(
            NSMenuItem(
                title: "退出 NotePal",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(NSMenuItem(title: "撤销", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "删除", action: #selector(NSText.delete(_:)), keyEquivalent: ""))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func configureApplicationIcon() {
        guard
            let url = AppResourceBundle.url(forResource: "NotePalLogo", withExtension: "png"),
            let image = NSImage(contentsOf: url)
        else {
            return
        }

        NSApp.applicationIconImage = image
    }

    private func createNote() {
        petInteractionManager.userActivity()
        _ = noteStore.createNote()
        showPanel(tab: .notes)
    }

    private func createTodo() {
        petInteractionManager.userActivity()
        _ = todoStore.createTodo()
        showPanel(tab: .todos)
    }

    private func togglePanel() {
        if reminderWaitingForTodoOpen {
            reminderWaitingForTodoOpen = false
            showPanel(tab: .todos)
            return
        }

        if panelWindowController.isVisible {
            hidePanel()
        } else {
            showPanel(tab: nil)
        }
    }

    private func showPanel(tab: PanelTab?) {
        petInteractionManager.userActivity()
        if tab == .todos {
            reminderWaitingForTodoOpen = false
            petInteractionManager.reminderAcknowledged()
        }

        panelWindowController.show(
            relativeTo: petWindowController.windowFrame,
            preferredTab: tab
        )
    }

    private func hidePanel() {
        panelWindowController.hide()
    }

    private func configurePanelAutoHide() {
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.hidePanelIfNeeded(for: self?.screenPoint(for: event) ?? NSEvent.mouseLocation)
            return event
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.hidePanelIfNeeded(for: NSEvent.mouseLocation)
            }
        }
    }

    private func removePanelAutoHideMonitors() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }

        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    private func screenPoint(for event: NSEvent) -> NSPoint {
        guard let window = event.window else {
            return NSEvent.mouseLocation
        }

        return window.convertPoint(toScreen: event.locationInWindow)
    }

    private func hidePanelIfNeeded(for screenPoint: NSPoint) {
        guard panelWindowController?.isVisible == true else {
            return
        }

        let protectedFrames = [
            panelWindowController?.window?.frame,
            petWindowController?.window?.frame
        ].compactMap { $0 }

        guard !protectedFrames.contains(where: { $0.contains(screenPoint) }) else {
            return
        }

        hidePanel()
    }

    private func syncAttachedWindows(relativeTo petFrame: NSRect) {
        panelWindowController?.reposition(relativeTo: petFrame)
        speechBubbleWindowController?.reposition(relativeTo: petFrame)
    }

    private func showGreeting() {
        if let phrase = mentorDialogueManager.randomPhrase() {
            showMentorDialogue(phrase)
        }
    }

    private func showMentorDialogue(_ phrase: String) {
        enqueueNonCriticalDialogue(
            phrase,
            kind: .mentor,
            duration: 5
        )
    }

    private func showReminder(_ message: String, dueTodos: [TodoItem]) {
        reminderWaitingForTodoOpen = true
        petInteractionManager.reminderStarted()

        speechBubbleManager.enqueue(
            SpeechBubbleMessage(
                kind: .reminder,
                text: message,
                duration: settingsStore.reminderBubbleDuration,
                isCritical: true,
                onClick: { [weak self] in
                    self?.reminderWaitingForTodoOpen = false
                    self?.petInteractionManager.reminderAcknowledged()
                    self?.showPanel(tab: .todos)
                }
            )
        )
        todoStore.markReminded(dueTodos)
    }

    private func showWellnessReminder(_ message: String, reminders: [WellnessReminder]) {
        speechBubbleManager.enqueue(
            SpeechBubbleMessage(
                kind: .reminder,
                text: message,
                duration: 10,
                isCritical: true,
                onClick: { [weak self] in
                    self?.showPanel(tab: .wellness)
                }
            )
        )
    }

    private func showSaveError(_ message: String) {
        petInteractionManager.saveFailed()
        speechBubbleManager.enqueue(
            SpeechBubbleMessage(
                kind: .error,
                text: message,
                duration: settingsStore.generalBubbleDuration + 2,
                isCritical: true
            )
        )
    }

    private func enqueueNonCriticalDialogue(
        _ text: String,
        kind: SpeechBubbleMessage.Kind,
        duration: TimeInterval
    ) {
        speechBubbleManager.enqueue(
            SpeechBubbleMessage(
                kind: kind,
                text: text,
                duration: duration,
                isCritical: false
            )
        )
    }

    private func presentSpeechBubble(
        _ message: SpeechBubbleMessage,
        completion: @escaping (Bool) -> Void
    ) {
        let didShow = speechBubbleWindowController.show(
            message: message.text,
            duration: message.duration,
            relativeTo: petWindowController.windowFrame,
            parentWindow: petWindowController.window,
            onDismiss: completion
        )

        if !didShow {
            completion(false)
        }
    }
}
