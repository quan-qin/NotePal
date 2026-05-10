using NotePalWindows.Models;
using System.Windows.Threading;

namespace NotePalWindows.Services;

public sealed class WellnessReminderEventArgs : EventArgs
{
    public WellnessReminderEventArgs(string message, IReadOnlyList<WellnessReminder> reminders)
    {
        Message = message;
        Reminders = reminders;
    }

    public string Message { get; }
    public IReadOnlyList<WellnessReminder> Reminders { get; }
}

public sealed class WellnessReminderManager
{
    private readonly WellnessReminderStore _store;
    private readonly DispatcherTimer _deadlineTimer = new();
    private readonly DispatcherTimer _safetyTimer = new();
    private bool _isChecking;

    public WellnessReminderManager(WellnessReminderStore store)
    {
        _store = store;
        _deadlineTimer.Tick += (_, _) => CheckAndReschedule();
        _safetyTimer.Interval = TimeSpan.FromMinutes(1);
        _safetyTimer.Tick += (_, _) => CheckAndReschedule();
        _store.Changed += (_, _) => CheckAndReschedule();
    }

    public event EventHandler<WellnessReminderEventArgs>? ReminderDue;

    public void Start()
    {
        CheckAndReschedule();
        _safetyTimer.Start();
    }

    public void Stop()
    {
        _deadlineTimer.Stop();
        _safetyTimer.Stop();
    }

    private void CheckAndReschedule()
    {
        CheckReminders(DateTimeOffset.Now);
        ScheduleNextDeadlineCheck();
    }

    private void CheckReminders(DateTimeOffset asOf)
    {
        if (_isChecking)
        {
            return;
        }

        _isChecking = true;
        try
        {
            var dueReminders = _store.DueReminders(asOf);
            if (dueReminders.Count == 0)
            {
                return;
            }

            var message = dueReminders.Count == 1
                ? dueReminders[0].Message
                : $"{dueReminders.Count} 个养生提醒到了。";

            ReminderDue?.Invoke(this, new WellnessReminderEventArgs(message, dueReminders));
            _store.AdvanceReminders(dueReminders, DateTimeOffset.Now);
        }
        finally
        {
            _isChecking = false;
        }
    }

    private void ScheduleNextDeadlineCheck()
    {
        _deadlineTimer.Stop();

        var now = DateTimeOffset.Now;
        var nextDueDate = _store.NextDueDate(now);
        if (nextDueDate is null)
        {
            return;
        }

        var interval = nextDueDate.Value - now;
        _deadlineTimer.Interval = interval <= TimeSpan.Zero
            ? TimeSpan.FromMilliseconds(50)
            : interval;
        _deadlineTimer.Start();
    }
}
