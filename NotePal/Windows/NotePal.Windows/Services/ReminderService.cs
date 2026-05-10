using NotePalWindows.Models;
using System.Windows.Threading;

namespace NotePalWindows.Services;

public sealed class ReminderEventArgs : EventArgs
{
    public ReminderEventArgs(string message, IReadOnlyList<TodoItem> dueTodos)
    {
        Message = message;
        DueTodos = dueTodos;
    }

    public string Message { get; }
    public IReadOnlyList<TodoItem> DueTodos { get; }
}

public sealed class ReminderService
{
    private readonly TodoStore _todoStore;
    private readonly DispatcherTimer _deadlineTimer = new();
    private readonly DispatcherTimer _safetyTimer = new();
    private bool _isChecking;

    public ReminderService(TodoStore todoStore)
    {
        _todoStore = todoStore;
        _deadlineTimer.Tick += (_, _) => CheckAndReschedule();
        _safetyTimer.Interval = TimeSpan.FromMinutes(1);
        _safetyTimer.Tick += (_, _) => CheckAndReschedule();
        _todoStore.Changed += (_, _) => CheckAndReschedule();
    }

    public event EventHandler<ReminderEventArgs>? ReminderDue;

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
            var dueTodos = _todoStore.DueTodosNeedingReminder(asOf);
            if (dueTodos.Count == 0)
            {
                return;
            }

            var message = dueTodos.Count == 1
                ? $"待办到期：{dueTodos[0].Title}"
                : $"{dueTodos.Count} 个待办已到期。";

            ReminderDue?.Invoke(this, new ReminderEventArgs(message, dueTodos));
            _todoStore.MarkReminded(dueTodos);
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
        var nextDueDate = _todoStore.NextUnremindedDueDate(now);
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
