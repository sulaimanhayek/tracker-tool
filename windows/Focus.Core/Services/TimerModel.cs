using System.Globalization;

namespace Focus.Core;

/// The countdown. Time left is derived from a wall-clock deadline rather than
/// counted down by the tick, so a missed tick — or a sleeping PC — cannot make
/// the timer drift away from the clock.
///
/// Nothing in here owns a thread: the view drives `Tick`, which keeps the model
/// deterministic and lets the checks run it a day at a time.
public sealed class TimerModel : Observable
{
    private readonly SessionLog _log;
    private readonly ThemeStore _themes;
    private readonly Func<DateTime> _now;

    private TimerMode _mode = TimerMode.Focus;
    private double _remaining;
    private bool _isRunning;
    private int _completedRounds;

    private DateTime? _segmentStart;
    private DateTime? _deadline;

    public Dictionary<TimerMode, int> Durations { get; } = new();

    public TimerMode Mode { get => _mode; private set { if (Set(ref _mode, value)) Raise(nameof(Total)); } }
    public double Remaining { get => _remaining; private set { if (Set(ref _remaining, value)) Raise(nameof(Progress)); } }
    public bool IsRunning { get => _isRunning; private set => Set(ref _isRunning, value); }
    public int CompletedRounds { get => _completedRounds; private set => Set(ref _completedRounds, value); }

    public double Total => (Durations.GetValueOrDefault(Mode, Mode.DefaultMinutes())) * 60.0;
    public double Progress => Total > 0 ? Remaining / Total : 0;

    /// Raised when a stretch runs out, so the view can say so.
    public event Action<TimerMode>? Completed;

    public TimerModel(SessionLog log, ThemeStore themes, Func<DateTime>? now = null)
    {
        _log = log;
        _themes = themes;
        _now = now ?? (() => DateTime.Now);

        foreach (var mode in TimerModes.All)
        {
            var stored = Prefs.GetInt($"duration.{mode.Key()}");
            Durations[mode] = stored > 0 ? stored : mode.DefaultMinutes();
        }

        _remaining = Durations[TimerMode.Focus] * 60.0;
        _completedRounds = RoundsSoFarToday();
    }

    /// The round count is a today figure, so it starts again on a new day.
    private int RoundsSoFarToday() =>
        Prefs.GetString("roundsDate") == Today() ? Prefs.GetInt("completedRoundsToday") : 0;

    private string Today() => _now().ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

    public void Toggle() { if (IsRunning) Pause(); else Start(); }

    public void Start()
    {
        if (IsRunning) return;
        _deadline = _now().AddSeconds(Remaining);
        _segmentStart ??= _now();
        IsRunning = true;
        Sounds.Tick();
    }

    public void Pause()
    {
        if (!IsRunning) return;
        StopTicking();
        // Pausing banks the focus time already earned, so a long pause is not
        // silently counted as work when the session is later finished.
        RecordSegment(false);
    }

    public void Reset()
    {
        StopTicking();
        RecordSegment(false);
        Remaining = Total;
    }

    public void Select(TimerMode mode)
    {
        if (mode == Mode) return;
        StopTicking();
        RecordSegment(false);
        Mode = mode;
        Remaining = Total;
    }

    public void SetDuration(TimerMode mode, int minutes)
    {
        Durations[mode] = Math.Max(1, Math.Min(480, minutes));
        Prefs.Set($"duration.{mode.Key()}", Durations[mode]);
        Raise(nameof(Durations));
        Raise(nameof(Total));
        ApplyDurationChange();
    }

    public void ApplyDurationChange()
    {
        if (IsRunning) return;
        Remaining = Total;
    }

    /// Called by the view a few times a second. Anything that has happened to
    /// the clock in between — a sleep, a stall — is simply read off it.
    public void Tick()
    {
        if (_deadline is null) return;
        Remaining = Math.Max(0, (_deadline.Value - _now()).TotalSeconds);
        if (Remaining <= 0) Complete();
    }

    private void StopTicking()
    {
        if (IsRunning && _deadline is not null)
            Remaining = Math.Max(0, (_deadline.Value - _now()).TotalSeconds);
        IsRunning = false;
        _deadline = null;
    }

    private void Complete()
    {
        var finished = Mode;
        StopTicking();
        RecordSegment(true);
        Sounds.Alarm();

        if (Mode == TimerMode.Focus)
        {
            CompletedRounds = RoundsSoFarToday() + 1;
            Prefs.Set("completedRoundsToday", CompletedRounds);
            Prefs.Set("roundsDate", Today());
            Mode = CompletedRounds % TimerModes.RoundsBeforeLongBreak == 0
                ? TimerMode.LongBreak
                : TimerMode.ShortBreak;
        }
        else
        {
            Mode = TimerMode.Focus;
        }

        Remaining = Total;
        Completed?.Invoke(finished);
    }

    /// Writes the focus time earned since the timer was last started. Breaks are
    /// not logged, and neither is a stretch too short to be meaningful.
    private void RecordSegment(bool completed)
    {
        var start = _segmentStart;
        _segmentStart = null;
        if (!Mode.IsTracked() || start is null) return;

        var end = _now();
        if ((end - start.Value).TotalSeconds < 60) return;
        _log.Append(new Session(start.Value, end, _themes.Selected ?? "", completed));
    }
}
