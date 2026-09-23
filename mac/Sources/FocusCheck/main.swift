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
UserDefaults.standard.removeObject(forKey: "background")
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

print("\nSounds")
do {
    UserDefaults.standard.removeObject(forKey: "soundsEnabled")
    check("sound is on until it is turned off", Sounds.isEnabled)
    Sounds.isEnabled = false
    check("turning it off sticks", !Sounds.isEnabled)
    Sounds.isEnabled = true
    check("and turning it back on sticks", Sounds.isEnabled)
    UserDefaults.standard.removeObject(forKey: "soundsEnabled")
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

print("\nBackgrounds")
do {
    check("all six palettes are offered", Background.all.count == 6)
    check(
        "every key is distinct",
        Set(Background.all.map(\.key)).count == Background.all.count
    )
    check("midnight is the first", Background.all[0].key == "midnight")

    // Hex parsing is the one place a typo would show as a wrong colour rather
    // than a failure, so it is pinned.
    let midnight = Background.named("midnight")
    check("a hex channel reads back", Int((midnight.background.red * 255).rounded()) == 0x12)
    check("and the middle one", Int((midnight.background.green * 255).rounded()) == 0x14)
    check("and the last", Int((midnight.background.blue * 255).rounded()) == 0x1a)
    check("white is white", RGB(hex: "#ffffff") == RGB(red: 1, green: 1, blue: 1))
    check("a malformed value is black rather than a crash", RGB(hex: "nonsense").red == 0)

    check("paper is a light palette", !Background.named("paper").isDark)
    check("parchment too", !Background.named("parchment").isDark)
    check("midnight is not", Background.named("midnight").isDark)
    check("an unknown key falls back to the first", Background.named("zzz").key == "midnight")

    let store = BackgroundStore()
    check("a new install starts on midnight", store.selected == "midnight")
    store.selected = "forest"
    check("the choice is remembered", BackgroundStore().selected == "forest")
    check("and the store hands back that palette", BackgroundStore().current.label == "Forest")
    UserDefaults.standard.removeObject(forKey: "background")
}

print("\nThe data folder as a directory")
do {
    let manager = FileManager.default
    let shown = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("focus-listing-\(UUID().uuidString)")
    defer { try? manager.removeItem(at: shown) }
    try! manager.createDirectory(at: shown.appendingPathComponent("notes"), withIntermediateDirectories: true)
    try! "x".write(to: shown.appendingPathComponent("sessions.csv"), atomically: true, encoding: .utf8)
    try! "x".write(to: shown.appendingPathComponent(".DS_Store"), atomically: true, encoding: .utf8)
    try! "x".write(to: shown.appendingPathComponent("notes/Board.doc"), atomically: true, encoding: .utf8)

    let entries = DataFolder.listing(of: shown)
    check("the folder's own files are listed", entries.map(\.name) == ["notes", "sessions.csv"])
    check("folders come first", entries[0].isDirectory)
    check("a file is not called a folder", !entries[1].isDirectory)
    check("dot files are left out", !entries.contains { $0.name.hasPrefix(".") })
    check("a folder shows what is in it", entries[0].children.map(\.name) == ["Board.doc"])
    check(
        "but only a level deep",
        DataFolder.listing(of: shown, depth: 0)[0].children.isEmpty
    )
    check("an empty folder lists nothing", DataFolder.listing(of: shown.appendingPathComponent("nowhere")).isEmpty)
}

print("\nTimer wake-ups")
do {
    let next = TimerModel.delayUntilNextChange
    let close = { (a: TimeInterval, b: TimeInterval) in abs(a - b) < 0.0001 }
    check("wakes when the shown second turns over", close(next(1500.0), 0.5))
    check("mid-second, waits only for the rest of it", close(next(1499.8), 0.3))
    check("never waits more than a second", close(next(1499.51), 0.01) && close(next(1499.49), 0.99))
    check("with zero showing, waits for the deadline itself", close(next(0.4), 0.4))
    check("a finished countdown does not wait", next(0) == 0 && next(-1) == 0)
}

print("\nTime added by hand")
do {
    let calendar = Calendar.current
    let day = date("2025-03-04 00:00:00")
    func at(_ hour: Int, _ minute: Int) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    let morning = ManualEntry.session(day: day, from: at(9, 0), to: at(11, 30), theme: "Writing", calendar: calendar)
    check("the hours land on the day picked", calendar.isDate(morning.start, inSameDayAs: day))
    check("the stretch is as long as the times say", morning.seconds == 150 * 60)
    check("the theme is carried through", morning.theme == "Writing")
    check("a stretch entered by hand is a finished one", morning.completed)
    check("nothing is wrong with a plain morning", ManualEntry.problem(with: morning, now: at(23, 0)) == nil)

    let overnight = ManualEntry.session(day: day, from: at(23, 30), to: at(0, 30), theme: "", calendar: calendar)
    check("a finish before the start crosses midnight", overnight.seconds == 60 * 60)
    check("but the row still belongs to the day it began", calendar.isDate(overnight.start, inSameDayAs: day))

    let nothing = ManualEntry.session(day: day, from: at(9, 0), to: at(9, 0), theme: "", calendar: calendar)
    check("a stretch with no time in it is refused", ManualEntry.problem(with: nothing) != nil)

    let marathon = ManualEntry.session(day: day, from: at(1, 0), to: at(20, 0), theme: "", calendar: calendar)
    check("an implausibly long stretch is refused", ManualEntry.problem(with: marathon) != nil)

    check(
        "time that has not happened yet is refused",
        ManualEntry.problem(with: morning, now: at(9, 30)) != nil
    )

    let afternoon = ManualEntry.session(day: day, from: at(14, 0), to: at(15, 0), theme: "", calendar: calendar)
    check("separate stretches do not overlap", !ManualEntry.overlap(morning, afternoon))
    check("a stretch overlaps itself", ManualEntry.overlap(morning, morning))
    check(
        "an hour inside another is an overlap",
        ManualEntry.overlap(morning, ManualEntry.session(day: day, from: at(10, 0), to: at(11, 0), theme: "", calendar: calendar))
    )
    check(
        "ending exactly when the next begins is not",
        !ManualEntry.overlap(afternoon, ManualEntry.session(day: day, from: at(15, 0), to: at(16, 0), theme: "", calendar: calendar))
    )
}

print("\nWhat one bar is made of")
do {
    let calendar = Calendar.current
    let monday = date("2025-03-03 09:00:00")
    let tuesday = date("2025-03-04 09:00:00")
    let sessions = [
        Session(start: monday, end: monday.addingTimeInterval(3600), theme: "Writing", completed: true),
        Session(start: monday.addingTimeInterval(7200), end: monday.addingTimeInterval(9000), theme: "Admin", completed: true),
        Session(start: monday.addingTimeInterval(10800), end: monday.addingTimeInterval(14400), theme: "Writing", completed: true),
        Session(start: tuesday, end: tuesday.addingTimeInterval(1800), theme: "Reading", completed: true)
    ]

    let split = Statistics.byTheme(sessions, in: monday, grain: .day, calendar: calendar)
    check("only that day's themes are counted", split.map(\.theme) == ["Writing", "Admin"])
    check("the same theme twice in a day adds up", split[0].seconds == 2 * 3600)
    check("the largest share comes first", split[0].seconds > split[1].seconds)
    check(
        "the split adds up to the bar it belongs to",
        split.reduce(0) { $0 + $1.seconds }
            == Statistics.buckets(sessions, grain: .day, now: monday, calendar: calendar).last?.seconds
    )
    check("a day with nothing on it splits into nothing", Statistics.byTheme(sessions, in: date("2025-03-05 09:00:00"), grain: .day, calendar: calendar).isEmpty)
    check(
        "a week gathers the days in it",
        Statistics.byTheme(sessions, in: monday, grain: .week, calendar: calendar)
            .reduce(0) { $0 + $1.seconds } == 3600 + 1800 + 3600 + 1800
    )
    check(
        "an unnamed theme is still shown",
        Statistics.byTheme(
            [Session(start: monday, end: monday.addingTimeInterval(600), theme: "", completed: true)],
            in: monday, grain: .day, calendar: calendar
        ).first?.theme == "No theme"
    )
}

print("\nColours and the chart in one pass")
do {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/London")!

    let monday = date("2025-03-03 09:00:00")
    let tuesday = date("2025-03-04 09:00:00")
    let sessions = [
        Session(start: monday, end: monday.addingTimeInterval(3600), theme: "Writing", completed: true),
        Session(start: monday.addingTimeInterval(7200), end: monday.addingTimeInterval(9000), theme: "Admin", completed: true),
        Session(start: tuesday, end: tuesday.addingTimeInterval(1800), theme: "Admin", completed: true),
        Session(start: tuesday.addingTimeInterval(3600), end: tuesday.addingTimeInterval(5400), theme: "Writing", completed: true)
    ]

    let order = ChartPalette.order(of: sessions)
    check("themes are coloured in the order they first appear", order == ["Writing", "Admin"])
    check("a theme named twice is only counted once", ChartPalette.order(of: sessions + sessions) == order)
    check("an unnamed theme gets a colour too", ChartPalette.order(of: [Session(start: monday, end: tuesday, theme: "", completed: true)]) == ["No theme"])
    check("the palette wraps rather than running out", ChartPalette.colour(ChartPalette.colours.count) == ChartPalette.colours[0])

    let periods = Statistics.breakdown(sessions, grain: .day, now: tuesday, calendar: calendar)
    check("a bar per period, as before", periods.count == Grain.day.span)
    check(
        "each bar totals what the plain buckets say",
        periods.map(\.seconds) == Statistics.buckets(sessions, grain: .day, now: tuesday, calendar: calendar).map(\.seconds)
    )

    let mondayBar = periods.first { $0.start == Statistics.start(of: monday, grain: .day, calendar: calendar) }
    let tuesdayBar = periods.first { $0.start == Statistics.start(of: tuesday, grain: .day, calendar: calendar) }
    check("a bar is split by theme", mondayBar?.slices.map(\.theme) == ["Writing", "Admin"])
    check("its slices add up to the bar", mondayBar?.slices.reduce(0) { $0 + $1.seconds } == mondayBar?.seconds)
    check("a theme keeps its colour from one bar to the next", mondayBar?.slices.first?.colour == tuesdayBar?.slices.first?.colour)
    check("slices are stacked in palette order, not by size", tuesdayBar?.slices.map(\.theme) == ["Writing", "Admin"])
    check("an empty period has no slices", periods.first { $0.slices.isEmpty && $0.seconds == 0 } != nil)
    check("labels come ready to draw", mondayBar?.title == Grain.day.title(for: mondayBar!.start, calendar: calendar))

    check("the label clock shows hours and minutes", Statistics.clock(seconds: 45 * 60) == "0:45")
    check("it pads the minutes", Statistics.clock(seconds: 2 * 3600 + 5 * 60) == "2:05")
    check("seconds left over do not round the minute up", Statistics.clock(seconds: 59) == "0:00")
}

print("")
if failures == 0 {
    print("All checks passed.")
} else {
    print("\(failures) check(s) failed.")
    exit(1)
}
