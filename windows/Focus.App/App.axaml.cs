using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Markup.Xaml;
using Focus.Core;

namespace Focus.App;

public partial class App : Application
{
    public override void Initialize() => AvaloniaXamlLoader.Load(this);

    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            // Nothing is written until the folder question has been answered, so
            // a first run cannot leave a stray folder behind if the user picks
            // somewhere else.
            if (DataFolder.IsChosen) DataFolder.EnsureExists();

            var shell = new Shell();
            desktop.MainWindow = new MainWindow(shell);
            // A note being typed when the app is closed must still reach its document.
            desktop.ShutdownRequested += (_, _) => shell.Notes.Flush();
        }

        base.OnFrameworkInitializationCompleted();
    }
}
