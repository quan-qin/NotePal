namespace NotePalWindows.Services;

public sealed class SpeechBubbleMessage
{
    public enum MessageKind
    {
        Reminder,
        Error,
        Mentor,
        Sleepy,
        Completion
    }

    public MessageKind Kind { get; init; }
    public string Text { get; init; } = "";
    public TimeSpan Duration { get; init; } = TimeSpan.FromSeconds(4);
    public bool IsCritical { get; init; }
    public Action? OnClick { get; init; }
}

public sealed class SpeechBubbleManager
{
    private readonly SettingsStore _settingsStore;
    private readonly Queue<SpeechBubbleMessage> _queue = new();
    private readonly Func<SpeechBubbleMessage, Action<bool>, bool> _present;
    private bool _isShowing;

    public SpeechBubbleManager(
        SettingsStore settingsStore,
        Func<SpeechBubbleMessage, Action<bool>, bool> present)
    {
        _settingsStore = settingsStore;
        _present = present;
    }

    public void Enqueue(SpeechBubbleMessage message)
    {
        if (!message.IsCritical && _settingsStore.MuteNonCriticalDialogue)
        {
            return;
        }

        _queue.Enqueue(message);
        PresentNextIfNeeded();
    }

    private void PresentNextIfNeeded()
    {
        if (_isShowing || _queue.Count == 0)
        {
            return;
        }

        _isShowing = true;
        var message = _queue.Dequeue();
        var didShow = _present(message, _ =>
        {
            _isShowing = false;
            PresentNextIfNeeded();
        });

        if (!didShow)
        {
            _isShowing = false;
            PresentNextIfNeeded();
        }
    }
}
