import AppKit
import SwiftUI

@MainActor
final class PetWindowController: NSWindowController {
    private let todoStore: TodoStore
    private let interactionManager: PetInteractionManager
    private let settingsStore: SettingsStore
    private let onTogglePanel: () -> Void
    private let onDoubleClick: () -> Void
    private let onNewNote: () -> Void
    private let onNewTodo: () -> Void
    private let onShowNotes: () -> Void
    private let onHideNotes: () -> Void
    private let onPetMoved: (NSRect) -> Void
    private let onQuit: () -> Void

    var windowFrame: NSRect {
        window?.frame ?? .zero
    }

    init(
        todoStore: TodoStore,
        interactionManager: PetInteractionManager,
        settingsStore: SettingsStore,
        onTogglePanel: @escaping () -> Void,
        onDoubleClick: @escaping () -> Void,
        onNewNote: @escaping () -> Void,
        onNewTodo: @escaping () -> Void,
        onShowNotes: @escaping () -> Void,
        onHideNotes: @escaping () -> Void,
        onPetMoved: @escaping (NSRect) -> Void = { _ in },
        onQuit: @escaping () -> Void
    ) {
        self.todoStore = todoStore
        self.interactionManager = interactionManager
        self.settingsStore = settingsStore
        self.onTogglePanel = onTogglePanel
        self.onDoubleClick = onDoubleClick
        self.onNewNote = onNewNote
        self.onNewTodo = onNewTodo
        self.onShowNotes = onShowNotes
        self.onHideNotes = onHideNotes
        self.onPetMoved = onPetMoved
        self.onQuit = onQuit

        let window = PetWindow(
            contentRect: NSRect(x: 0, y: 0, width: 117, height: 117),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        configure(window)

        let contentView = PetInteractionHostingView(
            rootView: PetView(
                todoStore: todoStore,
                interactionManager: interactionManager,
                settingsStore: settingsStore
            )
        )
        contentView.onClick = { [weak self] in
            self?.interactionManager.clicked()
            self?.onTogglePanel()
        }
        contentView.onDoubleClick = { [weak self] in
            self?.interactionManager.doubleClicked()
            self?.onDoubleClick()
        }
        contentView.onDrag = { [weak self] in
            self?.interactionManager.dragging()
            if let frame = self?.windowFrame {
                self?.onPetMoved(frame)
            }
        }
        contentView.onDragEnded = { [weak self] in
            self?.interactionManager.dragEnded()
            if let frame = self?.windowFrame {
                self?.onPetMoved(frame)
            }
        }
        contentView.onRightClick = { [weak self, weak contentView] point in
            guard let contentView else {
                return
            }

            self?.interactionManager.rightClicked()
            self?.showContextMenu(at: point, in: contentView)
        }

        window.contentView = contentView
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        if let screen = NSScreen.main?.visibleFrame, let window {
            let origin = NSPoint(
                x: screen.maxX - window.frame.width - 64,
                y: screen.minY + 120
            )
            window.setFrameOrigin(origin)
        }

        showWindow(nil)
        window?.orderFrontRegardless()
    }

    func bringToFront() {
        window?.level = .statusBar
        window?.orderFrontRegardless()
    }

    private func configure(_ window: NSPanel) {
        // The pet lives in a transparent, borderless floating panel so only the
        // original pet drawing is visible on the desktop.
        window.title = "NotePal"
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .statusBar
        window.hidesOnDeactivate = false
        window.ignoresMouseEvents = false
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]
    }

