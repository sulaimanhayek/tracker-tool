import FocusKit
import Foundation

// Checks for the parts that must not be got wrong: the session log's round trip
// through CSV, and the arithmetic behind every figure the app reports.
// XCTest is not available without Xcode, so this is a plain executable.

var failures = 0

func check(_ name: String, _ condition: @autoclosure () -> Bool) {
    if condition() {
        print("  ok   \(name)")
    } else {
        print("  FAIL \(name)")
        failures += 1
    }
}

func date(_ string: String) -> Date {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    return formatter.date(from: string)!
}

print("CSV")
check("plain field is left alone", CSV.escape("Deep work") == "Deep work")
check("comma forces quoting", CSV.escape("Reading, writing") == "\"Reading, writing\"")
check("quote is doubled", CSV.escape("He said \"go\"") == "\"He said \"\"go\"\"\"")
check("round trip keeps a comma", CSV.parse(row: CSV.row(["a,b", "c"])) == ["a,b", "c"])
check("round trip keeps a quote", CSV.parse(row: CSV.row(["say \"hi\"", "x"])) == ["say \"hi\"", "x"])
check("empty fields survive", CSV.parse(row: "a,,c") == ["a", "", "c"])

print("\nSession log")
let folder = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("focus-check-\(UUID().uuidString)")
DataFolder.setURL(folder)
// The app only touches disk once the folder question has been answered.
DataFolder.markChosen()
// The board the app was last on is remembered between launches, and these
// checks are a launch like any other — without this, a run starts wherever the
// previous run left off and the checks below are no longer deterministic.
UserDefaults.standard.removeObject(forKey: "selectedNotesFolder")
UserDefaults.standard.removeObject(forKey: "roundsDate")
UserDefaults.standard.removeObject(forKey: "completedRoundsToday")
defer {
    DataFolder.setURL(nil)
    try? FileManager.default.removeItem(at: folder)
}

let log = SessionLog()
check("starts empty", log.sessions.isEmpty)

let written = [
    Session(start: date("2026-09-19 09:00:00"), end: date("2026-09-19 10:00:00"), theme: "Deep work", completed: true),
    Session(start: date("2026-09-19 11:00:00"), end: date("2026-09-19 11:30:00"), theme: "Reading, notes", completed: false),
    Session(start: date("2026-09-18 14:00:00"), end: date("2026-09-18 15:00:00"), theme: "Deep work", completed: true)
]
written.forEach(log.append)

check("three rows appended", log.sessions.count == 3)
check("no error was recorded", log.lastError == nil)

let reloaded = SessionLog()
check("rows survive a reload", reloaded.sessions.count == 3)
check("a theme containing a comma survives", reloaded.sessions[1].theme == "Reading, notes")
check("duration survives", reloaded.sessions[0].seconds == 3600)
check("the completed flag survives", reloaded.sessions[0].completed && !reloaded.sessions[1].completed)

let raw = (try? String(contentsOf: DataFolder.sessionsFile, encoding: .utf8)) ?? ""
check("file carries a header", raw.hasPrefix(SessionLog.header))
check("file has one line per session plus the header", raw.split(separator: "\n").count == 4)

print("\nStatistics")
let now = date("2026-09-19 18:00:00")
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = .current

let sessions = reloaded.sessions
check(
    "today totals only today",
    Statistics.total(sessions, grain: .day, now: now, calendar: calendar) == 5400
)
check(
    "the year totals everything",
    Statistics.total(sessions, grain: .year, now: now, calendar: calendar) == 9000
)

let byTheme = Statistics.byTheme(sessions, grain: .year, now: now, calendar: calendar)
check("themes are ranked by time", byTheme.first?.theme == "Deep work")
check("a theme's time is summed across days", byTheme.first?.seconds == 7200)

let daily = Statistics.buckets(sessions, grain: .day, now: now, calendar: calendar)
check("the daily chart spans a fortnight", daily.count == Grain.day.span)
check("the last bucket is today", daily.last?.seconds == 5400)
check("empty days are kept as gaps", daily.contains { $0.seconds == 0 })
check("buckets run oldest first", daily.first!.start < daily.last!.start)

print("\nFormatting")
check("minutes alone", Statistics.format(seconds: 1500) == "25m")
check("whole hours drop the minutes", Statistics.format(seconds: 7200) == "2h")
check("hours and minutes", Statistics.format(seconds: 5400) == "1h 30m")

print("\nNotes: a document round trip")
let sample = "Shipping plan\nDraft the release notes\n\nThen tag it, <b>carefully</b> & twice"
let created = date("2026-09-19 15:50:44")
let sampleNote = Note(id: NoteDocument.stamp(for: created), createdAt: created, text: sample)
let doc = NoteDocument.board(notes: [sampleNote], name: "Board")

