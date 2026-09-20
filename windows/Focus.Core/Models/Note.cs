namespace Focus.Core;

public sealed record NoteColor(string Key, string Label, string Hex)
{
    public static readonly NoteColor[] All =
    {
        new("amber", "Amber", "#FFD45E"),
        new("pink", "Pink", "#FF9EC4"),
        new("mint", "Mint", "#8EE3BF"),
        new("sky", "Sky", "#8FCCFF"),
        new("lilac", "Lilac", "#C2A6FF"),
        new("lime", "Lime", "#D9E86B")
    };

    public static NoteColor Named(string key) =>
        All.FirstOrDefault(c => c.Key == key) ?? All[0];
}

/// A sticky note. Its text is a section of the board's Word document; everything
/// else here is board furniture, kept in Board.json beside it.
public sealed class Note : Observable
{
    public const double DefaultWidth = 240;
    public const double DefaultHeight = 240;
    public const double MinimumWidth = 160;
    public const double MinimumHeight = 150;

    private string _text = "";
    private double _x = 24, _y = 24, _width = DefaultWidth, _height = DefaultHeight;
    private string _color = "amber";
    private int _z = 1;

    /// The note's stamp, which is also its identity inside the document.
    public string Id { get; }
    public DateTime CreatedAt { get; }

    public Note(string id, DateTime createdAt) { Id = id; CreatedAt = createdAt; }

    public string Text { get => _text; set { if (Set(ref _text, value)) Raise(nameof(Title)); } }
    public double X { get => _x; set => Set(ref _x, value); }
    public double Y { get => _y; set => Set(ref _y, value); }
    public double Width { get => _width; set => Set(ref _width, value); }
    public double Height { get => _height; set => Set(ref _height, value); }
    public string Color { get => _color; set => Set(ref _color, value); }
    public int Z { get => _z; set => Set(ref _z, value); }

    public string Title
    {
        get
        {
            var first = (Text.Split('\n').FirstOrDefault() ?? "").Trim();
            return first.Length == 0 ? "Untitled note" : first;
        }
    }
}

/// What Board.json holds: where a note sits, not what it says.
public sealed class NoteLayout
{
    public double X { get; set; }
    public double Y { get; set; }
    public double Width { get; set; }
    public double Height { get; set; }
    public string Color { get; set; } = "amber";
    public int Z { get; set; }
}
