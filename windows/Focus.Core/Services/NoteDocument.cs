using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace Focus.Core;

/// Reads and writes a board as a single Word document.
///
/// A board is one document with a section per note, so what you open in Word is
/// the board itself rather than a folder of fragments. Word opens HTML with a
/// .doc extension as a document, which keeps the app free of a .docx zip writer
/// and leaves the file readable in any text editor. Byte for byte the same
/// format the Mac app writes, so one folder serves both.
public static class NoteDocument
{
    public const string FileExtension = "doc";
    private const string StampFormat = "yyyy-MM-dd HH:mm:ss";

    /// The stamp is both a note's identity and its creation time, printed in the
    /// document so it survives a round trip through Word. It is deliberately
    /// culture-free — a PC set to another language must still read these back.
    public static string Stamp(DateTime date) =>
        date.ToString(StampFormat, CultureInfo.InvariantCulture);

    public static DateTime? DateFromStamp(string stamp)
    {
        var head = stamp.Length >= 19 ? stamp[..19] : stamp;
        return DateTime.TryParseExact(head, StampFormat, CultureInfo.InvariantCulture,
            DateTimeStyles.None, out var value) ? value : null;
    }

    /// A stamp for reading, not for storing — shown on the card itself.
    public static string LongStamp(DateTime date) => date.ToString("dddd d MMMM yyyy, HH:mm");

    /// The whole board, oldest note first, separated by horizontal rules.
    public static string Board(IEnumerable<Note> notes, string name)
    {
        var sections = notes
            .OrderBy(n => n.CreatedAt)
            .Select(note => $"<h2>{Escape(note.Title)}</h2>\n<p class=\"stamp\">{Escape(note.Id)}</p>\n{Body(note.Text)}");

        // Two dollars: CSS braces stay literal, and interpolation is {{…}}.
        return $$"""
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"><title>{{Escape(name)}}</title>
        <style>
        body { font-family: Calibri, sans-serif; font-size: 11pt; }
        h1 { font-size: 20pt; margin: 0 0 16pt; }
        h2 { font-size: 14pt; margin: 0 0 4pt; }
        .stamp { color: #666666; font-size: 9pt; margin: 0 0 12pt; }
        hr { border: 0; border-top: 1px solid #cccccc; margin: 24pt 0; }
        </style></head>
        <body>
        <h1>{{Escape(name)}}</h1>
        {{string.Join("\n<hr>\n", sections)}}
        </body></html>
        """;
    }

    private static string Body(string text)
    {
        var lines = text.Split('\n').Skip(1).ToList(); // the first line is the heading already
        if (lines.Count == 0) return "";
        // A blank line still needs a paragraph, or Word closes the gap up.
        return string.Join("\n", lines.Select(line =>
            $"<p>{(line.Length == 0 ? "&nbsp;" : Escape(line))}</p>"));
    }

    private static string Escape(string text) =>
        text.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;");

    /// One note recovered from a section of the document.
    public sealed record Parsed(string Id, DateTime CreatedAt, string Text);

    /// Splits a board document back into its notes. A section whose stamp is
    /// missing or unreadable — someone typed a new section into Word, say — is
    /// still kept, and is given the file's own date rather than being dropped.
    ///
    /// `titleTag` is `h2` in a board document; the folder-per-board layout this
    /// replaced used `h1`, and migrating those reads them with `h1`.
    public static List<Parsed> NotesFromHtml(string html, DateTime? fallbackDate = null, string titleTag = "h2")
    {
        var fallback = fallbackDate ?? DateTime.Now;
        var source = html;
        foreach (var tag in new[] { "head", "style", "script" })
            source = Regex.Replace(source, $"<{tag}[^>]*>.*?</{tag}>", "",
                RegexOptions.Singleline | RegexOptions.IgnoreCase);

        var results = new List<Parsed>();
        var used = new HashSet<string>();

        foreach (var section in Regex.Split(source, "<hr[^>]*>", RegexOptions.IgnoreCase))
        {
            var lines = new List<string>();
            string? stamp = null;

            foreach (Match match in Regex.Matches(section, @"<(h1|h2|p)([^>]*)>(.*?)</\1>",
                         RegexOptions.Singleline | RegexOptions.IgnoreCase))
            {
                var tag = match.Groups[1].Value.ToLowerInvariant();
                var attributes = match.Groups[2].Value;
                var value = Unescape(Strip(match.Groups[3].Value)).Replace(" ", "");

                if (tag == titleTag) lines.Insert(0, value);
                else if (tag is "h1" or "h2") continue; // the board's own name
                else if (tag == "p" && attributes.Contains("class=\"stamp\"") && stamp is null)
                    stamp = value.Trim();
                else lines.Add(value);
            }

            while (lines.Count > 0 && lines[^1].Trim().Length == 0) lines.RemoveAt(lines.Count - 1);
            if (lines.Count == 0 && stamp is null) continue;

            var created = (stamp is null ? null : DateFromStamp(stamp)) ?? fallback;
            var id = stamp is not null && DateFromStamp(stamp) is not null ? stamp : Stamp(created);

            // Two sections cannot share an identity, or the board file would only
            // remember where one of them sits.
            var attempt = 2;
            while (!used.Add(id)) id = $"{Stamp(created)} ({attempt++})";

            results.Add(new Parsed(id, created, string.Join("\n", lines)));
        }

        return results;
    }

    private static string Strip(string html)
    {
        var text = Regex.Replace(html, "<br>", "\n", RegexOptions.IgnoreCase);
        return Regex.Replace(text, "<[^>]+>", "");
    }

    private static string Unescape(string text) =>
        text.Replace("&nbsp;", " ")
            .Replace("&lt;", "<")
            .Replace("&gt;", ">")
            .Replace("&quot;", "\"")
            .Replace("&#39;", "'")
            .Replace("&amp;", "&");
}
