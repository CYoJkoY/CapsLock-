using System;
using System.IO;

namespace CapsLockSharp
{
    public static class ClipboardService
    {
        public static bool LooksLikeFilePathList(string text)
        {
            if (string.IsNullOrEmpty(text) || !text.Contains("\n"))
                return false;

            int newlineIndex = text.IndexOf('\n');
            string first = text.Substring(0, newlineIndex).TrimEnd('\r');

            if (string.IsNullOrWhiteSpace(first))
                return false;

            try
            {
                return File.Exists(first) || Directory.Exists(first);
            }
            catch
            {
                return false;
            }
        }

        public static string NormalizeText(string text)
        {
            if (string.IsNullOrEmpty(text))
                return string.Empty;

            return text.Replace("\r\n", "\n").Replace('\r', '\n');
        }

        public static string Preview(string text, int maxLength = 80)
        {
            return AhkSearch.GetPreview(text, maxLength);
        }
    }
}
