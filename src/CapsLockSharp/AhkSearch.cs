using System;

namespace CapsLockSharp
{
    /// <summary>
    /// AHK InStr's default CaseSense=false folds ASCII A-Z only, not arbitrary
    /// Unicode like OrdinalIgnoreCase. Reuse one folded query/prefix table for
    /// a search; never allocate a lowercased copy of each history entry.
    /// </summary>
    internal sealed class AhkSearch
    {
        private readonly string query;
        private readonly bool asciiQuery;
        private readonly char[] folded;
        private readonly int[] prefix;

        internal AhkSearch(string query)
        {
            this.query = query;
            asciiQuery = IsAscii(query);
            folded = query.ToCharArray();
            prefix = new int[folded.Length];
            for (int i = 0; i < folded.Length; i++)
                folded[i] = FoldAscii(folded[i]);
            for (int i = 1, matched = 0; i < folded.Length; i++)
            {
                while (matched > 0 && folded[i] != folded[matched])
                    matched = prefix[matched - 1];
                if (folded[i] == folded[matched])
                    matched++;
                prefix[i] = matched;
            }
        }

        internal static bool IsAscii(string text)
        {
            for (int i = 0; i < text.Length; i++)
                if (text[i] > 0x7f)
                    return false;
            return true;
        }

        internal bool Contains(string text, bool asciiText)
        {
            if (folded.Length == 0)
                return true;
            if (text.Length < folded.Length)
                return false;
            if (asciiText && asciiQuery)
                return text.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0;

            // KMP for mixed/Unicode text: ASCII-insensitive, non-ASCII exact,
            // and linear even for long, repetitive clipboard contents.
            int matched = 0;
            for (int i = 0; i < text.Length; i++)
            {
                char c = FoldAscii(text[i]);
                while (matched > 0 && c != folded[matched])
                    matched = prefix[matched - 1];
                if (c == folded[matched])
                    matched++;
                if (matched == folded.Length)
                    return true;
            }
            return false;
        }

        private static char FoldAscii(char c)
        {
            return c >= 'A' && c <= 'Z' ? (char)(c + ('a' - 'A')) : c;
        }
    }
}
