using System;
using System.Text.RegularExpressions;

namespace CapsLockSharp
{
    public static class AhkSearch
    {
        private static readonly Regex WhitespaceRegex = new Regex(@"[\r\n\t\f\x0B]+", RegexOptions.Compiled);

        public static bool Matches(string text, string query)
        {
            if (string.IsNullOrEmpty(query))
                return true;

            if (string.IsNullOrEmpty(text))
                return false;

            if (text.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0)
                return true;

            string preview = GetPreview(text, 80);
            return preview.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0;
        }

        public static string GetPreview(string text, int maxLength = 80)
        {
            if (string.IsNullOrEmpty(text))
                return string.Empty;

            string prefix = text.Length > maxLength ? text.Substring(0, maxLength) : text;
            string display = WhitespaceRegex.Replace(prefix, " ");

            return text.Length > maxLength ? display + "…" : display;
        }
    }
}
