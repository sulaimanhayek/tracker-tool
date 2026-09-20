namespace Focus.Core;

public enum TimerMode { Focus, ShortBreak, LongBreak }

public static class TimerModes
{
    /// Focus rounds completed before a long break is suggested.
    public const int RoundsBeforeLongBreak = 4;

    public static readonly TimerMode[] All = { TimerMode.Focus, TimerMode.ShortBreak, TimerMode.LongBreak };

    /// The wire name, shared with the Mac app's preference keys.
    public static string Key(this TimerMode mode) => mode switch
    {
        TimerMode.Focus => "focus",
        TimerMode.ShortBreak => "shortBreak",
        _ => "longBreak"
    };

    public static string Label(this TimerMode mode) => mode switch
    {
        TimerMode.Focus => "Focus",
        TimerMode.ShortBreak => "Short Break",
        _ => "Long Break"
    };

    public static int DefaultMinutes(this TimerMode mode) => mode switch
    {
        TimerMode.Focus => 60,
        TimerMode.ShortBreak => 5,
        _ => 15
    };

    /// Only focus time is tracked; breaks are not work.
    public static bool IsTracked(this TimerMode mode) => mode == TimerMode.Focus;
}
