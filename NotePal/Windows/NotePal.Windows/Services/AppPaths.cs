using System.IO;

namespace NotePalWindows.Services;

public static class AppPaths
{
    public static string AppDataDirectory
    {
        get
        {
            var appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            return Path.Combine(appData, "NotePal");
        }
    }

    public static string DataPath => Path.Combine(AppDataDirectory, "notepal-data.json");
    public static string SettingsPath => Path.Combine(AppDataDirectory, "settings.json");
    public static string ThemeKeysPath => Path.Combine(AppDataDirectory, "theme-keys.json");
}
