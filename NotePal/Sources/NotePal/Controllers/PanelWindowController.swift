import AppKit
import SwiftUI

@MainActor
final class PanelWindowController: NSWindowController {
    private let panelState = PanelState()
    private let onVisibilityChanged: (Bool) -> Void
    private let panelSize = NSSize(
        width: PanelState.defaultPanelSize.width,
        height: PanelState.defaultPanelSize.height
    )
    private let gap: CGFloat = 6
    private var lastPetFrame: NSRect?
    private var resizeStartFrame: NSRect?

    var isVisible: Bool {
        window?.isVisible == true
    }

    init(
        noteStore: NoteStore,
        todoStore: TodoStore,
        wellnessReminderStore: WellnessReminderStore,
        onVisibilityChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.onVisibilityChanged = onVisibilityChanged

        let window = EscHidingPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        configure(window)
        configureResizeHandlers()
        window.onEscape = { [weak self] in
            self?.hide()
        }

        let rootView = NotesPanelView(
            noteStore: noteStore,
            todoStore: todoStore,
            wellnessReminderStore: wellnessReminderStore,
            panelState: panelState
        )

        window.contentView = TransparentPanelHostingView(rootView: rootView)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(relativeTo petFrame: NSRect, preferredTab: PanelTab?) {
        if let preferredTab {
            panelState.selectedTab = preferredTab
        }

        guard let window else {
            return
        }

        lastPetFrame = petFrame
        positionWindow(relativeTo: petFrame)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onVisibilityChanged(true)
    }

    func reposition(relativeTo petFrame: NSRect) {
        guard isVisible else {
            return
        }

        lastPetFrame = petFrame
        positionWindow(relativeTo: petFrame)
    }

    func hide() {
        window?.orderOut(nil)
        onVisibilityChanged(false)
    }

    private func configure(_ window: NSPanel) {
        window.title = "NotePal"
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .statusBar
        window.hidesOnDeactivate = false
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]
    }

    private func configureResizeHandlers() {
        panelState.beginResize = { [weak self] in
            self?.resizeStartFrame = self?.window?.frame
        }

        panelState.resize = { [weak self] translation in
            self?.resizePanel(with: translation)
        }

        panelState.endResize = { [weak self] in
            self?.resizeStartFrame = nil
        }
    }

    private func resizePanel(with translation: CGSize) {
        guard
            let window,
            let startFrame = resizeStartFrame ?? self.window?.frame
        else {
            return
        }

        let screen = NSScreen.screens.first { screen in
            screen.frame.intersects(startFrame)
        }?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 700)

        let widthDelta = panelState.attachmentSide == .left ? translation.width : -translation.width
        let maxWidth = panelState.attachmentSide == .left
            ? screen.maxX - startFrame.minX - 12
            : startFrame.maxX - screen.minX - 12
        let maxHeight = screen.height - 24
        let newWidth = min(max(PanelState.defaultPanelSize.width, startFrame.width + widthDelta), maxWidth)
        let newHeight = min(max(PanelState.defaultPanelSize.height, startFrame.height + translation.height), maxHeight)
        let newX = panelState.attachmentSide == .left ? startFrame.minX : startFrame.maxX - newWidth
        let newY = max(screen.minY + 12, startFrame.maxY - newHeight)
        let newFrame = NSRect(x: newX, y: newY, width: newWidth, height: newHeight)

        panelState.panelSize = newFrame.size
        updateTailCenterY(windowFrame: newFrame)
        window.setFrame(newFrame, display: true)
    }

    private func positionWindow(relativeTo petFrame: NSRect) {
        guard let window else {
            return
        }

        let layout = layout(relativeTo: petFrame, windowSize: window.frame.size)
        panelState.attachmentSide = layout.side
        panelState.tailCenterY = layout.tailCenterY
        window.setFrameOrigin(layout.origin)
    }

    private func updateTailCenterY(windowFrame: NSRect) {
        guard let lastPetFrame else {
            return
        }

        panelState.tailCenterY = min(
            max(lastPetFrame.midY - windowFrame.minY, 54),
            windowFrame.height - 54
        )
    }

    private func layout(
        relativeTo petFrame: NSRect,
        windowSize: NSSize
    ) -> (origin: NSPoint, side: PanelAttachmentSide, tailCenterY: CGFloat) {
        let screen = NSScreen.screens.first { screen in
            screen.frame.intersects(petFrame)
        }?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 700)

        let placeOnRight = petFrame.maxX + gap + windowSize.width <= screen.maxX
        let side: PanelAttachmentSide = placeOnRight ? .left : .right
        let x = placeOnRight
            ? petFrame.maxX + gap
            : petFrame.minX - windowSize.width - gap

        var y = petFrame.midY - (windowSize.height / 2)
        y = min(max(y, screen.minY + 12), screen.maxY - windowSize.height - 12)
        let tailCenterY = min(max(petFrame.midY - y, 54), windowSize.height - 54)

        return (NSPoint(x: x, y: y), side, tailCenterY)
    }
}

private final class EscHidingPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
}

private final class TransparentPanelHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool {
        false
    }

    required init(rootView: Content) {
        super.init(rootView: rootView)
        configureTransparency()
    }

    @MainActor required dynamic init?(coder: NSCoder) {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureTransparency()
        window?.backgroundColor = .clear
        window?.isOpaque = false
    }

    private func configureTransparency() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
        layer?.masksToBounds = false
    }
}
