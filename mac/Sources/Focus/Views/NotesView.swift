import AppKit
import FocusKit
import SwiftUI

struct NotesView: View {
    @ObservedObject var store: NotesStore

    @State private var editing: FolderEdit?
    @State private var name = ""
    @State private var boardSize = CGSize(width: 900, height: 600)

    private enum FolderEdit: Identifiable {
        case new, rename
        var id: String { self == .new ? "new" : "rename" }
    }

    var body: some View {
        VStack(spacing: 12) {
            toolbar
            board
            Text("This board is one Word document, a section per note. Drag by the top bar, resize from the corner.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .sheet(item: $editing) { edit in
            folderSheet(edit)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Picker("", selection: $store.selectedFolder) {
                ForEach(store.folders, id: \.self) { folder in
                    Text(folder).tag(folder)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 180)

            Menu {
                Button("New board…") { name = ""; editing = .new }
                Button("Rename board…") { name = store.selectedFolder; editing = .rename }
                Button("Move board to Trash") { store.trashFolder() }
                    .disabled(store.folders.count < 2)
                Divider()
                Button("Reveal document in Finder") {
                    store.flush()
                    NSWorkspace.shared.activateFileViewerSelecting([store.documentURL(forFolder: store.selectedFolder)])
                }
                Button("Reload from disk") { store.reload() }
            } label: {
                Image(systemName: "folder")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 42)

            Spacer()

            Button("Open in Word") {
                if let file = store.compileFolder() {
                    NSWorkspace.shared.open(file)
                }
            }
            .disabled(store.notes.isEmpty)
            .help("Open this board's Word document — every note on it, in one file")

            Button(store.isStacked ? "Expand all" : "Organise") {
                if store.isStacked {
                    store.isStacked = false
                } else {
                    store.organise(boardHeight: boardSize.height)
                }
            }
            .disabled(store.notes.isEmpty)

            Button("+ New note") {
                // A spring rather than a curve: the slight overshoot is what
                // makes the note look pressed onto the board instead of pasted
                // into the frame.
                withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                    _ = store.add()
                }
            }
                .buttonStyle(.borderedProminent)
        }
    }

    private var board: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .underPageBackgroundColor))
                    .overlay { dots }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )

                if store.notes.isEmpty {
                    Text("Nothing in “\(store.selectedFolder)” yet — add a note and drag it anywhere.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                ForEach(store.notes) { note in
                    NoteCardView(store: store, note: note, bounds: geometry.size)
                        .transition(.stickyNote)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            // Cards measure their drags against this, not against themselves.
            .coordinateSpace(name: NoteCardView.boardSpace)
            .onAppear { boardSize = geometry.size }
            .onChange(of: geometry.size) { _, size in boardSize = size }
        }
        .frame(minHeight: 420)
    }

    /// The board's paper: a grid of dots, drawn once into a canvas rather than
    /// as a view per dot.
    private var dots: some View {
        Canvas { context, size in
            let spacing = 22.0
            let diameter = 1.7
            let colour = GraphicsContext.Shading.color(Color(nsColor: .tertiaryLabelColor))

            var y = spacing
            while y < size.height {
                var x = spacing
                while x < size.width {
                    let dot = CGRect(
                        x: x - diameter / 2,
                        y: y - diameter / 2,
                        width: diameter,
                        height: diameter
                    )
                    context.fill(Path(ellipseIn: dot), with: colour)
                    x += spacing
                }
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }

    private func folderSheet(_ edit: FolderEdit) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(edit == .new ? "New board" : "Rename board")
                .font(.headline)

            TextField("Folder name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
                .onSubmit(commit)

            HStack {
                Spacer()
                Button("Cancel") { editing = nil }
                Button(edit == .new ? "Create" : "Rename", action: commit)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
    }

    private func commit() {
        guard let edit = editing else { return }
        if edit == .new {
            store.addFolder(name)
        } else {
            store.renameFolder(name)
        }
        editing = nil
    }
}