check("the board is titled after itself", doc.contains("<h1>Board</h1>"))
check("the first line becomes the section heading", doc.contains("<h2>Shipping plan</h2>"))
check("the stamp is written", doc.contains("<p class=\"stamp\">2026-09-19 15:50:44</p>"))
check("angle brackets are escaped", doc.contains("&lt;b&gt;carefully&lt;/b&gt;"))
check("an ampersand is escaped", doc.contains("&amp; twice"))

let readBack = NoteDocument.notes(fromHTML: doc)
check("one section reads back as one note", readBack.count == 1)
check("text survives the round trip", readBack.first?.text == sample)
check("the identity survives the round trip", readBack.first?.id == sampleNote.id)
check("the creation time survives the round trip", readBack.first?.createdAt == created)

let second = Note(id: NoteDocument.stamp(for: created.addingTimeInterval(60)),
                  createdAt: created.addingTimeInterval(60), text: "Second note\nwith a line")
let two = NoteDocument.board(notes: [second, sampleNote], name: "Board")
let bothBack = NoteDocument.notes(fromHTML: two)
check("two notes make two sections", two.components(separatedBy: "<h2>").count == 3)
check("sections are separated by a rule", two.contains("<hr>"))
check("both notes read back", bothBack.count == 2)
check("they come back oldest first", bothBack.first?.id == sampleNote.id)

let empty = NoteDocument.board(notes: [Note(id: "x", createdAt: created, text: "")], name: "Board")
check("an empty note gets a placeholder heading", empty.contains("<h2>Untitled note</h2>"))
check("an empty note reads back as its heading", NoteDocument.notes(fromHTML: empty).first?.text == "Untitled note")

// A section someone typed into Word by hand has no stamp, and must not vanish.
let handwritten = """
<html><body><h1>Board</h1>
<h2>Typed in Word</h2><p>a thought</p>
</body></html>
"""
let rescued = NoteDocument.notes(fromHTML: handwritten, fallbackDate: created)
check("a section without a stamp is still read", rescued.count == 1)
check("and it keeps its text", rescued.first?.text == "Typed in Word\na thought")
check("and it is given the fallback date", rescued.first?.createdAt == created)

check("a stamp parses back to its date", NoteDocument.date(fromStamp: "2026-09-19 15:50:44") == created)
check("a de-duplicated stamp still parses", NoteDocument.date(fromStamp: "2026-09-19 15:50:44 (2)") == created)

print("\nNotes: the board")
let notes = NotesStore()
check("a board starts empty", notes.notes.isEmpty)

guard var first = notes.add() else {
    print("  FAIL could not create a note")
    exit(1)
}
first.text = "Shipping plan\nDraft the release notes"
first.x = 120
first.color = "mint"
notes.update(first, writeText: true)
notes.flush()

let boardDoc = notes.documentURL(forFolder: notes.selectedFolder)
check("the board is one document on disk", FileManager.default.fileExists(atPath: boardDoc.path))
check("the document is a .doc", boardDoc.lastPathComponent == "Board.doc")
check("a layout file sits beside it", FileManager.default.fileExists(atPath: notes.layoutURL(forFolder: "Board").path))

let reopened = NotesStore()
check("the note comes back", reopened.notes.count == 1)
check("its text comes back", reopened.notes.first?.text == "Shipping plan\nDraft the release notes")
check("its position comes back", reopened.notes.first?.x == 120)
check("its colour comes back", reopened.notes.first?.color == "mint")
check("its creation time comes back", reopened.notes.first?.id == first.id)
check("its title is the first line", reopened.notes.first?.title == "Shipping plan")

reopened.addFolder("Reading")
check("a new board is created", reopened.folders.contains("Reading"))
check("switching board clears the canvas", reopened.notes.isEmpty)
check("the new board has its own document",
      FileManager.default.fileExists(atPath: reopened.documentURL(forFolder: "Reading").path))

reopened.selectedFolder = "Board"
check("switching back brings the notes with it", reopened.notes.count == 1)

_ = reopened.add()
check("a second note lands on the board", reopened.notes.count == 2)
check("the two notes have different identities", reopened.notes[0].id != reopened.notes[1].id)
reopened.flush()
check(
    "both live in the one document",
    ((try? String(contentsOf: boardDoc, encoding: .utf8)) ?? "").components(separatedBy: "<h2>").count == 3
)

