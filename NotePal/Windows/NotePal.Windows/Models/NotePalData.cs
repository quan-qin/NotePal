namespace NotePalWindows.Models;

public sealed class NotePalData
{
    public List<Note> Notes { get; set; } = [];
    public List<TodoItem> Todos { get; set; } = [];
    public HashSet<string> RemindedTodoRevisions { get; set; } = [];
    public List<WellnessReminder> WellnessReminders { get; set; } = [];
}
