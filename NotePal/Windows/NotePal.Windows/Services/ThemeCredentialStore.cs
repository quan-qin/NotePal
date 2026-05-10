using NotePalWindows.Models;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;

namespace NotePalWindows.Services;

public static class ThemeCredentialStore
{
    private static readonly object Lock = new();
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };

    public static string? SavedKey(PetTheme theme)
    {
        if (!theme.IsSpecial())
        {
            return null;
        }

        lock (Lock)
        {
            var entries = LoadEntries();
            var protectedValue = theme.StoredKeyNames()
                .Select(keyName => entries.TryGetValue(keyName, out var value) ? value : null)
                .FirstOrDefault(value => value is not null);

            if (protectedValue is null)
            {
                return null;
            }

            try
            {
                var encrypted = Convert.FromBase64String(protectedValue);
                var raw = Dpapi.Unprotect(encrypted);
                var key = Encoding.UTF8.GetString(raw);
                return string.IsNullOrWhiteSpace(key) ? null : key;
            }
            catch
            {
                return null;
            }
        }
    }

    public static bool HasSavedKey(PetTheme theme)
    {
        return SavedKey(theme) is not null;
    }

    public static void SaveKey(string rawKey, PetTheme theme)
    {
        if (!theme.IsSpecial())
        {
            return;
        }

        var key = EncryptedThemeAsset.NormalizeKey(rawKey);
        if (string.IsNullOrWhiteSpace(key))
        {
            throw new InvalidOperationException("Theme key is empty.");
        }

        lock (Lock)
        {
            var entries = LoadEntries();
            var protectedData = Dpapi.Protect(Encoding.UTF8.GetBytes(key));
            entries[theme.ToRawValue()] = Convert.ToBase64String(protectedData);
            SaveEntries(entries);
        }
    }

    private static Dictionary<string, string> LoadEntries()
    {
        if (!File.Exists(AppPaths.ThemeKeysPath))
        {
            return [];
        }

        try
        {
            var json = File.ReadAllText(AppPaths.ThemeKeysPath);
            return JsonSerializer.Deserialize<Dictionary<string, string>>(json, JsonOptions) ?? [];
        }
        catch
        {
            return [];
        }
    }

    private static void SaveEntries(Dictionary<string, string> entries)
    {
        Directory.CreateDirectory(AppPaths.AppDataDirectory);
        var encoded = JsonSerializer.Serialize(entries, JsonOptions);
        var tempPath = $"{AppPaths.ThemeKeysPath}.tmp";
        File.WriteAllText(tempPath, encoded);
        File.Move(tempPath, AppPaths.ThemeKeysPath, overwrite: true);
    }
}

internal static class Dpapi
{
    private const int CryptProtectUiForbidden = 0x1;

    public static byte[] Protect(byte[] data)
    {
        return Transform(data, protect: true);
    }

    public static byte[] Unprotect(byte[] data)
    {
        return Transform(data, protect: false);
    }

    private static byte[] Transform(byte[] data, bool protect)
    {
        var input = CreateBlob(data);
        try
        {
            DataBlob output;
            bool success;
            if (protect)
            {
                success = CryptProtectData(
                    ref input,
                    null,
                    IntPtr.Zero,
                    IntPtr.Zero,
                    IntPtr.Zero,
                    CryptProtectUiForbidden,
                    out output);
            }
            else
            {
                success = CryptUnprotectData(
                    ref input,
                    IntPtr.Zero,
                    IntPtr.Zero,
                    IntPtr.Zero,
                    IntPtr.Zero,
                    CryptProtectUiForbidden,
                    out output);
            }

            if (!success)
            {
                throw new InvalidOperationException($"DPAPI failed with error {Marshal.GetLastWin32Error()}.");
            }

            try
            {
                var result = new byte[output.CbData];
                Marshal.Copy(output.PbData, result, 0, result.Length);
                return result;
            }
            finally
            {
                if (output.PbData != IntPtr.Zero)
                {
                    LocalFree(output.PbData);
                }
            }
        }
        finally
        {
            if (input.PbData != IntPtr.Zero)
            {
                Marshal.FreeHGlobal(input.PbData);
            }
        }
    }

    private static DataBlob CreateBlob(byte[] data)
    {
        var blob = new DataBlob
        {
            CbData = data.Length,
            PbData = Marshal.AllocHGlobal(data.Length)
        };
        Marshal.Copy(data, 0, blob.PbData, data.Length);
        return blob;
    }

    [DllImport("crypt32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CryptProtectData(
        ref DataBlob dataIn,
        string? dataDescription,
        IntPtr optionalEntropy,
        IntPtr reserved,
        IntPtr promptStruct,
        int flags,
        out DataBlob dataOut);

    [DllImport("crypt32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CryptUnprotectData(
        ref DataBlob dataIn,
        IntPtr dataDescription,
        IntPtr optionalEntropy,
        IntPtr reserved,
        IntPtr promptStruct,
        int flags,
        out DataBlob dataOut);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr LocalFree(IntPtr handle);

    [StructLayout(LayoutKind.Sequential)]
    private struct DataBlob
    {
        public int CbData;
        public IntPtr PbData;
    }
}