reopened.organise(boardHeight: 600)
check("organising stacks the board", reopened.isStacked)
check("organised notes line up in a column", reopened.notes[0].x == reopened.notes[1].x)
check("organised notes are spaced apart", reopened.notes[1].y > reopened.notes[0].y)

let toTrash = reopened.notes[1]
reopened.trash(toTrash)
check("removing a note takes it off the board", reopened.notes.count == 1)
check(
    "and out of the document",
    !((try? String(contentsOf: boardDoc, encoding: .utf8)) ?? "").contains(toTrash.id)
)
check("but the document itself stays", FileManager.default.fileExists(atPath: boardDoc.path))

print("\nNotes: folders from the old layout")
do {
    let manager = FileManager.default
    let legacy = DataFolder.notesFolder.appendingPathComponent("Archive", isDirectory: true)
    try? manager.createDirectory(at: legacy, withIntermediateDirectories: true)
    let oldNote = """
    <html><head><style>x</style></head><body><h1>Old note</h1>
    <p class="stamp">Saturday, 19 September 2026 at 15:50</p><p>still here</p></body></html>
    """
    try? oldNote.write(to: legacy.appendingPathComponent("2026-09-19_15-50-44.doc"),
                       atomically: true, encoding: .utf8)
    try? #"{"2026-09-19_15-50-44.doc":{"x":40,"y":60,"width":240,"height":240,"color":"mint","z":1}}"#
        .write(to: legacy.appendingPathComponent("board.json"), atomically: true, encoding: .utf8)

    let migrated = NotesStore()
    check("the old folder becomes a board", migrated.folders.contains("Archive"))
    migrated.selectedFolder = "Archive"
    check("its note is carried across", migrated.notes.count == 1)
    check("with its text", migrated.notes.first?.text == "Old note\nstill here")
    check("and its place on the board", migrated.notes.first?.x == 40)
    check("the old folder is left alone", manager.fileExists(atPath: legacy.path))

    // Migrating twice would overwrite the document that was just made.
    let again = NotesStore()
    again.selectedFolder = "Archive"
    check("a second launch does not re-migrate", again.notes.count == 1)
}

print("\nMoving the data folder")
do {
    let manager = FileManager.default
    let old = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("focus-move-old-\(UUID().uuidString)")
    let new = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("focus-move-new-\(UUID().uuidString)")
    defer {
        try? manager.removeItem(at: old)
        try? manager.removeItem(at: new)
        DataFolder.setURL(folder)
    }

    DataFolder.setURL(old)
    DataFolder.ensureExists()
    try? "keep me".write(to: DataFolder.sessionsFile, atomically: true, encoding: .utf8)
    try? manager.createDirectory(at: DataFolder.notesFolder, withIntermediateDirectories: true)

    let moved = try! DataFolder.relocate(to: new, movingExisting: true)
    check("the app now points at the new folder", DataFolder.url.path == new.path)
    check("the choice is remembered", DataFolder.isChosen)
    check("the log came along", manager.fileExists(atPath: new.appendingPathComponent("sessions.csv").path))
    check("the notes folder came along", manager.fileExists(atPath: new.appendingPathComponent("notes").path))
    check("nothing is left behind", !manager.fileExists(atPath: old.appendingPathComponent("sessions.csv").path))
    check("it reports what it moved", moved.moved.sorted() == ["notes", "sessions.csv"])

    // A file already at the destination is never overwritten.
    let third = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("focus-move-third-\(UUID().uuidString)")
    defer { try? manager.removeItem(at: third) }
    try? manager.createDirectory(at: third, withIntermediateDirectories: true)
    try? "mine".write(to: third.appendingPathComponent("sessions.csv"), atomically: true, encoding: .utf8)
    let second = try! DataFolder.relocate(to: third, movingExisting: true)
    check("an existing file at the destination is kept", second.kept.contains("sessions.csv"))
    check(
        "and it keeps its own contents",
        (try? String(contentsOf: third.appendingPathComponent("sessions.csv"), encoding: .utf8)) == "mine"
    )
    check(
        "the one it could not move stays where it was",
        manager.fileExists(atPath: new.appendingPathComponent("sessions.csv").path)
    )

    // Leaving the data behind is the other half of the choice.
    let fresh = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("focus-move-fresh-\(UUID().uuidString)")
    defer { try? manager.removeItem(at: fresh) }
    try! DataFolder.relocate(to: fresh, movingExisting: false)
    check("starting fresh creates the folder", manager.fileExists(atPath: fresh.path))
    check("starting fresh brings nothing", (try! manager.contentsOfDirectory(atPath: fresh.path)).isEmpty)
}

print("")
if failures == 0 {
    print("All checks passed.")
} else {
    print("\(failures) check(s) failed.")
    exit(1)
}
