import Foundation

/// Reads and writes a note as a Word document.
///
/// Word opens HTML with a .doc extension as a document, which keeps the app free of
/// a .docx zip writer and leaves the file readable in any text editor. The app can
/// read back what it wrote exactly; if Word rewrites a file, the text is still
/// recovered, though its formatting is not.
public enum NoteDocument {
    public static let fileExtension = "doc"

    public static func stamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    public static func longStamp(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Parses a note's creation time back out of its filename, which is where it is
    /// recorded — the filesystem's own dates move when a file is copied.
    public static func date(fromFilename name: String) -> Date? {
        let base = (name as NSString).deletingPathExtension
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: String(base.prefix(19)))
    }

    // MARK: - Writing

    public static func html(text: String, createdAt: Date, title: String? = nil) -> String {
        let heading = title ?? firstLine(of: text)
        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"><title>\(escape(heading))</title>
        <style>
        body { font-family: Calibri, sans-serif; font-size: 11pt; }
        h1 { font-size: 16pt; margin: 0 0 4pt; }
        .stamp { color: #666666; font-size: 9pt; margin: 0 0 12pt; }
        </style></head>
        <body>
        <h1>\(escape(heading))</h1>
        <p class="stamp">\(escape(longStamp(for: createdAt)))</p>
        \(body(of: text))
        </body></html>
        """
    }

    /// Every note in a folder, oldest first, separated by horizontal rules.
    public static func compiled(notes: [Note], folder: String) -> String {
        let ordered = notes.sorted { $0.createdAt < $1.createdAt }
        let sections = ordered.map { note -> String in
            """
            <h2>\(escape(note.title))</h2>
            <p class="stamp">\(escape(longStamp(for: note.createdAt)))</p>
            \(body(of: note.text, skippingFirstLine: true))
            """
        }

        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"><title>\(escape(folder))</title>
        <style>
        body { font-family: Calibri, sans-serif; font-size: 11pt; }
        h1 { font-size: 20pt; }
        h2 { font-size: 14pt; margin: 0 0 4pt; }
        .stamp { color: #666666; font-size: 9pt; margin: 0 0 12pt; }
        hr { border: 0; border-top: 1px solid #cccccc; margin: 24pt 0; }
        </style></head>
        <body>
        <h1>\(escape(folder))</h1>
        \(sections.joined(separator: "\n<hr>\n"))
        </body></html>
        """
    }

    private static func firstLine(of text: String) -> String {
        let first = text.split(separator: "\n", omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let trimmed = first.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Untitled note" : trimmed
    }

    private static func body(of text: String, skippingFirstLine: Bool = true) -> String {
        var lines = text.components(separatedBy: "\n")
        if skippingFirstLine, !lines.isEmpty { lines.removeFirst() }
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

    /// Recovers a note's text. `<h1>` is the first line, the timestamp paragraph is
    /// dropped, and the remaining paragraphs are the rest.
    public static func text(fromHTML html: String) -> String {
        var source = html
        for tag in ["head", "style", "script"] {
            source = remove(tag: tag, from: source)
        }

        var lines: [String] = []
        for (tag, content) in blocks(in: source) {
            let value = unescape(strip(content)).replacingOccurrences(of: "\u{00a0}", with: "")
            if tag == "h1" {
                lines.insert(value, at: 0)
            } else if tag == "p" {
                // The stamp paragraph is generated, not typed, so it is not text.
                if lines.count == 1, isStamp(content) { continue }
                lines.append(value)
            }
        }

        while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    private static func isStamp(_ content: String) -> Bool {
        content.range(of: "class=\"stamp\"") != nil
    }

    private static func blocks(in html: String) -> [(String, String)] {
        var results: [(String, String)] = []
        let pattern = "<(h1|p)([^>]*)>(.*?)</\\1>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else {
            return results
        }

        let range = NSRange(html.startIndex..., in: html)
        for match in regex.matches(in: html, range: range) {
            guard
                let tagRange = Range(match.range(at: 1), in: html),
                let attributeRange = Range(match.range(at: 2), in: html),
                let contentRange = Range(match.range(at: 3), in: html)
            else { continue }
            let tag = String(html[tagRange]).lowercased()
            results.append((tag, String(html[attributeRange]) + ">" + String(html[contentRange])))
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
        if let cut = text.firstIndex(of: ">") { text = String(text[text.index(after: cut)...]) }
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
