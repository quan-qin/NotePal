using System.Text.Json;
using System.Text.Json.Serialization;

namespace NotePalWindows.Models;

public enum PetTheme
{
    Newton,
    Confucius,
    SpecialA,
    SpecialB
}

public static class PetThemeExtensions
{
    public static string ToRawValue(this PetTheme theme)
    {
        return theme switch
        {
            PetTheme.Newton => "newton",
            PetTheme.Confucius => "confucius",
            PetTheme.SpecialA => "specialA",
            PetTheme.SpecialB => "specialB",
            _ => "newton"
        };
    }

    public static IReadOnlyList<string> StoredKeyNames(this PetTheme theme)
    {
        return theme switch
        {
            PetTheme.SpecialA => [theme.ToRawValue(), string.Concat("academic", "Special")],
            PetTheme.SpecialB => [theme.ToRawValue(), string.Concat("wed", "ding", "Special")],
            _ => [theme.ToRawValue()]
        };
    }

    public static string DisplayName(this PetTheme theme)
    {
        return theme switch
        {
            PetTheme.Newton => "Default Theme",
            PetTheme.Confucius => "Classic Theme",
            PetTheme.SpecialA => "Special Theme A",
            PetTheme.SpecialB => "Special Theme B",
            _ => "NotePal"
        };
    }

    public static string ResourceName(this PetTheme theme)
    {
        return theme switch
        {
            PetTheme.Newton => "Newton",
            PetTheme.Confucius => "Kongzi",
            PetTheme.SpecialA => "SpecialThemeA",
            PetTheme.SpecialB => "SpecialThemeB",
            _ => "Newton"
        };
    }

    public static bool IsSpecial(this PetTheme theme)
    {
        return theme is PetTheme.SpecialA or PetTheme.SpecialB;
    }

    public static string SleepyPhrase(this PetTheme theme)
    {
        return theme switch
        {
            PetTheme.Newton => "我会安静思考一会儿。",
            PetTheme.Confucius => "吾少也贱，故多能鄙事。",
            PetTheme.SpecialA => "我会安静待在这里。",
            PetTheme.SpecialB => "我会安静待在这里。",
            _ => "我会安静待在这里。"
        };
    }

    public static string CompletionPhrase(this PetTheme theme)
    {
        return theme switch
        {
            PetTheme.Newton => "完成一个待办，惯性被你打破了。",
            PetTheme.Confucius => "温故知新，又进一程。",
            PetTheme.SpecialA => "完成一个待办。",
            PetTheme.SpecialB => "完成一个待办。",
            _ => "完成一个待办。"
        };
    }

    public static string DefaultGreeting(this PetTheme theme)
    {
        return theme switch
        {
            PetTheme.Newton => "从一颗苹果开始，也能想到整片天空。",
            PetTheme.Confucius => "学而时习之，不亦说乎。",
            PetTheme.SpecialA => "最近进展如何？",
            PetTheme.SpecialB => "最近进展如何？",
            _ => "你好。"
        };
    }

    public static bool TryParseRawValue(string? rawValue, out PetTheme theme)
    {
        theme = PetTheme.Newton;
        if (string.IsNullOrWhiteSpace(rawValue))
        {
            return false;
        }

        switch (rawValue.Trim())
        {
            case "newton":
                theme = PetTheme.Newton;
                return true;
            case "confucius":
                theme = PetTheme.Confucius;
                return true;
            case "specialA":
                theme = PetTheme.SpecialA;
                return true;
            case "specialB":
                theme = PetTheme.SpecialB;
                return true;
            case var legacy when legacy == string.Concat("academic", "Special"):
                theme = PetTheme.SpecialA;
                return true;
            case var legacy when legacy == string.Concat("wed", "ding", "Special"):
                theme = PetTheme.SpecialB;
                return true;
            default:
                return Enum.TryParse(rawValue, ignoreCase: true, out theme);
        }
    }
}

public sealed class PetThemeJsonConverter : JsonConverter<PetTheme>
{
    public override PetTheme Read(
        ref Utf8JsonReader reader,
        Type typeToConvert,
        JsonSerializerOptions options)
    {
        if (reader.TokenType == JsonTokenType.String
            && PetThemeExtensions.TryParseRawValue(reader.GetString(), out var theme))
        {
            return theme;
        }

        if (reader.TokenType == JsonTokenType.Number && reader.TryGetInt32(out var value))
        {
            return Enum.IsDefined(typeof(PetTheme), value) ? (PetTheme)value : PetTheme.Newton;
        }

        return PetTheme.Newton;
    }

    public override void Write(Utf8JsonWriter writer, PetTheme value, JsonSerializerOptions options)
    {
        writer.WriteStringValue(value.ToRawValue());
    }
}
