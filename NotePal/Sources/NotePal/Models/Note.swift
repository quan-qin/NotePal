import Foundation

enum NoteRecordMode: String, CaseIterable, Identifiable, Codable {
    case text
    case drawing

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .text:
            return "文本记录"
        case .drawing:
            return "随笔画记"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case Self.text.rawValue, "文本记录":
            self = .text
        case Self.drawing.rawValue, "随笔画记":
            self = .drawing
        default:
            self = .text
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct Note: Identifiable, Codable, Equatable {
    var id: UUID
    var recordMode: NoteRecordMode
    var title: String
    var body: String
    var images: [NoteImage]
    var drawingStrokes: [NoteDrawingStroke]
    var createdAt: Date
    var updatedAt: Date
    var wasDecodedWithoutRecordMode: Bool

    init(
        id: UUID = UUID(),
        recordMode: NoteRecordMode = .text,
        title: String = "未命名笔记",
        body: String = "",
        images: [NoteImage] = [],
        drawingStrokes: [NoteDrawingStroke] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.recordMode = recordMode
        self.title = title
        self.body = body
        self.images = images
        self.drawingStrokes = drawingStrokes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.wasDecodedWithoutRecordMode = false
    }

    enum CodingKeys: String, CodingKey {
        case id
        case recordMode
        case title
        case body
        case images
        case drawingStrokes
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "未命名笔记"
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        images = try container.decodeIfPresent([NoteImage].self, forKey: .images) ?? []
        drawingStrokes = try container.decodeIfPresent([NoteDrawingStroke].self, forKey: .drawingStrokes) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        if let decodedRecordMode = try container.decodeIfPresent(NoteRecordMode.self, forKey: .recordMode) {
            recordMode = decodedRecordMode
            wasDecodedWithoutRecordMode = false
        } else {
            recordMode = Note.inferredRecordMode(body: body, images: images, drawingStrokes: drawingStrokes)
            wasDecodedWithoutRecordMode = true
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(recordMode, forKey: .recordMode)
        try container.encode(title, forKey: .title)
        try container.encode(body, forKey: .body)
        try container.encode(images, forKey: .images)
        try container.encode(drawingStrokes, forKey: .drawingStrokes)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    var hasTextRecordContent: Bool {
        !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty
    }

    var hasDrawingRecordContent: Bool {
        !drawingStrokes.isEmpty
    }

    var recordIdentity: String {
        "\(recordMode.rawValue)-\(id.uuidString)"
    }

    private static func inferredRecordMode(
        body: String,
        images: [NoteImage],
        drawingStrokes: [NoteDrawingStroke]
    ) -> NoteRecordMode {
        let hasText = !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !images.isEmpty
        let hasDrawing = !drawingStrokes.isEmpty

        if hasDrawing && !hasText {
            return .drawing
        }

        return .text
    }
}

struct NoteImage: Identifiable, Codable, Equatable {
    var id: UUID
    var pngData: Data

    init(id: UUID = UUID(), pngData: Data) {
        self.id = id
        self.pngData = pngData
    }
}

struct NoteDrawingStroke: Identifiable, Codable, Equatable {
    var id: UUID
    var points: [NoteDrawingPoint]
    var lineWidth: Double

    init(
        id: UUID = UUID(),
        points: [NoteDrawingPoint] = [],
        lineWidth: Double = 2.8
    ) {
        self.id = id
        self.points = points
        self.lineWidth = lineWidth
    }
}

struct NoteDrawingPoint: Codable, Equatable {
    var x: Double
    var y: Double

    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}
