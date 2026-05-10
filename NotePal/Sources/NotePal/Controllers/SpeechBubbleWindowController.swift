import AppKit
import SwiftUI

@MainActor
final class SpeechBubbleWindowController: NSWindowController {
    private var dismissTimer: Timer?
    private var finishHandler: ((Bool) -> Void)?
    private var bubbleOffsetFromPetOrigin: NSPoint?
    private weak var attachedParentWindow: NSWindow?
    private let textFont = NSFont.systemFont(ofSize: 11.8, weight: .medium)
    private let headAnchorXRatio: CGFloat = 0.55
    private let headTopYRatio: CGFloat = 0.91
    private let headBubbleGap: CGFloat = 8

    init() {
        let window = SpeechBubblePanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 72),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        configure(window)
    }

    required init?(coder: NSCoder) {
        nil
    }

    @discardableResult
    func show(
        message: String,
        duration: TimeInterval,
        relativeTo petFrame: NSRect,
        parentWindow: NSWindow?,
        onDismiss: @escaping (Bool) -> Void
    ) -> Bool {
        guard let window else {
            return false
        }

        dismissTimer?.invalidate()
        finishHandler?(false)
        finishHandler = onDismiss
        detachFromParent()

        let size = bubbleSize(for: message)
        window.setContentSize(size)

        let contentView = SpeechBubbleHostingView(rootView: SpeechBubbleView(message: message))
        contentView.onClick = { [weak self] in
            self?.finish(clicked: true)
        }
        window.contentView = contentView

        let origin = position(relativeTo: petFrame, windowSize: size)
        bubbleOffsetFromPetOrigin = NSPoint(
            x: origin.x - petFrame.origin.x,
            y: origin.y - petFrame.origin.y
        )
        window.setFrameOrigin(origin)
        window.level = .statusBar

        if let parentWindow {
            parentWindow.addChildWindow(window, ordered: .above)
            attachedParentWindow = parentWindow
        }

        window.orderFrontRegardless()
        window.displayIfNeeded()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak window] in
            window?.level = .statusBar
            window?.orderFrontRegardless()
        }

        if duration > 0 {
            let timer = Timer(timeInterval: duration, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.finish(clicked: false)
                }
            }
            timer.tolerance = min(1, duration * 0.15)
            RunLoop.main.add(timer, forMode: .common)
            dismissTimer = timer
        }

        return true
    }

    func hide() {
        bubbleOffsetFromPetOrigin = nil
        detachFromParent()
        window?.orderOut(nil)
    }

    func interrupt() {
        finish(clicked: false)
    }

    func reposition(relativeTo petFrame: NSRect) {
        guard let window, window.isVisible else {
            return
        }

        guard attachedParentWindow == nil else {
            return
        }

        if let bubbleOffsetFromPetOrigin {
            window.setFrameOrigin(
                NSPoint(
                    x: petFrame.origin.x + bubbleOffsetFromPetOrigin.x,
                    y: petFrame.origin.y + bubbleOffsetFromPetOrigin.y
                )
            )
        } else {
            window.setFrameOrigin(position(relativeTo: petFrame, windowSize: window.frame.size))
        }
    }

    private func finish(clicked: Bool) {
        dismissTimer?.invalidate()
        dismissTimer = nil
        let handler = finishHandler
        finishHandler = nil
        bubbleOffsetFromPetOrigin = nil
        detachFromParent()
        window?.orderOut(nil)
        handler?(clicked)
    }

    private func configure(_ window: NSPanel) {
        window.title = "NotePal 提醒"
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

    private func detachFromParent() {
        guard let window, let attachedParentWindow else {
            self.attachedParentWindow = nil
            return
        }

        attachedParentWindow.removeChildWindow(window)
        self.attachedParentWindow = nil
    }

    private func position(relativeTo petFrame: NSRect, windowSize: NSSize) -> NSPoint {
        let screen = NSScreen.screens.first { screen in
            screen.frame.intersects(petFrame)
        }?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 700)

        let headAnchorX = petFrame.minX + petFrame.width * headAnchorXRatio
        var x = headAnchorX - (windowSize.width / 2)
        x = min(max(x, screen.minX + 12), screen.maxX - windowSize.width - 12)

        let headTopY = petFrame.minY + petFrame.height * headTopYRatio
        let y = headTopY + headBubbleGap

        return NSPoint(x: x, y: y)
    }

    private func bubbleSize(for message: String) -> NSSize {
        let horizontalPadding: CGFloat = 26
        let verticalPadding: CGFloat = 20
        let tailHeight: CGFloat = 11
        let minWidth: CGFloat = 220
        let maxWidth: CGFloat = 320

        let estimatedWidth = min(max(CGFloat(message.count) * 7 + 48, minWidth), maxWidth)
        let textWidth = estimatedWidth - horizontalPadding
        let boundingRect = (message as NSString).boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: textFont]
        )
        let height = max(ceil(boundingRect.height) + verticalPadding + tailHeight, 58)

        return NSSize(width: estimatedWidth, height: height)
    }
}

private final class SpeechBubblePanel: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

private final class SpeechBubbleHostingView: NSHostingView<SpeechBubbleView> {
    var onClick: (() -> Void)?

    override var isOpaque: Bool {
        false
    }

    required init(rootView: SpeechBubbleView) {
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

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    private func configureTransparency() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
        layer?.masksToBounds = false
    }
}
