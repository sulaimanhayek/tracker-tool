import Foundation

public struct NoteColor: Identifiable, Equatable, Sendable {
    public let key: String
    public let label: String
    public let rgb: (red: Double, green: Double, blue: Double)

    public var id: String { key }

    public static func == (lhs: NoteColor, rhs: NoteColor) -> Bool { lhs.key == rhs.key }

    public static let all: [NoteColor] = [
        NoteColor(key: "amber", label: "Amber", rgb: (1.00, 0.83, 0.37)),
        NoteColor(key: "pink", label: "Pink", rgb: (1.00, 0.62, 0.77)),
        NoteColor(key: "mint", label: "Mint", rgb: (0.56, 0.89, 0.75)),
        NoteColor(key: "sky", label: "Sky", rgb: (0.56, 0.80, 1.00)),
        NoteColor(key: "lilac", label: "Lilac", rgb: (0.76, 0.65, 1.00)),
        NoteColor(key: "lime", label: "Lime", rgb: (0.85, 0.91, 0.42))
    ]

    public static func named(_ key: String) -> NoteColor {
        all.first { $0.key == key } ?? all[0]
    }
}

/// A sticky note. Its text lives in its own Word document on disk; everything here
/// but `text` is board furniture, kept in board.json beside it.
public struct Note: Identifiable, Equatable {
    public static let defaultSize = CGSize(width: 240, height: 240)
    public static let minimumSize = CGSize(width: 160, height: 150)

    /// The note's filename, which is also its identity on disk.
    public let id: String
    public let createdAt: Date
    public var text: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var color: String
    public var z: Int

    public var size: CGSize { CGSize(width: width, height: height) }

    public var title: String {
        let first = text.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let trimmed = first.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Untitled note" : trimmed
    }

    public init(
        id: String,
        createdAt: Date,
        text: String = "",
        x: Double = 24,
        y: Double = 24,
        width: Double = Note.defaultSize.width,
        height: Double = Note.defaultSize.height,
        color: String = "amber",
        z: Int = 1
    ) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.color = color
        self.z = z
    }
}

/// What board.json holds: where a note sits, not what it says.
struct NoteLayout: Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var color: String
    var z: Int
}
