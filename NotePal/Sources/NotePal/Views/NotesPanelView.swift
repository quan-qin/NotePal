import AppKit
import SwiftUI

struct NotesPanelView: View {
    @ObservedObject var noteStore: NoteStore
    @ObservedObject var todoStore: TodoStore
    @ObservedObject var wellnessReminderStore: WellnessReminderStore
    @ObservedObject var panelState: PanelState

    @State private var noteRecordMode: NoteRecordMode = .text
    @State private var isResizing = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            panelContent
                .offset(x: panelState.attachmentSide == .left ? 18 : 0)

            PanelPopoverTail(side: panelState.attachmentSide)
                .fill(panelFill)
                .overlay(
                    PanelPopoverTail(side: panelState.attachmentSide)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.7)
                )
                .frame(width: 18, height: 30)
                .position(
                    x: panelState.attachmentSide == .left ? 9 : panelContentWidth + 9,
                    y: panelState.tailCenterY
                )

            resizeHandle
        }
        .frame(width: panelState.panelSize.width, height: panelState.panelSize.height)
        .background(Color.clear)
    }

    private var panelContent: some View {
        VStack(spacing: 12) {
            header

            Picker("", selection: $panelState.selectedTab) {
                ForEach(PanelTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            errorText

            Group {
                switch panelState.selectedTab {
                case .notes:
                    notesList
                case .todos:
                    TodoListView(
                        todoStore: todoStore
                    )
                case .wellness:
                    wellnessSettings
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if panelState.selectedTab == .notes {
                Picker("", selection: $noteRecordMode) {
                    ForEach(NoteRecordMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .help("切换文本记录和随笔画记")
            }
        }
        .padding(14)
        .frame(width: panelContentWidth, height: panelState.panelSize.height)
        .background(panelBackground)
    }

    private var panelContentWidth: CGFloat {
        max(PanelState.defaultPanelSize.width - 24, panelState.panelSize.width - 24)
    }

    private var resizeHandle: some View {
        Image(systemName: resizeHandleIconName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.86))
                    .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
            )
            .position(
                x: panelState.attachmentSide == .left ? panelState.panelSize.width - 18 : 18,
                y: panelState.panelSize.height - 18
            )
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if !isResizing {
                            isResizing = true
                            panelState.beginResize?()
                        }
                        panelState.resize?(value.translation)
                    }
                    .onEnded { _ in
                        isResizing = false
                        panelState.endResize?()
                    }
            )
            .help("拖拽调整面板大小")
    }

    private var resizeHandleIconName: String {
        panelState.attachmentSide == .left
            ? "arrow.down.right.and.arrow.up.left"
            : "arrow.down.left.and.arrow.up.right"
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("NotePal")
                    .font(.system(size: 17, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if panelState.selectedTab != .wellness {
                Button(action: addCurrentItem) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .background(Circle().fill(Color.accentColor.opacity(0.14)))
                .help(panelState.selectedTab == .notes ? "新建笔记" : "新建待办")
            }
        }
    }

    private var subtitle: String {
        switch panelState.selectedTab {
        case .notes:
            return "快速笔记"
        case .todos:
            return "待办事项"
        case .wellness:
            return "养生提醒"
        }
    }

    @ViewBuilder
    private var errorText: some View {
        if let error = noteStore.lastError ?? todoStore.lastError ?? wellnessReminderStore.lastError {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var notesList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if visibleNotes.isEmpty {
                    emptyState(noteRecordMode.emptyStateText)
                } else {
                    ForEach(visibleNotes, id: \.recordIdentity) { note in
                        NoteCard(
                            note: note,
                            noteStore: noteStore
                        )
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var visibleNotes: [Note] {
        noteStore.notes(for: noteRecordMode)
    }

    private var wellnessSettings: some View {
        ScrollView {
            WellnessReminderSection(wellnessReminderStore: wellnessReminderStore)
                .padding(.vertical, 2)
        }
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 250)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(panelFill)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.7)
            )
            .shadow(color: .black.opacity(0.16), radius: 22, y: 10)
    }

    private var panelFill: Color {
        Color(nsColor: .windowBackgroundColor).opacity(0.96)
    }

    private func addCurrentItem() {
        switch panelState.selectedTab {
        case .notes:
            _ = noteStore.createNote(recordMode: noteRecordMode)
        case .todos:
            _ = todoStore.createTodo()
        case .wellness:
            break
        }
    }
}

private struct PanelPopoverTail: Shape {
    let side: PanelAttachmentSide

    func path(in rect: CGRect) -> Path {
        var path = Path()

        switch side {
        case .left:
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.midY),
                control: CGPoint(x: rect.midX, y: rect.midY - 2)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY),
                control: CGPoint(x: rect.midX, y: rect.midY + 2)
            )
        case .right:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.midY),
                control: CGPoint(x: rect.midX, y: rect.midY - 2)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY),
                control: CGPoint(x: rect.midX, y: rect.midY + 2)
            )
        }

        path.closeSubpath()
        return path
    }
}

