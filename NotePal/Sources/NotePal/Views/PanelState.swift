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
    @Published var selectedTab: PanelTab = .wellness
    @Published var attachmentSide: PanelAttachmentSide = .left
    @Published var tailCenterY: CGFloat = 92
}
