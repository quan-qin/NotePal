import SwiftUI

enum PanelTab: String, CaseIterable, Identifiable {
    case notes = "笔记"
    case todos = "待办"
    case wellness = "养生"

    var id: String {
        rawValue
    }
}

enum PanelAttachmentSide {
    case left
    case right
}

@MainActor
final class PanelState: ObservableObject {
    static let defaultPanelSize = CGSize(width: 414, height: 520)

    @Published var selectedTab: PanelTab = .wellness
    @Published var attachmentSide: PanelAttachmentSide = .left
    @Published var tailCenterY: CGFloat = 92
    @Published var panelSize: CGSize = defaultPanelSize

    var beginResize: (() -> Void)?
    var resize: ((CGSize) -> Void)?
    var endResize: (() -> Void)?
}
