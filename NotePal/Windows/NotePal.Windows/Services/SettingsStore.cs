using NotePalWindows.Models;
using System.IO;
using System.Text.Json;

namespace NotePalWindows.Services;

public sealed class SettingsStore
{
    private readonly JsonSerializerOptions _jsonOptions = JsonOptions.Create();

    public SettingsStore()
    {
        Settings = Load();
        Settings.SelectedPetTheme = PetTheme.Newton;
        Save();
    }

    public event EventHandler? Changed;
    public AppSettings Settings { get; private set; }

    public PetTheme SelectedPetTheme => IsUnlocked(Settings.SelectedPetTheme)
        ? Settings.SelectedPetTheme
        : PetTheme.Newton;

    public bool AnimationsEnabled => Settings.AnimationsEnabled;
    public bool ReducedMotionMode => Settings.ReducedMotionMode;
    public bool MuteNonCriticalDialogue => Settings.MuteNonCriticalDialogue;
    public TimeSpan IdleToSleepDuration => TimeSpan.FromSeconds(Math.Max(0, Settings.IdleToSleepSeconds));
    public TimeSpan ReminderBubbleDuration => TimeSpan.FromSeconds(Math.Clamp(Settings.ReminderBubbleSeconds, 1, 60));
    public TimeSpan GeneralBubbleDuration => TimeSpan.FromSeconds(Math.Clamp(Settings.GeneralBubbleSeconds, 1, 60));
    public double PetSize => Math.Clamp(Settings.PetSize, 64, 117);

    public bool IsUnlocked(PetTheme theme)
    {
        return !theme.IsSpecial()
            || (Settings.UnlockedSpecialThemes.Contains(theme) && ThemeCredentialStore.HasSavedKey(theme));
    }

    public bool SelectTheme(PetTheme theme)
    {
        if (!IsUnlocked(theme))
        {
            return false;
        }

        Settings.SelectedPetTheme = theme;
        SaveAndNotify();
        return true;
    }

    public void Unlock(PetTheme theme)
    {
        if (!theme.IsSpecial())
        {
            return;
        }

        Settings.UnlockedSpecialThemes.Add(theme);
        Settings.SelectedPetTheme = theme;
        SaveAndNotify();
    }

    public void SetMuteNonCriticalDialogue(bool isMuted)
    {
        Settings.MuteNonCriticalDialogue = isMuted;
        SaveAndNotify();
    }

    public void SetAnimationsEnabled(bool isEnabled)
    {
        Settings.AnimationsEnabled = isEnabled;
        SaveAndNotify();
    }

    private AppSettings Load()
    {
        try
        {
            if (!File.Exists(AppPaths.SettingsPath))
            {
                return new AppSettings();
            }

            var json = File.ReadAllText(AppPaths.SettingsPath);
            if (string.IsNullOrWhiteSpace(json))
            {
                return new AppSettings();
            }

            var settings = JsonSerializer.Deserialize<AppSettings>(json, _jsonOptions) ?? new AppSettings();
            settings.UnlockedSpecialThemes ??= [];
            settings.PetSize = Math.Clamp(settings.PetSize, 64, 117);
            settings.ReminderBubbleSeconds = Math.Clamp(settings.ReminderBubbleSeconds, 1, 60);
            settings.GeneralBubbleSeconds = Math.Clamp(settings.GeneralBubbleSeconds, 1, 60);
            settings.IdleToSleepSeconds = Math.Max(0, settings.IdleToSleepSeconds);
            return settings;
        }
        catch
        {
            return new AppSettings();
        }
    }

    private void SaveAndNotify()
    {
        Save();
        Changed?.Invoke(this, EventArgs.Empty);
    }

    private void Save()
    {
        Directory.CreateDirectory(AppPaths.AppDataDirectory);
        var encoded = JsonSerializer.Serialize(Settings, _jsonOptions);
        var tempPath = $"{AppPaths.SettingsPath}.tmp";
        File.WriteAllText(tempPath, encoded);
        File.Move(tempPath, AppPaths.SettingsPath, overwrite: true);
    }
}
