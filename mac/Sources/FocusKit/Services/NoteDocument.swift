import Foundation

/// Reads and writes a board as a single Word document.
///
/// A board is one document with a section per note, so what you open in Word is
/// the board itself rather than a folder of fragments. Word opens HTML with a
/// .doc extension as a document, which keeps the app free of a .docx zip writer
/// and leaves the file readable in any text editor. The app reads back exactly
/// what it wrote; if Word rewrites the file, the text and the section stamps are
/// still recovered, though the formatting is not.
public enum NoteDocument {
    public static let fileExtension = "doc"

    /// The stamp is both a note's identity and its creation time, printed in the
    /// document so it survives a round trip through Word. It is deliberately
    /// locale-free — a Mac set to another language must still read these back.
    public static func stamp(for date: Date) -> String {
        formatter(for: "yyyy-MM-dd HH:mm:ss").string(from: date)
    }

    public static func date(fromStamp stamp: String) -> Date? {
        formatter(for: "yyyy-MM-dd HH:mm:ss").date(from: String(stamp.prefix(19)))
    }

    /// A stamp for reading, not for storing — shown on the card itself.
    public static func longStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// A stamp that can also be a filename.
    public static func fileStamp(for date: Date) -> String {
        formatter(for: "yyyy-MM-dd_HH-mm-ss").string(from: date)
    }

    private static func formatter(for format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    // MARK: - Writing

    /// The whole board, oldest note first, separated by horizontal rules.
    public static func board(notes: [Note], name: String) -> String {
        let sections = notes.sorted { $0.createdAt < $1.createdAt }.map { note in
            """
            <h2>\(escape(note.title))</h2>
            <p class="stamp">\(escape(note.id))</p>
            \(body(of: note.text))
            """
        }

        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"><title>\(escape(name))</title>
        <style>
        body { font-family: Calibri, sans-serif; font-size: 11pt; }
        h1 { font-size: 20pt; margin: 0 0 16pt; }
        h2 { font-size: 14pt; margin: 0 0 4pt; }
        .stamp { color: #666666; font-size: 9pt; margin: 0 0 12pt; }
        hr { border: 0; border-top: 1px solid #cccccc; margin: 24pt 0; }
        </style></head>
        <body>
        <h1>\(escape(name))</h1>
        \(sections.joined(separator: "\n<hr>\n"))
        </body></html>
        """
    }

    private static func body(of text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        // The first line is the heading already, so it is not repeated here.
        if !lines.isEmpty { lines.removeFirst() }
        guard !lines.isEmpty else { return "" }
        // A blank line still needs a paragraph, or Word closes the gap up.
        return lines
            .map { "<p>\($0.isEmpty ? "&nbsp;" : escape($0))</p>" }
            .joined(separator: "\n")
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    // MARK: - Reading

    /// One note recovered from a section of the document.
    public struct Parsed {
        public var id: String
        public var createdAt: Date
        public var text: String

        public init(id: String, createdAt: Date, text: String) {
            self.id = id
            self.createdAt = createdAt
            self.text = text
        }
    }

    /// Splits a board document back into its notes. A section whose stamp is
    /// missing or unreadable — someone typed a new section into Word, say — is
    /// still kept, and is given the file's own date rather than being dropped.
    ///
    /// `titleTag` is `h2` in a board document; the folder-per-board layout this
    /// replaced used `h1`, and migrating those reads them with `h1`.
    public static func notes(
        fromHTML html: String,
        fallbackDate: Date = Date(),
        titleTag: String = "h2"
    ) -> [Parsed] {
        var source = html
        for tag in ["head", "style", "script"] {
            source = remove(tag: tag, from: source)
        }

        var results: [Parsed] = []
        var used = Set<String>()

        for section in split(source) {
            var lines: [String] = []
            var stamp: String?

            for (tag, attributes, content) in blocks(in: section) {
                let value = unescape(strip(content)).replacingOccurrences(of: "\u{00a0}", with: "")
                switch tag {
                case titleTag:
                    lines.insert(value, at: 0)
                case "h1", "h2":
                    continue // the board's own name
                case "p" where attributes.contains("class=\"stamp\"") && stamp == nil:
                    stamp = value.trimmingCharacters(in: .whitespaces)
                default:
                    lines.append(value)
                }
            }

            while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.removeLast()
            }
            guard !lines.isEmpty || stamp != nil else { continue }

            let created = stamp.flatMap(date(fromStamp:)) ?? fallbackDate
            var id = stamp.flatMap { date(fromStamp: $0) != nil ? $0 : nil } ?? self.stamp(for: created)
            var attempt = 2
            // Two sections cannot share an identity, or the board file would only
            // remember where one of them sits.
            while used.contains(id) {
                id = "\(self.stamp(for: created)) (\(attempt))"
                attempt += 1
            }
            used.insert(id)

            results.append(Parsed(id: id, createdAt: created, text: lines.joined(separator: "\n")))
        }

        return results
    }

    /// The document as sections: everything between the horizontal rules.
    private static func split(_ html: String) -> [String] {
        html.replacingOccurrences(
            of: "<hr[^>]*>",
            with: "\u{0001}",
            options: [.regularExpression, .caseInsensitive]
        )
        .components(separatedBy: "\u{0001}")
    }

    private static func blocks(in html: String) -> [(String, String, String)] {
        var results: [(String, String, String)] = []
        let pattern = "<(h1|h2|p)([^>]*)>(.*?)</\\1>"
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        ) else { return results }

        let range = NSRange(html.startIndex..., in: html)
        for match in regex.matches(in: html, range: range) {
            guard
                let tagRange = Range(match.range(at: 1), in: html),
                let attributeRange = Range(match.range(at: 2), in: html),
                let contentRange = Range(match.range(at: 3), in: html)
            else { continue }
            results.append((
                String(html[tagRange]).lowercased(),
                String(html[attributeRange]),
                String(html[contentRange])
            ))
        }
        return results
    }

    private static func remove(tag: String, from html: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: "<\(tag)[^>]*>.*?</\(tag)>",
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        ) else { return html }
        return regex.stringByReplacingMatches(
            in: html,
            range: NSRange(html.startIndex..., in: html),
            withTemplate: ""
        )
    }

    private static func strip(_ html: String) -> String {
        var text = html
        text = text.replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return text
    }

    private static func unescape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: "\u{00a0}")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}
