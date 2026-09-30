using System;
using System.Collections.Generic;

namespace CapsLockSharp
{
    /// <summary>
    /// Candidate C# implementation of the clipboard-history inner loop.
    /// Mirrors <c>HistoryManager.Add</c> in History/HistoryStorage.ahk.
    /// </summary>
    /// <remarks>
    /// Only the pure, allocation-light part of the service lives here. Nothing
    /// in this class touches the clipboard, the file system or the UI: those
    /// stay in AutoHotkey, which is the whole point of the boundary.
    ///
    /// Every index crossing the boundary is 0-based on this side. The AHK side
    /// adds or subtracts 1 as needed, and the equivalence tests in
    /// scripts/perf/ServiceEquivalence.ahk pin that convention down.
    /// </remarks>
    public static class HistoryService
    {
        /// <summary>
        /// Reverse linear scan for an existing entry, newest last, exactly the
        /// order HistoryManager.Add uses so that RemoveAt shifts as few
        /// elements as possible.
        /// </summary>
        /// <returns>0-based index of the duplicate, or -1 when there is none.</returns>
        public static int FindDuplicateIndex(string[] texts, string candidate)
        {
            if (texts == null || candidate == null)
                return -1;

            for (int i = texts.Length - 1; i >= 0; i--)
            {
                if (string.Equals(texts[i], candidate, StringComparison.Ordinal))
                    return i;
            }

            return -1;
        }

        /// <summary>
        /// Prepends <paramref name="entry"/> and trims the tail to
        /// <paramref name="max"/>, matching HistoryManager.Add's
        /// InsertAt(1) + Pop behaviour.
        /// </summary>
        public static string[] InsertTop(string[] texts, string entry, int max)
        {
            if (entry == null)
                return texts ?? new string[0];

            if (max <= 0)
                max = int.MaxValue;

            var result = new List<string>((texts == null ? 0 : texts.Length) + 1);
            result.Add(entry);

            if (texts != null)
            {
                for (int i = 0; i < texts.Length && result.Count < max; i++)
                    result.Add(texts[i]);
            }

            if (result.Count > max)
                result.RemoveRange(max, result.Count - max);

            return result.ToArray();
        }

        /// <summary>
        /// Removes the entry at <paramref name="index"/> (0-based). Returns the
        /// input unchanged when the index is out of range, which is what
        /// HistoryManager.Delete does.
        /// </summary>
        public static string[] RemoveAt(string[] texts, int index)
        {
            if (texts == null || index < 0 || index >= texts.Length)
                return texts ?? new string[0];

            var result = new List<string>(texts.Length - 1);
            for (int i = 0; i < texts.Length; i++)
            {
                if (i != index)
                    result.Add(texts[i]);
            }

            return result.ToArray();
        }

        /// <summary>
        /// Case-insensitive substring search over the stored text, which is
        /// what the "search history" box runs on every keystroke.
        /// </summary>
        /// <returns>0-based indices of the matching entries.</returns>
        public static int[] Search(string[] texts, string query)
        {
            if (texts == null || string.IsNullOrEmpty(query))
                return new int[0];

            var hits = new List<int>();

            for (int i = 0; i < texts.Length; i++)
            {
                string text = texts[i];
                if (text == null)
                    continue;

                if (text.IndexOf(query, StringComparison.OrdinalIgnoreCase) >= 0)
                    hits.Add(i);
            }

            return hits.ToArray();
        }
    }
}
