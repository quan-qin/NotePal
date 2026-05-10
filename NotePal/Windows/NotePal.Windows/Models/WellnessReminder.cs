using System.Text.Json;
using System.Text.Json.Serialization;

namespace NotePalWindows.Models;

public enum WellnessReminderKind
{
    DrinkWater,
    StandKegel,
    LookFar
}

public sealed class WellnessReminder
{
    public WellnessReminderKind Kind { get; set; }
    public bool IsEnabled { get; set; } = true;
    public int IntervalMinutes { get; set; } = 60;
    public DateTimeOffset NextReminderAt { get; set; } = DateTimeOffset.Now.AddHours(1);
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.Now;

    public string Id => Kind.ToRawValue();
    public string Title => Kind.Title();
    public string Message => Kind.Message();
    public int EffectiveIntervalMinutes => Math.Clamp(IntervalMinutes, 5, 1440);

    public WellnessReminder Clone()
    {
        return new WellnessReminder
        {
            Kind = Kind,
            IsEnabled = IsEnabled,
            IntervalMinutes = IntervalMinutes,
            NextReminderAt = NextReminderAt,
            UpdatedAt = UpdatedAt
        };
    }

    public static List<WellnessReminder> Defaults(DateTimeOffset? now = null)
    {
        var timestamp = now ?? DateTimeOffset.Now;
        return Enum.GetValues<WellnessReminderKind>()
            .Select(kind => new WellnessReminder
            {
                Kind = kind,
                IsEnabled = true,
                IntervalMinutes = 60,
                NextReminderAt = timestamp.AddHours(1),
                UpdatedAt = timestamp
            })
            .ToList();
    }
}

public static class WellnessReminderKindExtensions
{
    public static string ToRawValue(this WellnessReminderKind kind)
    {
        return kind switch
        {
            WellnessReminderKind.DrinkWater => "drinkWater",
            WellnessReminderKind.StandKegel => "standKegel",
            WellnessReminderKind.LookFar => "lookFar",
            _ => "drinkWater"
        };
    }

    public static string Title(this WellnessReminderKind kind)
    {
        return kind switch
        {
            WellnessReminderKind.DrinkWater => "提醒喝水",
            WellnessReminderKind.StandKegel => "提醒站立提肛",
            WellnessReminderKind.LookFar => "远眺养眼",
            _ => "养生提醒"
        };
    }

    public static string Message(this WellnessReminderKind kind)
    {
        return kind switch
        {
            WellnessReminderKind.DrinkWater => "该喝点水了。",
            WellnessReminderKind.StandKegel => "站起来活动一下，做一组提肛。",
            WellnessReminderKind.LookFar => "远眺一下，放松眼睛。",
            _ => "养生提醒到了。"
        };
    }

    public static bool TryParseRawValue(string? rawValue, out WellnessReminderKind kind)
    {
        kind = WellnessReminderKind.DrinkWater;
        if (string.IsNullOrWhiteSpace(rawValue))
        {
            return false;
        }

        switch (rawValue.Trim())
        {
            case "drinkWater":
                kind = WellnessReminderKind.DrinkWater;
                return true;
            case "standKegel":
                kind = WellnessReminderKind.StandKegel;
                return true;
            case "lookFar":
                kind = WellnessReminderKind.LookFar;
                return true;
            default:
                return Enum.TryParse(rawValue, ignoreCase: true, out kind);
        }
    }
}

public sealed class WellnessReminderKindJsonConverter : JsonConverter<WellnessReminderKind>
{
    public override WellnessReminderKind Read(
        ref Utf8JsonReader reader,
        Type typeToConvert,
        JsonSerializerOptions options)
    {
        if (reader.TokenType == JsonTokenType.String
            && WellnessReminderKindExtensions.TryParseRawValue(reader.GetString(), out var kind))
        {
            return kind;
        }

        if (reader.TokenType == JsonTokenType.Number && reader.TryGetInt32(out var value))
        {
            return Enum.IsDefined(typeof(WellnessReminderKind), value)
                ? (WellnessReminderKind)value
                : WellnessReminderKind.DrinkWater;
        }

        return WellnessReminderKind.DrinkWater;
    }

    public override void Write(
        Utf8JsonWriter writer,
        WellnessReminderKind value,
        JsonSerializerOptions options)
    {
        writer.WriteStringValue(value.ToRawValue());
    }
}
