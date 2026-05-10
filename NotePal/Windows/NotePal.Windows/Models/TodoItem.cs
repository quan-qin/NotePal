using System.Globalization;

namespace NotePalWindows.Models;

public sealed class TodoItem
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Title { get; set; } = "新待办";
    public string? Description { get; set; }
    public bool IsCompleted { get; set; }
    public DateTimeOffset? DueDate { get; set; }
    public string? WellnessKind { get; set; }
    public int? WellnessReminderIntervalMinutes { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.Now;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.Now;

    public bool IsWellnessTodo => WellnessKind is not null;

    public int EffectiveWellnessIntervalMinutes => Math.Max(5, WellnessReminderIntervalMinutes ?? 60);

    public string ReminderRevisionKey
    {
        get
        {
            var dueStamp = DueDate?.ToUnixTimeSeconds().ToString(CultureInfo.InvariantCulture) ?? "none";
            var updatedStamp = UpdatedAt.ToUnixTimeMilliseconds().ToString(CultureInfo.InvariantCulture);
            if (!IsWellnessTodo)
            {
                return $"v2|{Id.ToString().ToUpperInvariant()}|{dueStamp}|{updatedStamp}";
            }

            var wellnessStamp = WellnessKind ?? "regular";
            var intervalStamp = WellnessReminderIntervalMinutes?.ToString(CultureInfo.InvariantCulture) ?? "none";
            return $"v3|{Id.ToString().ToUpperInvariant()}|{dueStamp}|{updatedStamp}|{wellnessStamp}|{intervalStamp}";
        }
    }

    public bool IsDue(DateTimeOffset asOf)
    {
        return DueDate is not null && !IsCompleted && DueDate <= asOf;
    }

    public TodoItem Clone()
    {
        return new TodoItem
        {
            Id = Id,
            Title = Title,
            Description = Description,
            IsCompleted = IsCompleted,
            DueDate = DueDate,
            WellnessKind = WellnessKind,
            WellnessReminderIntervalMinutes = WellnessReminderIntervalMinutes,
            CreatedAt = CreatedAt,
            UpdatedAt = UpdatedAt
        };
    }
}
