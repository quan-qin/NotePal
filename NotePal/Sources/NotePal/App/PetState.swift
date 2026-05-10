import Foundation

enum PetState: String, CaseIterable, Identifiable {
    case idle
    case happy
    case thinking
    case sleeping
    case surprised
    case reminding
    case focused
    case celebrating

    var id: String { rawValue }
}
