import FocusKit
import SwiftUI

struct NoteCardView: View {
    @ObservedObject var store: NotesStore
    let note: Note
    let bounds: CGSize

    @State private var dragOrigin: CGPoint?
    @State private var resizeOrigin: CGSize?
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
        .frame(width: note.width, height: isCollapsed ? peek : note.height, alignment: .top)
        .background(paper)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: .black.opacity(isCollapsed ? 0.25 : 0.35), radius: hovering ? 12 : 7, y: 5)
        .overlay(alignment: .bottomTrailing) { if !isCollapsed { handle } }
        .position(x: note.x + note.width / 2, y: note.y + (isCollapsed ? peek : note.height) / 2)
        .zIndex(Double(hovering && store.isStacked ? 10_000 : note.z))
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
                    .frame(maxWidth: note.width * 0.55, alignment: .trailing)
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

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragOrigin == nil {
                    dragOrigin = CGPoint(x: note.x, y: note.y)
                    store.lift(note)
                }
                guard let origin = dragOrigin else { return }
                var updated = note
                // Clamped so a note can never be dragged off the board and lost.
                updated.x = clamp(origin.x + value.translation.width, max: bounds.width - note.width)
                updated.y = clamp(origin.y + value.translation.height, max: bounds.height - note.height)
                store.update(updated, writeText: false)
            }
            .onEnded { _ in dragOrigin = nil }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if resizeOrigin == nil {
                    resizeOrigin = CGSize(width: note.width, height: note.height)
                    store.lift(note)
                }
                guard let origin = resizeOrigin else { return }
                var updated = note
                updated.width = clamp(
                    origin.width + value.translation.width,
                    min: Note.minimumSize.width,
                    max: bounds.width - note.x
                )
                updated.height = clamp(
                    origin.height + value.translation.height,
                    min: Note.minimumSize.height,
                    max: bounds.height - note.y
                )
                store.update(updated, writeText: false)
            }
            .onEnded { _ in resizeOrigin = nil }
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