private extension NoteRecordMode {
    var emptyStateText: String {
        switch self {
        case .text:
            return "还没有文本记录。"
        case .drawing:
            return "还没有随笔画记。"
        }
    }
}

private struct NoteCard: View {
    let note: Note
    @ObservedObject var noteStore: NoteStore

    @State private var title: String
    @State private var bodyText: String
    @State private var images: [NoteImage]
    @State private var drawingStrokes: [NoteDrawingStroke]

    init(note: Note, noteStore: NoteStore) {
        self.note = note
        self.noteStore = noteStore
        _title = State(initialValue: note.title)
        _bodyText = State(initialValue: note.body)
        _images = State(initialValue: note.images)
        _drawingStrokes = State(initialValue: note.drawingStrokes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                TextField("标题", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .semibold))

                Button {
                    noteStore.deleteNote(id: note.id, recordMode: note.recordMode)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("删除笔记")
            }

            switch note.recordMode {
            case .text:
                textRecordBody
            case .drawing:
                drawingRecordBody
            }

            HStack {
                Text("创建于 \(DateFormatter.notePalShortDateTime.string(from: note.createdAt))")
                Spacer()
                Text("更新于 \(DateFormatter.notePalShortDateTime.string(from: note.updatedAt))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(cardBackground)
        .onChange(of: title) { _ in
            save()
        }
        .onChange(of: bodyText) { _ in
            save()
        }
    }

    private var textRecordBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            PasteImageTextEditor(
                text: $bodyText,
                onPasteImages: appendImages
            )
            .frame(minHeight: 84)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )

            if images.isEmpty {
                Text("可在文本区粘贴图片。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                NoteImageGrid(
                    images: images,
                    onCopy: copyImageToPasteboard,
                    onDelete: deleteImage
                )
            }
        }
    }

    private var drawingRecordBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            DrawingCanvasView(strokes: $drawingStrokes) {
                save()
            }
            .frame(minHeight: 230)

            HStack {
                Text("按住拖拽即可画记。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    drawingStrokes.removeAll()
                    save()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("清空画记")
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }

    private func save() {
        var updated = note
        updated.title = title
        switch note.recordMode {
        case .text:
            updated.body = bodyText
            updated.images = images
            updated.drawingStrokes = []
        case .drawing:
            updated.body = ""
            updated.images = []
            updated.drawingStrokes = drawingStrokes
        }
        noteStore.updateNote(updated)
    }

    private func appendImages(_ pastedImages: [NoteImage]) {
        guard !pastedImages.isEmpty else {
            return
        }

        images.append(contentsOf: pastedImages)
        save()
    }

    private func deleteImage(_ image: NoteImage) {
        images.removeAll { $0.id == image.id }
        save()
    }

    private func copyImageToPasteboard(_ image: NoteImage) {
        guard let nsImage = NSImage(data: image.pngData) else {
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([nsImage])
    }
}

private struct PasteImageTextEditor: NSViewRepresentable {
    @Binding var text: String
    let onPasteImages: ([NoteImage]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onPasteImages: onPasteImages)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = PasteAwareTextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 13)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 7, height: 7)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.onPasteImages = context.coordinator.pasteImages

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onPasteImages = onPasteImages

        guard let textView = scrollView.documentView as? PasteAwareTextView else {
            return
        }

        textView.onPasteImages = context.coordinator.pasteImages
        if textView.string != text {
            textView.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        var onPasteImages: ([NoteImage]) -> Void
        weak var textView: NSTextView?

        init(text: Binding<String>, onPasteImages: @escaping ([NoteImage]) -> Void) {
            self.text = text
            self.onPasteImages = onPasteImages
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            text.wrappedValue = textView.string
        }

        func pasteImages(_ images: [NSImage]) {
            let noteImages = images.compactMap { image -> NoteImage? in
                guard let pngData = image.pngDataForNotePal() else {
                    return nil
                }

                return NoteImage(pngData: pngData)
            }

            onPasteImages(noteImages)
        }
    }
}

