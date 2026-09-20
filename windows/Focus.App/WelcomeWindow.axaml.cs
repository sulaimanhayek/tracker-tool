using Avalonia.Controls;
using Avalonia.Markup.Xaml;
using Avalonia.Platform.Storage;
using Focus.Core;

namespace Focus.App;

/// The first-run question. Nothing is written to disk until it is answered.
public partial class WelcomeWindow : Window
{
    public WelcomeWindow()
    {
        InitializeComponent();
        this.FindControl<Button>("UseDefault")!.Content = $"Use {DataFolder.DefaultPath}";
    }

    private void InitializeComponent() => AvaloniaXamlLoader.Load(this);

    private async void Choose(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        var picked = await StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions
        {
            Title = "Choose a folder for your Focus data",
            AllowMultiple = false
        });

        var folder = picked.FirstOrDefault()?.TryGetLocalPath();
        if (string.IsNullOrEmpty(folder)) return;
        Close((folder, false));
    }

    private void UseTheDefault(object? sender, Avalonia.Interactivity.RoutedEventArgs e) =>
        Close((DataFolder.DefaultPath, false));
}
