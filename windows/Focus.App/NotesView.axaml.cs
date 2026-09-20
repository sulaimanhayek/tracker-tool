using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Markup.Xaml;
using Avalonia.Media;
using Shape = Avalonia.Controls.Shapes;
using Focus.Core;
using CoreBackground = Focus.Core.Background;

namespace Focus.App;

/// A board of sticky notes over a dotted surface. What you drag here is
/// furniture; the words go into the board's Word document.
public partial class NotesView : UserControl
{
    private readonly Shell _shell;
    private bool _syncingPicker;

    public NotesView() : this(new Shell()) { }

    public NotesView(Shell shell)
    {
        _shell = shell;
        InitializeComponent();

        shell.Notes.Notes.CollectionChanged += (_, _) => Redraw();
        shell.Notes.Folders.CollectionChanged += (_, _) => RefreshBoards();
        shell.Notes.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(NotesStore.SelectedFolder)) RefreshBoards();
            if (e.PropertyName == nameof(NotesStore.IsStacked)) RefreshButtons();
        };

        RefreshBoards();
        Redraw();
        ApplyBackground();
    }

    private void InitializeComponent() => AvaloniaXamlLoader.Load(this);

    /// The board takes the palette's surface colour, and its dots the text
    /// colour at a whisper, so a light palette still shows them.
    public void ApplyBackground()
    {
        var palette = _shell.Backgrounds.Current;
        var board = this.FindControl<Border>("Board");
        if (board is null) return;

        board.Background = new DrawingBrush
        {
            TileMode = TileMode.Tile,
            SourceRect = new RelativeRect(0, 0, 22, 22, RelativeUnit.Absolute),
            DestinationRect = new RelativeRect(0, 0, 22, 22, RelativeUnit.Absolute),
            Drawing = new DrawingGroup
            {
                Children =
                {
                    new GeometryDrawing
                    {
                        Brush = Palette.Brush(palette.SurfaceHex),
                        Geometry = new RectangleGeometry(new Rect(0, 0, 22, 22))
                    },
                    new GeometryDrawing
                    {
                        Brush = new SolidColorBrush(Dot(palette)),
                        Geometry = new EllipseGeometry(new Rect(10, 10, 1.8, 1.8))
                    }
                }
            }
        };
    }

    private static Color Dot(CoreBackground palette)
    {
        var (r, g, b) = CoreBackground.Rgb(palette.TextHex);
        return Color.FromArgb(60, r, g, b);
    }

    private void RefreshBoards()
    {
        var picker = this.FindControl<ComboBox>("BoardPicker")!;
        _syncingPicker = true;
        picker.ItemsSource = _shell.Notes.Folders.ToList();
        picker.SelectedItem = _shell.Notes.SelectedFolder;
        _syncingPicker = false;

        this.FindControl<MenuItem>("TrashBoardItem")!.IsEnabled = _shell.Notes.Folders.Count > 1;
        RefreshButtons();
    }

    private void RefreshButtons()
    {
        var any = _shell.Notes.Notes.Count > 0;
        this.FindControl<Button>("OpenInWord")!.IsEnabled = any;
        var organise = this.FindControl<Button>("OrganiseButton")!;
        organise.IsEnabled = any;
        organise.Content = _shell.Notes.IsStacked ? "Expand all" : "Organise";
    }

    private void Redraw()
    {
        var surface = this.FindControl<Canvas>("Surface")!;
        surface.Children.Clear();

        foreach (var note in _shell.Notes.Notes.OrderBy(n => n.Z))
            surface.Children.Add(Card(note));

        var hint = this.FindControl<TextBlock>("EmptyHint")!;
        hint.IsVisible = _shell.Notes.Notes.Count == 0;
        hint.Text = $"Nothing on “{_shell.Notes.SelectedFolder}” yet — add a note and drag it anywhere.";

        RefreshButtons();
    }

    /// One note: a coloured card with a grab bar, a colour menu, a close button
    /// and a corner to resize from.
    private Control Card(Note note)
    {
        var paper = Palette.Brush(NoteColor.Named(note.Color).Hex);

        var text = new TextBox
        {
            Text = note.Text,
            AcceptsReturn = true,
            TextWrapping = TextWrapping.Wrap,
            Background = Brushes.Transparent,
            BorderThickness = default,
            Foreground = Brushes.Black,
            Margin = new Thickness(6, 2, 6, 6),
            Watermark = "Type here…",
            Classes = { "note" }
        };
        text.TextChanged += (_, _) =>
        {
            if (note.Text == text.Text) return;
            note.Text = text.Text ?? "";
            _shell.Notes.NoteTextChanged();
        };

        var colours = new MenuFlyout();
        foreach (var colour in NoteColor.All)
        {
            var key = colour.Key;
            var item = new MenuItem
            {
                Header = colour.Label,
                Icon = new Border
                {
                    Width = 12, Height = 12,
                    CornerRadius = new CornerRadius(3),
                    Background = Palette.Brush(colour.Hex)
                }
            };
            item.Click += (_, _) => { note.Color = key; _shell.Notes.NoteMoved(); Redraw(); };
            colours.Items.Add(item);
        }

        var palette = new Button
        {
            Content = "●",
            FontSize = 11,
            Foreground = Brushes.Black,
            Background = Brushes.Transparent,
            BorderThickness = default,
            Padding = new Thickness(5, 0),
            Flyout = colours
        };

        var close = new Button
        {
            Content = "✕",
            FontSize = 10,
            Foreground = Brushes.Black,
            Background = Brushes.Transparent,
            BorderThickness = default,
            Padding = new Thickness(5, 0)
        };
        close.Click += (_, _) => _shell.Notes.Trash(note);

        var bar = new Grid
        {
            ColumnDefinitions = new ColumnDefinitions("*,Auto,Auto"),
            Height = 24,
            Background = Brushes.Transparent,
            Cursor = new Cursor(StandardCursorType.SizeAll)
        };
        var stamp = new TextBlock
        {
            Text = note.CreatedAt.ToString("HH:mm"),
            FontSize = 10,
            Opacity = 0.55,
            Foreground = Brushes.Black,
            Margin = new Thickness(9, 0, 0, 0),
            VerticalAlignment = VerticalAlignment.Center
        };
        Grid.SetColumn(palette, 1);
        Grid.SetColumn(close, 2);
        bar.Children.Add(stamp);
        bar.Children.Add(palette);
        bar.Children.Add(close);

        var grip = new Border
        {
            Width = 16,
            Height = 16,
            Background = Brushes.Transparent,
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Bottom,
            Cursor = new Cursor(StandardCursorType.BottomRightCorner),
            Child = new Shape.Path
            {
                Data = Geometry.Parse("M 15,3 L 15,15 L 3,15 Z"),
                Fill = new SolidColorBrush(Color.FromArgb(55, 0, 0, 0))
            }
        };

        var card = new Border
        {
            Width = note.Width,
            Height = note.Height,
            Background = paper,
            CornerRadius = new CornerRadius(8),
            BoxShadow = BoxShadows.Parse("0 3 10 0 #33000000"),
            Child = new Panel
            {
                Children =
                {
                    new DockPanel { Children = { Dock(bar, Avalonia.Controls.Dock.Top), text } },
                    grip
                }
            }
        };

        Canvas.SetLeft(card, note.X);
        Canvas.SetTop(card, note.Y);

        Drag(bar, card, note, resizing: false);
        Drag(grip, card, note, resizing: true);

        // Clicking anywhere on the card brings it forward, so an overlapped note
        // is one click away rather than lost underneath.
        card.AddHandler(PointerPressedEvent, (_, _) =>
        {
            if (_shell.Notes.Notes.Count > 1) _shell.Notes.Lift(note);
        }, Avalonia.Interactivity.RoutingStrategies.Tunnel);

        return card;
    }

    private static Control Dock(Control control, Dock side)
    {
        DockPanel.SetDock(control, side);
        return control;
    }

    /// Moving and resizing are the same gesture with a different target, so they
    /// share one handler; the note is written back once the button comes up
    /// rather than on every pixel.
    private void Drag(Control handle, Border card, Note note, bool resizing)
    {
        var dragging = false;
        var origin = default(Point);
        var startX = 0.0;
        var startY = 0.0;

        handle.PointerPressed += (_, e) =>
        {
            dragging = true;
            origin = e.GetPosition(this.FindControl<Canvas>("Surface")!);
            startX = resizing ? note.Width : note.X;
            startY = resizing ? note.Height : note.Y;
            e.Pointer.Capture(handle);
        };

        handle.PointerMoved += (_, e) =>
        {
            if (!dragging) return;
            var here = e.GetPosition(this.FindControl<Canvas>("Surface")!);
            var dx = here.X - origin.X;
            var dy = here.Y - origin.Y;

            if (resizing)
            {
                card.Width = Math.Max(Note.MinimumWidth, startX + dx);
                card.Height = Math.Max(Note.MinimumHeight, startY + dy);
            }
            else
            {
                Canvas.SetLeft(card, Math.Max(0, startX + dx));
                Canvas.SetTop(card, Math.Max(0, startY + dy));
            }
        };

        handle.PointerReleased += (_, e) =>
        {
            if (!dragging) return;
            dragging = false;
            e.Pointer.Capture(null);

            if (resizing)
            {
                note.Width = card.Width;
                note.Height = card.Height;
            }
            else
            {
                note.X = Canvas.GetLeft(card);
                note.Y = Canvas.GetTop(card);
            }
            _shell.Notes.NoteMoved();
        };
    }

    private void BoardChanged(object? sender, SelectionChangedEventArgs e)
    {
        if (_syncingPicker) return;
        if (this.FindControl<ComboBox>("BoardPicker")!.SelectedItem is string folder)
            _shell.Notes.SelectedFolder = folder;
    }

    private void AddNote(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => _shell.Notes.Add();

    private void Organise(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (_shell.Notes.IsStacked) _shell.Notes.IsStacked = false;
        else _shell.Notes.Organise(this.FindControl<Border>("Board")!.Bounds.Height);
        Redraw();
    }

    private void OpenDocument(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var file = _shell.Notes.CompileFolder();
        if (file is not null) DataFolder.Open(file);
    }

    private void RevealBoard(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        _shell.Notes.Flush();
        DataFolder.Reveal();
    }

    private void ReloadBoards(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        _shell.Notes.Reload();
        Redraw();
    }

    private void TrashBoard(object? sender, Avalonia.Interactivity.RoutedEventArgs e) => _shell.Notes.TrashFolder();

    private async void NewBoard(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var name = await AskForName("New board", "");
        if (!string.IsNullOrWhiteSpace(name)) _shell.Notes.AddFolder(name);
    }

    private async void RenameBoard(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var name = await AskForName("Rename board", _shell.Notes.SelectedFolder);
        if (!string.IsNullOrWhiteSpace(name)) _shell.Notes.RenameFolder(name);
    }

    /// A one-field dialog; Avalonia has no prompt of its own.
    private async Task<string?> AskForName(string title, string initial)
    {
        if (TopLevel.GetTopLevel(this) is not Window owner) return null;

        var box = new TextBox { Text = initial, Watermark = "Board name", Width = 260 };
        var ok = new Button { Content = "OK", IsDefault = true };
        var cancel = new Button { Content = "Cancel", IsCancel = true };

        var dialog = new Window
        {
            Title = title,
            Width = 320,
            SizeToContent = SizeToContent.Height,
            CanResize = false,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            Content = new StackPanel
            {
                Margin = new Thickness(20),
                Spacing = 14,
                Children =
                {
                    new TextBlock { Text = title, FontWeight = FontWeight.SemiBold },
                    box,
                    new StackPanel
                    {
                        Orientation = Orientation.Horizontal,
                        Spacing = 8,
                        HorizontalAlignment = HorizontalAlignment.Right,
                        Children = { cancel, ok }
                    }
                }
            }
        };

        ok.Click += (_, _) => dialog.Close(box.Text);
        cancel.Click += (_, _) => dialog.Close(null);
        box.KeyDown += (_, args) => { if (args.Key == Key.Enter) dialog.Close(box.Text); };

        return await dialog.ShowDialog<string?>(owner);
    }
}
