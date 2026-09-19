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

print("")
if failures == 0 {
    print("All checks passed.")
} else {
    print("\(failures) check(s) failed.")
    exit(1)
}