    private func showContextMenu(at point: NSPoint, in view: NSView) {
        let menu = NSMenu(title: "NotePal")

        addMenuItem("新建笔记", to: menu, action: #selector(newNote))
        addMenuItem("新建待办", to: menu, action: #selector(newTodo))
        menu.addItem(.separator())
        addMenuItem("显示笔记", to: menu, action: #selector(showNotes))
        addMenuItem("隐藏面板", to: menu, action: #selector(hideNotes))
        menu.addItem(.separator())
        addThemeMenu(to: menu)
        menu.addItem(.separator())
        addMenuItem(
            settingsStore.muteNonCriticalDialogue ? "开启闲聊" : "静音闲聊",
            to: menu,
            action: #selector(toggleMuteChatter)
        )
        addMenuItem(
            settingsStore.animationsEnabled ? "关闭动画" : "开启动画",
            to: menu,
            action: #selector(toggleAnimations)
        )
        menu.addItem(.separator())
        addMenuItem("退出 NotePal", to: menu, action: #selector(quit))

        menu.popUp(positioning: nil, at: point, in: view)
    }

    @discardableResult
    private func addMenuItem(_ title: String, to menu: NSMenu, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    private func addThemeMenu(to menu: NSMenu) {
        let themeMenuItem = NSMenuItem(title: "切换形象", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu(title: "切换形象")

        for theme in PetTheme.allCases where !theme.isSpecial {
            addThemeMenuItem(theme, to: themeMenu)
        }
        let unlockedSpecialThemes = PetTheme.allCases.filter { theme in
            theme.isSpecial && settingsStore.isUnlocked(theme)
        }

        if !unlockedSpecialThemes.isEmpty {
            themeMenu.addItem(.separator())
            addDisabledMenuItem("特殊形象", to: themeMenu)
            for theme in unlockedSpecialThemes {
                addThemeMenuItem(theme, to: themeMenu)
            }
        }

        themeMenu.addItem(.separator())
        addMenuItem("输入特殊形象 key...", to: themeMenu, action: #selector(promptForThemeKey))

        themeMenuItem.submenu = themeMenu
        menu.addItem(themeMenuItem)
    }

    private func addDisabledMenuItem(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func addThemeMenuItem(_ theme: PetTheme, to menu: NSMenu) {
        let item = NSMenuItem(title: theme.displayName, action: #selector(selectPetTheme(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = theme.rawValue
        item.state = settingsStore.selectedPetTheme == theme ? .on : .off
        menu.addItem(item)
    }

    @objc private func newNote() {
        onNewNote()
    }

    @objc private func newTodo() {
        onNewTodo()
    }

    @objc private func showNotes() {
        onShowNotes()
    }

    @objc private func hideNotes() {
        onHideNotes()
    }

    @objc private func toggleMuteChatter() {
        settingsStore.muteNonCriticalDialogue.toggle()
    }

    @objc private func toggleAnimations() {
        settingsStore.animationsEnabled.toggle()
    }

    @objc private func selectPetTheme(_ sender: NSMenuItem) {
        guard
            let themeID = sender.representedObject as? String,
            let theme = PetTheme(storedValue: themeID)
        else {
            return
        }

        if settingsStore.selectTheme(theme) {
            return
        }

        promptForThemeKey()
    }

    @objc private func promptForThemeKey() {
        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        input.placeholderString = "请输入 key"

        let alert = NSAlert()
        alert.messageText = "切换特殊形象"
        alert.informativeText = "请输入特殊形象 key。"
        alert.alertStyle = .informational
        alert.accessoryView = input
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let unlockedTheme: PetTheme?
        do {
            unlockedTheme = try PetAssetLoader.unlockSpecialTheme(with: input.stringValue)
        } catch {
            showUnlockStorageError()
            return
        }

        guard let theme = unlockedTheme else {
            showUnlockError()
            return
        }

        settingsStore.unlock(theme)
        _ = settingsStore.selectTheme(theme)
    }

    private func showUnlockError() {
        let alert = NSAlert()
        alert.messageText = "key 不正确"
        alert.informativeText = "没有找到对应的特殊形象。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    private func showUnlockStorageError() {
        let alert = NSAlert()
        alert.messageText = "无法保存 key"
        alert.informativeText = "特殊形象已验证，但 key 无法写入钥匙串。请检查系统钥匙串权限后重试。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    @objc private func quit() {
        onQuit()
    }
}

private final class PetWindow: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

private final class PetInteractionHostingView: NSHostingView<PetView> {
    var onClick: (() -> Void)?
    var onDoubleClick: (() -> Void)?
    var onRightClick: ((NSPoint) -> Void)?
    var onDrag: (() -> Void)?
    var onDragEnded: (() -> Void)?

    private var mouseDownLocation: NSPoint?
    private var windowStartOrigin: NSPoint?
    private var didDrag = false
    private var pendingSingleClick: DispatchWorkItem?
    private let dragThreshold: CGFloat = 4

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = NSEvent.mouseLocation
        windowStartOrigin = window?.frame.origin
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let mouseDownLocation, let windowStartOrigin else {
            return
        }

        let currentMouseLocation = NSEvent.mouseLocation
        let deltaX = currentMouseLocation.x - mouseDownLocation.x
        let deltaY = currentMouseLocation.y - mouseDownLocation.y

        if abs(deltaX) + abs(deltaY) > dragThreshold {
            didDrag = true
        }

        // Dragging is handled by the hosting view because the pet window is
        // borderless and has no title bar for AppKit to drag automatically.
        let proposedOrigin = NSPoint(
            x: windowStartOrigin.x + deltaX,
            y: windowStartOrigin.y + deltaY
        )
        window.setFrameOrigin(
            Self.constrainedOrigin(
                proposedOrigin,
                windowSize: window.frame.size,
                mouseLocation: currentMouseLocation
            )
        )

        if didDrag {
            onDrag?()
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownLocation = nil
            windowStartOrigin = nil
            didDrag = false
        }

        guard !didDrag else {
            onDragEnded?()
            return
        }

        if event.clickCount >= 2 {
            pendingSingleClick?.cancel()
            pendingSingleClick = nil
            onDoubleClick?()
            return
        }

        let click = DispatchWorkItem { [weak self] in
            self?.onClick?()
            self?.pendingSingleClick = nil
        }
        pendingSingleClick = click
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: click)
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(convert(event.locationInWindow, from: nil))
    }

    private static func constrainedOrigin(
        _ proposedOrigin: NSPoint,
        windowSize: NSSize,
        mouseLocation: NSPoint
    ) -> NSPoint {
        let proposedFrame = NSRect(origin: proposedOrigin, size: windowSize)
        let screen = NSScreen.screens.first { screen in
            screen.visibleFrame.contains(mouseLocation)
        } ?? NSScreen.screens.first { screen in
            screen.visibleFrame.intersects(proposedFrame)
        } ?? NSScreen.main

        guard let visibleFrame = screen?.visibleFrame else {
            return proposedOrigin
        }

        let maxX = max(visibleFrame.minX, visibleFrame.maxX - windowSize.width)
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - windowSize.height)
        return NSPoint(
            x: min(max(proposedOrigin.x, visibleFrame.minX), maxX),
            y: min(max(proposedOrigin.y, visibleFrame.minY), maxY)
        )
    }
}
