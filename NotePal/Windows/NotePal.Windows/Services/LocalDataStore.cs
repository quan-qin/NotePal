using NotePalWindows.Models;
using System.IO;
using System.Text.Json;

namespace NotePalWindows.Services;

public sealed class LocalDataStore
{
    private readonly object _lock = new();
    private readonly JsonSerializerOptions _jsonOptions = JsonOptions.Create();
    private readonly string[] _legacyDataPaths;

    public LocalDataStore()
    {
        var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        DataPath = AppPaths.DataPath;
        _legacyDataPaths =
        [
            Path.Combine(appData, "NotePet", "notepet-data.json"),
            Path.Combine(appData, "NotePet-ath", "notepet-data.json"),
            Path.Combine(appData, "NotePet4xyz", "notepet4xyz-data.json"),
            Path.Combine(appData, "NotePet-zyzx", "notepet-zyzx-data.json")
        ];
        Data = Load();
    }

    public string DataPath { get; }
    public NotePalData Data { get; private set; }

    public NotePalData Update(Action<NotePalData> mutation)
    {
        lock (_lock)
        {
            mutation(Data);
            Normalize(Data);
            SaveUnlocked(Data);
            return Data;
        }
    }

    private NotePalData Load()
    {
        lock (_lock)
        {
            NotePalData data;
            if (File.Exists(DataPath))
            {
                data = LoadData(DataPath);
            }
            else
            {
                data = LoadMigratedLegacyData() ?? new NotePalData();
                Normalize(data);
                SaveUnlocked(data);
            }

            Normalize(data);
            return data;
        }
    }

    private NotePalData? LoadMigratedLegacyData()
    {
        var migrated = new NotePalData();
        var didLoad = false;

        foreach (var path in _legacyDataPaths.Where(File.Exists))
        {
            Merge(LoadData(path), migrated);
            didLoad = true;
        }

        return didLoad ? migrated : null;
    }

    private NotePalData LoadData(string path)
    {
        var json = File.ReadAllText(path);
        if (string.IsNullOrWhiteSpace(json))
        {
            return new NotePalData();
        }

        return JsonSerializer.Deserialize<NotePalData>(json, _jsonOptions) ?? new NotePalData();
    }

    private void SaveUnlocked(NotePalData data)
    {
        Directory.CreateDirectory(AppPaths.AppDataDirectory);
        var encoded = JsonSerializer.Serialize(data, _jsonOptions);
        var tempPath = $"{DataPath}.tmp";
        File.WriteAllText(tempPath, encoded);
        File.Move(tempPath, DataPath, overwrite: true);
    }

    private static void Merge(NotePalData incoming, NotePalData target)
    {
        Normalize(incoming);
        Normalize(target);

        foreach (var note in incoming.Notes)
        {
            var index = target.Notes.FindIndex(item => item.Id == note.Id);
            if (index < 0)
            {
                target.Notes.Add(note);
            }
            else if (target.Notes[index].UpdatedAt < note.UpdatedAt)
            {
                target.Notes[index] = note;
            }
        }

        foreach (var todo in incoming.Todos)
        {
            var index = target.Todos.FindIndex(item => item.Id == todo.Id);
            if (index < 0)
            {
                target.Todos.Add(todo);
            }
            else if (target.Todos[index].UpdatedAt < todo.UpdatedAt)
            {
                target.Todos[index] = todo;
            }
        }

        foreach (var reminder in incoming.WellnessReminders)
        {
            var index = target.WellnessReminders.FindIndex(item => item.Kind == reminder.Kind);
            if (index < 0)
            {
                target.WellnessReminders.Add(reminder);
            }
            else if (target.WellnessReminders[index].UpdatedAt < reminder.UpdatedAt)
            {
                target.WellnessReminders[index] = reminder;
            }
        }

        target.RemindedTodoRevisions.UnionWith(incoming.RemindedTodoRevisions);
    }

    public static void Normalize(NotePalData data)
    {
        data.Notes ??= [];
        data.Todos ??= [];
        data.RemindedTodoRevisions ??= [];
        data.WellnessReminders ??= [];

        var now = DateTimeOffset.Now;
        var remindersByKind = WellnessReminder.Defaults(now)
            .ToDictionary(reminder => reminder.Kind, reminder => reminder);

        foreach (var reminder in data.WellnessReminders)
        {
            var normalized = reminder.Clone();
            normalized.IntervalMinutes = normalized.EffectiveIntervalMinutes;
            remindersByKind[normalized.Kind] = normalized;
        }

        foreach (var legacyTodo in data.Todos.Where(todo => todo.IsWellnessTodo).ToList())
        {
            if (!WellnessReminderKindExtensions.TryParseRawValue(legacyTodo.WellnessKind, out var kind))
            {
                continue;
            }

            var interval = legacyTodo.EffectiveWellnessIntervalMinutes;
            remindersByKind[kind] = new WellnessReminder
            {
                Kind = kind,
                IsEnabled = !legacyTodo.IsCompleted,
                IntervalMinutes = interval,
                NextReminderAt = legacyTodo.DueDate ?? now.AddMinutes(interval),
                UpdatedAt = legacyTodo.UpdatedAt
            };
        }

        data.Todos.RemoveAll(todo => todo.IsWellnessTodo);
        data.WellnessReminders = Enum.GetValues<WellnessReminderKind>()
            .Select(kind => remindersByKind[kind])
            .ToList();

        var currentTodoKeys = data.Todos.Select(todo => todo.ReminderRevisionKey).ToHashSet();
        data.RemindedTodoRevisions.IntersectWith(currentTodoKeys);
    }
}

public static class JsonOptions
{
    public static JsonSerializerOptions Create()
    {
        var options = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            WriteIndented = true
        };
        options.Converters.Add(new WellnessReminderKindJsonConverter());
        options.Converters.Add(new PetThemeJsonConverter());
        return options;
    }
}
