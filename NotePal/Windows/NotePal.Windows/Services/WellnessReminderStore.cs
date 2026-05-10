using NotePalWindows.Models;

namespace NotePalWindows.Services;

public sealed class WellnessReminderStore
{
    private readonly LocalDataStore _dataStore;

    public WellnessReminderStore(LocalDataStore dataStore)
    {
        _dataStore = dataStore;
        Reload();
    }

    public event EventHandler? Changed;
    public Action<string>? ErrorRaised { get; set; }
    public string? LastError { get; private set; }
    public IReadOnlyList<WellnessReminder> Reminders { get; private set; } = [];

    public void Reload()
    {
        try
        {
            var data = _dataStore.Update(LocalDataStore.Normalize);
            Reminders = Sort(data.WellnessReminders);
            ClearError();
        }
        catch (Exception ex)
        {
            SetError($"无法加载养生提醒：{ex.Message}");
        }
    }

    public void SetEnabled(WellnessReminderKind kind, bool isEnabled)
    {
        Persist(data =>
        {
            var reminder = EnsureReminder(data, kind);
            reminder.IsEnabled = isEnabled;
            reminder.UpdatedAt = DateTimeOffset.Now;
            if (isEnabled)
            {
                reminder.NextReminderAt = DateTimeOffset.Now.AddMinutes(reminder.EffectiveIntervalMinutes);
            }
        });
    }

    public void SetInterval(WellnessReminderKind kind, int minutes)
    {
        Persist(data =>
        {
            var reminder = EnsureReminder(data, kind);
            reminder.IntervalMinutes = Math.Clamp(minutes, 5, 1440);
            reminder.NextReminderAt = DateTimeOffset.Now.AddMinutes(reminder.EffectiveIntervalMinutes);
            reminder.UpdatedAt = DateTimeOffset.Now;
        });
    }

    public IReadOnlyList<WellnessReminder> DueReminders(DateTimeOffset asOf)
    {
        return Reminders
            .Where(reminder => reminder.IsEnabled && reminder.NextReminderAt <= asOf)
            .ToList();
    }

    public DateTimeOffset? NextDueDate(DateTimeOffset asOf)
    {
        return Reminders
            .Where(reminder => reminder.IsEnabled && reminder.NextReminderAt > asOf)
            .Select(reminder => (DateTimeOffset?)reminder.NextReminderAt)
            .Min();
    }

    public void AdvanceReminders(IEnumerable<WellnessReminder> reminders, DateTimeOffset from)
    {
        var kinds = reminders.Select(reminder => reminder.Kind).ToHashSet();
        if (kinds.Count == 0)
        {
            return;
        }

        Persist(data =>
        {
            foreach (var reminder in data.WellnessReminders.Where(reminder => kinds.Contains(reminder.Kind)))
            {
                reminder.NextReminderAt = from.AddMinutes(reminder.EffectiveIntervalMinutes);
                reminder.UpdatedAt = from;
            }
        });
    }

    private void Persist(Action<NotePalData> mutation)
    {
        try
        {
            var data = _dataStore.Update(data =>
            {
                LocalDataStore.Normalize(data);
                mutation(data);
            });
            Reminders = Sort(data.WellnessReminders);
            ClearError();
        }
        catch (Exception ex)
        {
            SetError($"无法保存养生提醒：{ex.Message}");
        }
    }

    private static WellnessReminder EnsureReminder(NotePalData data, WellnessReminderKind kind)
    {
        LocalDataStore.Normalize(data);
        var reminder = data.WellnessReminders.FirstOrDefault(item => item.Kind == kind);
        if (reminder is not null)
        {
            return reminder;
        }

        reminder = new WellnessReminder { Kind = kind };
        data.WellnessReminders.Add(reminder);
        return reminder;
    }

    private static IReadOnlyList<WellnessReminder> Sort(IEnumerable<WellnessReminder> reminders)
    {
        var order = Enum.GetValues<WellnessReminderKind>()
            .Select((kind, index) => new { kind, index })
            .ToDictionary(item => item.kind, item => item.index);

        return reminders
            .OrderBy(reminder => order.TryGetValue(reminder.Kind, out var index) ? index : 0)
            .Select(reminder => reminder.Clone())
            .ToList();
    }

    private void ClearError()
    {
        LastError = null;
        Changed?.Invoke(this, EventArgs.Empty);
    }

    private void SetError(string message)
    {
        LastError = message;
        ErrorRaised?.Invoke(message);
        Changed?.Invoke(this, EventArgs.Empty);
    }
}
