using System.Security.Cryptography;
using System.Text;

namespace NotePalWindows.Services;

public static class EncryptedThemeAsset
{
    public const string FileExtension = "notepalasset";

    private static readonly byte[] Magic = Encoding.UTF8.GetBytes("NPETASSET1");
    // Keep the original associated data so existing encrypted theme assets remain readable.
    private static readonly byte[] AssociatedData = Encoding.UTF8.GetBytes("NotePet encrypted theme asset v1");
    private const int SaltByteCount = 16;
    private const int NonceByteCount = 12;
    private const int TagByteCount = 16;
    private const int KeyByteCount = 32;
    private const int KeyDerivationRounds = 180_000;

    public static string NormalizeKey(string key)
    {
        return key.Trim().ToLowerInvariant();
    }

    public static byte[] Decrypt(byte[] encryptedData, string rawKey)
    {
        var keyText = NormalizeKey(rawKey);
        if (keyText.Length == 0)
        {
            throw new InvalidOperationException("Theme key is empty.");
        }

        var minimumByteCount = Magic.Length + SaltByteCount + NonceByteCount + TagByteCount + 1;
        if (encryptedData.Length < minimumByteCount || !encryptedData.AsSpan(0, Magic.Length).SequenceEqual(Magic))
        {
            throw new InvalidOperationException("Theme asset is invalid.");
        }

        var offset = Magic.Length;
        var salt = encryptedData.AsSpan(offset, SaltByteCount).ToArray();
        offset += SaltByteCount;
        var nonce = encryptedData.AsSpan(offset, NonceByteCount).ToArray();
        offset += NonceByteCount;

        var sealedData = encryptedData.AsSpan(offset).ToArray();
        if (sealedData.Length <= TagByteCount)
        {
            throw new InvalidOperationException("Theme asset is invalid.");
        }

        var cipherTextLength = sealedData.Length - TagByteCount;
        var ciphertext = sealedData.AsSpan(0, cipherTextLength).ToArray();
        var tag = sealedData.AsSpan(cipherTextLength, TagByteCount).ToArray();
        var plaintext = new byte[ciphertext.Length];
        var key = Rfc2898DeriveBytes.Pbkdf2(
            Encoding.UTF8.GetBytes(keyText),
            salt,
            KeyDerivationRounds,
            HashAlgorithmName.SHA256,
            KeyByteCount);

        using var aes = new AesGcm(key, TagByteCount);
        aes.Decrypt(nonce, ciphertext, tag, plaintext, AssociatedData);
        return plaintext;
    }
}
