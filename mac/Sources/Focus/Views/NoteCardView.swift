import FocusKit
import SwiftUI

struct NoteCardView: View {
    /// Gestures are measured in the board's coordinate space rather than the
    /// card's own. A card moves while it is being dragged, so measuring against
    /// itself means every event is measured from a space that has just moved —
    /// the reading feeds back into the thing being read, and the note shakes.
    static let boardSpace = "focus.board"

    @ObservedObject var store: NotesStore
    let note: Note
    let bounds: CGSize

    // The gesture is held here and drawn as an offset. The store hears about it
    // once, on release: publishing every pointer event would rebuild every card
    // on the board, each with a live text view inside it.
    @State private var drag: CGSize = .zero
    @State private var resize: CGSize = .zero
    @State private var isDragging = false
    @State private var hovering = false

    /// Collapsed height on an organised board: the top bar plus the first line.
    private let peek: Double = 62
    /// The width of the close button, which the drag strip must not cover.
    private let closeButtonWidth: Double = 26

    private var isCollapsed: Bool { store.isStacked && !hovering }

    var body: some View {
        // The content is a separate, equatable view: while a drag is in flight
        // none of its inputs change, so SwiftUI skips rebuilding it and only the
        // offset below is recomputed.
        NoteCardContent(
            store: store,
            note: note,
            width: liveWidth,
            height: isCollapsed ? peek : liveHeight,
            isCollapsed: isCollapsed
        )
        .equatable()
        .offset(x: clampedDrag.width, y: clampedDrag.height)
        .shadow(color: .black.opacity(isCollapsed ? 0.25 : 0.35), radius: isDragging ? 14 : 7, y: 5)
        .overlay(alignment: .topLeading) { dragStrip }
        .overlay(alignment: .bottomTrailing) { if !isCollapsed { handle } }
        .position(x: note.x + liveWidth / 2, y: note.y + (isCollapsed ? peek : liveHeight) / 2)
        .zIndex(Double(isDragging || (hovering && store.isStacked) ? 10_000 : note.z))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.18), value: isCollapsed)
    }

    /// The grip: the top bar, minus the corner the close button sits in.
    private var dragStrip: some View {
        Color.clear
            .frame(width: max(0, liveWidth - closeButtonWidth), height: 22)
            .contentShape(Rectangle())
            .offset(x: clampedDrag.width, y: clampedDrag.height)
            .gesture(dragGesture)
    }

    private var handle: some View {
        Image(systemName: "arrow.down.right")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.black.opacity(0.4))
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
            .offset(x: clampedDrag.width, y: clampedDrag.height)
            .gesture(resizeGesture)
            .help("Drag to resize")
    }

    // MARK: - Live geometry

    /// The drag so far, clamped so a note can never be taken off the board and
    /// lost. It is clamped here rather than on release, so where the card is
    /// drawn is always where it will land.
    private var clampedDrag: CGSize {
        CGSize(
            width: clamp(note.x + drag.width, max: bounds.width - liveWidth) - note.x,
            height: clamp(note.y + drag.height, max: bounds.height - liveHeight) - note.y
        )
    }

    private var liveWidth: Double {
        clamp(note.width + resize.width, min: Note.minimumSize.width, max: bounds.width - note.x)
    }

    private var liveHeight: Double {
        clamp(note.height + resize.height, min: Note.minimumSize.height, max: bounds.height - note.y)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.boardSpace))
            .onChanged { value in
                isDragging = true
                drag = value.translation
            }
            .onEnded { _ in
                var updated = note
                updated.x = note.x + clampedDrag.width
                updated.y = note.y + clampedDrag.height
                drag = .zero
                isDragging = false
                // Lifting and saving both publish, so they wait until the note
                // has been put down.
                store.lift(note)
                store.update(updated, writeText: false)
            }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.boardSpace))
            .onChanged { value in
                isDragging = true
                resize = value.translation
            }
            .onEnded { _ in
                var updated = note
                updated.width = liveWidth
                updated.height = liveHeight
                resize = .zero
                isDragging = false
                store.lift(note)
                store.update(updated, writeText: false)
            }
    }

    private func clamp(_ value: Double, min lower: Double = 0, max upper: Double) -> Double {
        Swift.max(lower, Swift.min(Swift.max(lower, upper), value))
    }
}

/// The card itself: paper, text and controls. It knows nothing about dragging,
/// which is what lets SwiftUI leave it alone while a drag is in flight.
private struct NoteCardContent: View, Equatable {
    @ObservedObject var store: NotesStore
    let note: Note
    let width: Double
    let height: Double
    let isCollapsed: Bool

    /// Deliberately ignores the store, which publishes its own changes.
    static func == (lhs: NoteCardContent, rhs: NoteCardContent) -> Bool {
        lhs.note == rhs.note
            && lhs.width == rhs.width
            && lhs.height == rhs.height
            && lhs.isCollapsed == rhs.isCollapsed
    }

    private var paper: Color {
        let rgb = NoteColor.named(note.color).rgb
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    var body: some View {
        VStack(spacing: 0) {
            grip
            if !isCollapsed { editor }
            footer
        }
        .frame(width: width, height: height, alignment: .top)
        .background(paper)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var grip: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.black.opacity(0.35))

            Text(shortStamp)
                .font(.system(size: 9))
                .foregroundStyle(.black.opacity(0.5))
                .help("Created \(NoteDocument.longStamp(for: note.createdAt))")

            Spacer(minLength: 0)

            if isCollapsed {
                Text(note.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.black.opacity(0.65))
                    .lineLimit(1)
                    .frame(maxWidth: width * 0.55, alignment: .trailing)
            }

            Button {
                store.trash(note)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.black.opacity(0.45))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Move this note to the Trash")
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .frame(height: 22)
        .background(.black.opacity(0.06))
    }

    private var editor: some View {
        TextEditor(text: Binding(
            get: { note.text },
            set: { text in
                var updated = note
                updated.text = text
                store.update(updated, writeText: true)
            }
        ))
        .font(.system(size: 13))
        .foregroundStyle(Color(red: 0.17, green: 0.16, blue: 0.13))
        .scrollContentBackground(.hidden)
        .background(.clear)
        .padding(.horizontal, 6)
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        Group {
            if isCollapsed {
                Text(firstBodyLine)
                    .font(.system(size: 11))
                    .foregroundStyle(.black.opacity(0.6))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            } else {
                HStack(spacing: 5) {
                    ForEach(NoteColor.all) { color in
                        Button {
                            var updated = note
                            updated.color = color.key
                            store.update(updated, writeText: false)
                        } label: {
                            Circle()
                                .fill(Color(red: color.rgb.red, green: color.rgb.green, blue: color.rgb.blue))
                                .frame(width: 13, height: 13)
                                .overlay(
                                    Circle().stroke(
                                        .black.opacity(color.key == note.color ? 0.65 : 0.2),
                                        lineWidth: color.key == note.color ? 2 : 1
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .help(color.label)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .padding(.trailing, 14)
            }
        }
    }

    private var shortStamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = Calendar.current.isDate(note.createdAt, equalTo: Date(), toGranularity: .year)
            ? "d MMM, HH:mm"
            : "d MMM yyyy, HH:mm"
        return formatter.string(from: note.createdAt)
    }

    private var firstBodyLine: String {
        let lines = note.text.components(separatedBy: "\n").dropFirst()
        return lines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
    }
}
