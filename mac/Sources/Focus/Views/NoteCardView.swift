import FocusKit
import SwiftUI

struct NoteCardView: View {
    @ObservedObject var store: NotesStore
    let note: Note
    let bounds: CGSize

    // A drag is held here rather than in the store: publishing every pointer
    // event would rebuild every card on the board — each with a live text view
    // inside it — which is what made dragging judder. The store hears about it
    // once, when the note is dropped.
    @State private var drag: CGSize = .zero
    @State private var resize: CGSize = .zero
    @State private var isDragging = false
    @State private var hovering = false

    /// Collapsed height on an organised board: the top bar plus the first line.
    private let peek: Double = 62

    private var isCollapsed: Bool { store.isStacked && !hovering }
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
        .frame(width: liveWidth, height: isCollapsed ? peek : liveHeight, alignment: .top)
        .background(paper)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(isCollapsed ? 0.25 : 0.35), radius: hovering ? 12 : 7, y: 5)
        .overlay(alignment: .bottomTrailing) { if !isCollapsed { handle } }
        .position(x: liveX + liveWidth / 2, y: liveY + (isCollapsed ? peek : liveHeight) / 2)
        .zIndex(Double(isDragging || (hovering && store.isStacked) ? 10_000 : note.z))
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.18), value: isCollapsed)
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
                    .frame(maxWidth: liveWidth * 0.55, alignment: .trailing)
            }

            Button {
                store.trash(note)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.black.opacity(0.45))
            }
            .buttonStyle(.plain)
            .help("Move this note to the Trash")
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(.black.opacity(0.06))
        .contentShape(Rectangle())
        .gesture(dragGesture)
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

    private var handle: some View {
        Image(systemName: "arrow.down.right")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.black.opacity(0.4))
            .frame(width: 16, height: 16)
            .contentShape(Rectangle())
            .gesture(resizeGesture)
            .help("Drag to resize")
    }

    // MARK: - Live geometry

    // What is drawn while a gesture is in flight: the note's saved geometry plus
    // the gesture so far, clamped the same way the committed value will be, so
    // the card never jumps when it is dropped.
    private var liveX: Double { clamp(note.x + drag.width, max: bounds.width - liveWidth) }
    private var liveY: Double { clamp(note.y + drag.height, max: bounds.height - liveHeight) }

    private var liveWidth: Double {
        clamp(note.width + resize.width, min: Note.minimumSize.width, max: bounds.width - note.x)
    }

    private var liveHeight: Double {
        clamp(note.height + resize.height, min: Note.minimumSize.height, max: bounds.height - note.y)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    store.lift(note)
                }
                drag = value.translation
            }
            .onEnded { _ in
                var updated = note
                // Clamped so a note can never be dragged off the board and lost.
                updated.x = liveX
                updated.y = liveY
                store.update(updated, writeText: false)
                drag = .zero
                isDragging = false
            }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    store.lift(note)
                }
                resize = value.translation
            }
            .onEnded { _ in
                var updated = note
                updated.width = liveWidth
                updated.height = liveHeight
                store.update(updated, writeText: false)
                resize = .zero
                isDragging = false
            }
    }

    private func clamp(_ value: Double, min lower: Double = 0, max upper: Double) -> Double {
        Swift.max(lower, Swift.min(Swift.max(lower, upper), value))
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
