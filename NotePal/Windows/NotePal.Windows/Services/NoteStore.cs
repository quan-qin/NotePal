using NotePalWindows.Models;

namespace NotePalWindows.Services;

public sealed class NoteStore
{
    private readonly LocalDataStore _dataStore;

    public NoteStore(LocalDataStore dataStore)
    {
        _dataStore = dataStore;
    }

    public event EventHandler? Changed;
    public Action<string>? ErrorRaised { get; set; }
    public string? LastError { get; private set; }
    public IReadOnlyList<Note> Notes => _dataStore.Data.Notes
        .OrderByDescending(note => note.UpdatedAt)
        .ToList();

    public Note? CreateNote()
    {
        try
        {
            var note = new Note();
            _dataStore.Update(data => data.Notes.Insert(0, note));
            ClearError();
            return note;
        }
        catch (Exception ex)
        {
            SetError($"无法保存笔记：{ex.Message}");
            return null;
        }
    }

    public void UpdateNote(Note note)
    {
        try
        {
            var updated = note.Clone();
            updated.Title = string.IsNullOrWhiteSpace(updated.Title) ? "未命名笔记" : updated.Title.Trim();
            updated.UpdatedAt = DateTimeOffset.Now;
            _dataStore.Update(data =>
            {
                var index = data.Notes.FindIndex(item => item.Id == updated.Id);
                if (index >= 0)
                {
                    data.Notes[index] = updated;
                }
            });
            ClearError();
        }
        catch (Exception ex)
        {
            SetError($"无法保存笔记：{ex.Message}");
        }
    }

    public void DeleteNote(Guid id)
    {
        try
        {
            _dataStore.Update(data => data.Notes.RemoveAll(note => note.Id == id));
            ClearError();
        }
        catch (Exception ex)
        {
            SetError($"无法删除笔记：{ex.Message}");
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
