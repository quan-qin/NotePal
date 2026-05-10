using NotePalWindows.Models;

namespace NotePalWindows.Services;

public sealed class TodoStore
{
    private readonly LocalDataStore _dataStore;

    public TodoStore(LocalDataStore dataStore)
    {
        _dataStore = dataStore;
    }

    public event EventHandler? Changed;
    public event EventHandler<TodoItem>? TodoCompleted;
    public Action<string>? ErrorRaised { get; set; }
    public string? LastError { get; private set; }
    public IReadOnlyList<TodoItem> Todos => _dataStore.Data.Todos
        .Where(todo => !todo.IsWellnessTodo)
        .OrderBy(todo => todo.IsCompleted)
        .ThenBy(todo => todo.DueDate ?? DateTimeOffset.MaxValue)
        .ThenByDescending(todo => todo.UpdatedAt)
        .ToList();
    public IReadOnlySet<string> RemindedTodoRevisions => _dataStore.Data.RemindedTodoRevisions;
    public int IncompleteCount => _dataStore.Data.Todos.Count(todo => !todo.IsCompleted && !todo.IsWellnessTodo);

    public TodoItem? CreateTodo()
    {
        try
        {
            var todo = new TodoItem();
            _dataStore.Update(data => data.Todos.Insert(0, todo));
            ClearError();
            return todo;
        }
        catch (Exception ex)
        {
            SetError($"无法保存待办：{ex.Message}");
            return null;
        }
    }

    public void UpdateTodo(TodoItem todo)
    {
        try
        {
            var existing = _dataStore.Data.Todos.FirstOrDefault(item => item.Id == todo.Id);
            var wasCompleted = existing?.IsCompleted == true;
            var updated = todo.Clone();
            updated.Title = string.IsNullOrWhiteSpace(updated.Title) ? "新待办" : updated.Title.Trim();
            updated.Description = string.IsNullOrWhiteSpace(updated.Description) ? null : updated.Description;
            updated.UpdatedAt = DateTimeOffset.Now;
            updated.WellnessKind = null;
            updated.WellnessReminderIntervalMinutes = null;

            _dataStore.Update(data =>
            {
                var index = data.Todos.FindIndex(item => item.Id == updated.Id);
                if (index >= 0)
                {
                    data.Todos[index] = updated;
                }
            });

            ClearError();
            if (!wasCompleted && updated.IsCompleted)
            {
                TodoCompleted?.Invoke(this, updated);
            }
        }
        catch (Exception ex)
        {
            SetError($"无法保存待办：{ex.Message}");
        }
    }

    public void DeleteTodo(Guid id)
    {
        try
        {
            _dataStore.Update(data => data.Todos.RemoveAll(todo => todo.Id == id));
            ClearError();
        }
        catch (Exception ex)
        {
            SetError($"无法删除待办：{ex.Message}");
        }
    }

    public IReadOnlyList<TodoItem> DueTodosNeedingReminder(DateTimeOffset asOf)
    {
        return _dataStore.Data.Todos
            .Where(todo => !todo.IsWellnessTodo
                && todo.IsDue(asOf)
                && !_dataStore.Data.RemindedTodoRevisions.Contains(todo.ReminderRevisionKey))
            .ToList();
    }

    public DateTimeOffset? NextUnremindedDueDate(DateTimeOffset asOf)
    {
        return _dataStore.Data.Todos
            .Where(todo => !todo.IsWellnessTodo
                && todo.DueDate is not null
                && !todo.IsCompleted
                && todo.DueDate > asOf
                && !_dataStore.Data.RemindedTodoRevisions.Contains(todo.ReminderRevisionKey))
            .Select(todo => (DateTimeOffset?)todo.DueDate!.Value)
            .Min();
    }

    public void MarkReminded(IEnumerable<TodoItem> todos)
    {
        try
        {
            var revisions = todos
                .Where(todo => !todo.IsWellnessTodo)
                .Select(todo => todo.ReminderRevisionKey)
                .ToList();

            if (revisions.Count == 0)
            {
                return;
            }

            _dataStore.Update(data =>
            {
                foreach (var revision in revisions)
                {
                    data.RemindedTodoRevisions.Add(revision);
                }
            });
            ClearError();
        }
        catch (Exception ex)
        {
            SetError($"无法保存提醒状态：{ex.Message}");
        }
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