private final class PasteAwareTextView: NSTextView {
    var onPasteImages: (([NSImage]) -> Void)?

    override func paste(_ sender: Any?) {
        let images = NSPasteboard.general.notePalImages()
        if !images.isEmpty {
            onPasteImages?(images)
            return
        }

        super.paste(sender)
    }
}

private struct NoteImageGrid: View {
    let images: [NoteImage]
    let onCopy: (NoteImage) -> Void
    let onDelete: (NoteImage) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 92), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(images) { image in
                if let nsImage = NSImage(data: image.pngData) {
                    VStack(spacing: 6) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(height: 86)
                            .frame(maxWidth: .infinity)
                            .background(Color.black.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                        HStack(spacing: 8) {
                            Button {
                                onCopy(image)
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.plain)
                            .help("复制图片")

                            Button {
                                onDelete(image)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .help("删除图片")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    }
                    .padding(7)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.68))
                    )
                }
            }
        }
    }
}

private struct DrawingCanvasView: View {
    @Binding var strokes: [NoteDrawingStroke]
    let onCommit: () -> Void

    @State private var currentStroke: NoteDrawingStroke?

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for stroke in strokes {
                    draw(stroke, in: &context, size: size)
                }

                if let currentStroke {
                    draw(currentStroke, in: &context, size: size)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        appendPoint(value.location, in: geometry.size)
                    }
                    .onEnded { _ in
                        commitStroke()
                    }
            )
        }
    }

    private func draw(
        _ stroke: NoteDrawingStroke,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        guard let first = stroke.points.first else {
            return
        }

        var path = Path()
        path.move(to: point(first, in: size))

        for drawingPoint in stroke.points.dropFirst() {
            path.addLine(to: point(drawingPoint, in: size))
        }

        context.stroke(
            path,
            with: .color(.primary.opacity(0.86)),
            style: StrokeStyle(lineWidth: CGFloat(stroke.lineWidth), lineCap: .round, lineJoin: .round)
        )
    }

    private func appendPoint(_ location: CGPoint, in size: CGSize) {
        let clampedX = min(max(location.x / max(size.width, 1), 0), 1)
        let clampedY = min(max(location.y / max(size.height, 1), 0), 1)
        let point = NoteDrawingPoint(x: clampedX, y: clampedY)

        if currentStroke == nil {
            currentStroke = NoteDrawingStroke(points: [point])
        } else {
            currentStroke?.points.append(point)
        }
    }

    private func commitStroke() {
        guard let currentStroke, currentStroke.points.count > 1 else {
            self.currentStroke = nil
            return
        }

        strokes.append(currentStroke)
        self.currentStroke = nil
        onCommit()
    }

    private func point(_ drawingPoint: NoteDrawingPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: drawingPoint.x * size.width,
            y: drawingPoint.y * size.height
        )
    }
}

private extension NSPasteboard {
    func notePalImages() -> [NSImage] {
        var images: [NSImage] = []

        if let directImage = NSImage(pasteboard: self) {
            images.append(directImage)
        }

        if let fileURLs = readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in fileURLs {
                guard
                    let image = NSImage(contentsOf: url),
                    image.isValid
                else {
                    continue
                }

                images.append(image)
            }
        }

        var seenRepresentations = Set<String>()
        return images.filter { image in
            let key = "\(Int(image.size.width))x\(Int(image.size.height))-\(image.representations.count)"
            guard !seenRepresentations.contains(key) else {
                return false
            }

            seenRepresentations.insert(key)
            return true
        }
    }
}

private extension NSImage {
    func pngDataForNotePal() -> Data? {
        guard
            let tiffData = tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }
}
