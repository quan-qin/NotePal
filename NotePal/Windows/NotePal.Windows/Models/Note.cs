namespace NotePalWindows.Models;

public sealed class Note
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Title { get; set; } = "未命名笔记";
    public string Body { get; set; } = "";
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.Now;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.Now;

    public Note Clone()
    {
        return new Note
        {
            Id = Id,
            Title = Title,
            Body = Body,
            CreatedAt = CreatedAt,
            UpdatedAt = UpdatedAt
        };
    }
}
