using NotePalWindows.Models;
using System.Drawing;
using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace NotePalWindows.Services;

public sealed class PetAssetStore
{
    private readonly Dictionary<PetTheme, ImageSource> _imageCache = [];

    public ImageSource? ImageFor(PetTheme theme)
    {
        if (_imageCache.TryGetValue(theme, out var cached))
        {
            return cached;
        }

        ImageSource? image = theme.IsSpecial()
            ? LoadSpecialImage(theme)
            : LoadPublicImage(theme);

        if (image is not null)
        {
            _imageCache[theme] = image;
        }

        return image;
    }

    public PetTheme? UnlockSpecialTheme(string key)
    {
        var normalizedKey = EncryptedThemeAsset.NormalizeKey(key);
        if (string.IsNullOrWhiteSpace(normalizedKey))
        {
            return null;
        }

        foreach (var theme in new[] { PetTheme.SpecialA, PetTheme.SpecialB })
        {
            var image = DecryptImage(theme, normalizedKey);
            if (image is null)
            {
                continue;
            }

            ThemeCredentialStore.SaveKey(normalizedKey, theme);
            _imageCache[theme] = image;
            return theme;
        }

        return null;
    }

    public static Icon? LoadApplicationIcon()
    {
        var info = Application.GetResourceStream(new Uri("pack://application:,,,/Assets/NotePal.ico", UriKind.Absolute));
        if (info?.Stream is null)
        {
            return null;
        }

        using var stream = info.Stream;
        using var icon = new Icon(stream);
        return (Icon)icon.Clone();
    }

    private static ImageSource? LoadPublicImage(PetTheme theme)
    {
        try
        {
            var image = new BitmapImage(new Uri($"pack://application:,,,/Assets/{theme.ResourceName()}.png", UriKind.Absolute));
            image.Freeze();
            return image;
        }
        catch
        {
            return null;
        }
    }

    private ImageSource? LoadSpecialImage(PetTheme theme)
    {
        var savedKey = ThemeCredentialStore.SavedKey(theme);
        return savedKey is null ? null : DecryptImage(theme, savedKey);
    }

    private static ImageSource? DecryptImage(PetTheme theme, string key)
    {
        try
        {
            var encryptedData = LoadEncryptedData(theme);
            if (encryptedData is null)
            {
                return null;
            }

            var imageData = EncryptedThemeAsset.Decrypt(encryptedData, key);
            using var stream = new MemoryStream(imageData);
            var image = new BitmapImage();
            image.BeginInit();
            image.CacheOption = BitmapCacheOption.OnLoad;
            image.StreamSource = stream;
            image.EndInit();
            image.Freeze();
            return image;
        }
        catch
        {
            return null;
        }
    }

    private static byte[]? LoadEncryptedData(PetTheme theme)
    {
        var uri = new Uri($"pack://application:,,,/Assets/{theme.ResourceName()}.{EncryptedThemeAsset.FileExtension}", UriKind.Absolute);
        var info = Application.GetResourceStream(uri);
        if (info?.Stream is null)
        {
            return null;
        }

        using var stream = info.Stream;
        using var memory = new MemoryStream();
        stream.CopyTo(memory);
        return memory.ToArray();
    }
}
