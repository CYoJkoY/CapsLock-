using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace CapsLockSharp
{
    /// <summary>
    /// Resident text index. AHK remains the owner of history metadata and disk
    /// storage; only a snapshot and subsequent small deltas cross the bridge.
    /// All public indices are zero-based, newest first; -1 means not found.
    /// </summary>
    public sealed class HistoryService
    {
        private sealed class Entry
        {
            internal readonly string Text;
            internal readonly bool AsciiText;
            internal string Preview;
            internal bool AsciiPreview;
            internal int Slot;
            internal Entry OlderDuplicate;
            internal Entry NewerDuplicate;

            internal Entry(string text)
            {
                Text = text;
                AsciiText = AhkSearch.IsAscii(text);
            }
        }

        private sealed class Occurrences
        {
            internal Entry Oldest;
            internal Entry Newest;
        }

        // Oldest first in a ring: prepend/evict in AHK becomes append/shift-head
        // here, with no O(n) copy on the common new-clip path.
        private Entry[] entries = new Entry[16];
        private int head;
        private int count;
        private Dictionary<string, Occurrences> byText =
            new Dictionary<string, Occurrences>(StringComparer.Ordinal);

        public int Count { get { return count; } }

        /// <summary>Replaces the index atomically, preserving loaded duplicates.</summary>
        public void LoadSnapshot(string payload)
        {
            string[] texts = StringWire.Unpack(payload);
            var replacement = new HistoryService();
            replacement.EnsureCapacity(texts.Length);
            for (int i = texts.Length - 1; i >= 0; i--)
                replacement.Append(new Entry(texts[i]));

            entries = replacement.entries;
            head = replacement.head;
            count = replacement.count;
            byText = replacement.byText;
        }

        /// <summary>
        /// O(1) lookup, including the oldest of several loaded duplicates.
        /// Physical ring slots give the current rank without renumbering every
        /// entry when a new clip arrives.
        /// </summary>
        public int FindDuplicate(string candidate)
        {
            Occurrences found;
            if (candidate == null || !byText.TryGetValue(candidate, out found))
                return -1;

            int oldestIndex = (found.Oldest.Slot - head + entries.Length) % entries.Length;
            return count - oldestIndex - 1;
        }

        /// <summary>
        /// Applies an already committed AHK insert/removal/trim, returning the
        /// new count for a cheap consistency check. Stale deltas throw before
        /// changing anything. The caller handles the duplicate-at-top no-op.
        /// </summary>
        public int ApplyAdd(string text, int duplicateIndex, int max)
        {
            if (text == null)
                throw new ArgumentNullException(nameof(text));
            if (max < 0)
                throw new ArgumentOutOfRangeException(nameof(max));
            if (FindDuplicate(text) != duplicateIndex)
                throw new InvalidOperationException("History delta does not match the resident snapshot.");

            if (duplicateIndex >= 0)
                Remove(count - duplicateIndex - 1);
            if (max > 0)
                Append(new Entry(text));
            return TrimTo(max);
        }

        public int DeleteAt(int index)
        {
            if (index < 0 || index >= count)
                throw new ArgumentOutOfRangeException(nameof(index));
            Remove(count - index - 1);
            return count;
        }

        public int TrimTo(int max)
        {
            if (max < 0)
                throw new ArgumentOutOfRangeException(nameof(max));
            while (count > max)
                Remove(0);

            // Do not retain a large ring after disabling/trimming history.
            if (entries.Length > 64 && count < entries.Length / 4)
                Resize(Math.Max(16, count * 2));
            return count;
        }

        /// <summary>
        /// One scalar query in, comma-separated indices out (not an array proxy
        /// read once per hit). Matches both raw text and the existing 80-code-unit
        /// menu preview, including queries spanning collapsed whitespace.
        /// </summary>
        public string SearchIndices(string query)
        {
            query = query ?? string.Empty;
            var search = new AhkSearch(query);
            var hits = new StringBuilder();
            for (int index = 0; index < count; index++)
            {
                Entry entry = At(count - index - 1);
                if (query.Length != 0 && !search.Contains(entry.Text, entry.AsciiText))
                {
                    if (entry.Preview == null)
                    {
                        entry.Preview = BuildPreview(entry.Text);
                        entry.AsciiPreview = AhkSearch.IsAscii(entry.Preview);
                    }
                    if (!search.Contains(entry.Preview, entry.AsciiPreview))
                        continue;
                }

                if (hits.Length != 0)
                    hits.Append(',');
                hits.Append(index.ToString(CultureInfo.InvariantCulture));
            }
            return hits.ToString();
        }

        /// <summary>Diagnostic snapshot; not used on the per-copy path.</summary>
        public string ExportSnapshot()
        {
            var texts = new string[count];
            for (int i = 0; i < count; i++)
                texts[i] = At(count - i - 1).Text;
            return StringWire.Pack(texts);
        }

        public static string BuildPreview(string text)
        {
            if (string.IsNullOrEmpty(text))
                return string.Empty;

            int length = Math.Min(80, text.Length);
            var preview = new StringBuilder(length + 1);
            bool inWhitespace = false;
            for (int i = 0; i < length; i++)
            {
                char c = text[i];
                // PCRE's \v also includes NEL, line separator and paragraph separator.
                bool whitespace = c == '\r' || c == '\n' || c == '\t' || c == '\v' || c == '\f'
                    || c == '\u0085' || c == '\u2028' || c == '\u2029';
                if (!whitespace || !inWhitespace)
                    preview.Append(whitespace ? ' ' : c);
                inWhitespace = whitespace;
            }
            if (text.Length > 80)
                preview.Append('\u2026');
            return preview.ToString();
        }

        private int Slot(int oldestIndex) { return (head + oldestIndex) % entries.Length; }
        private Entry At(int oldestIndex) { return entries[Slot(oldestIndex)]; }

        private void EnsureCapacity(int capacity)
        {
            if (capacity > entries.Length)
                Resize(Math.Max(capacity, checked(entries.Length * 2)));
        }

        private void Resize(int capacity)
        {
            var resized = new Entry[capacity];
            for (int i = 0; i < count; i++)
            {
                Entry entry = At(i);
                resized[i] = entry;
                entry.Slot = i;
            }
            entries = resized;
            head = 0;
        }

        private void Append(Entry entry)
        {
            EnsureCapacity(count + 1);
            entry.Slot = Slot(count);
            entries[entry.Slot] = entry;
            count++;

            Occurrences occurrences;
            if (!byText.TryGetValue(entry.Text, out occurrences))
            {
                occurrences = new Occurrences();
                byText.Add(entry.Text, occurrences);
            }
            entry.OlderDuplicate = occurrences.Newest;
            if (occurrences.Newest != null)
                occurrences.Newest.NewerDuplicate = entry;
            else
                occurrences.Oldest = entry;
            occurrences.Newest = entry;
        }

        private void Remove(int oldestIndex)
        {
            Entry removed = At(oldestIndex);
            Occurrences occurrences = byText[removed.Text];
            if (removed.OlderDuplicate != null)
                removed.OlderDuplicate.NewerDuplicate = removed.NewerDuplicate;
            else
                occurrences.Oldest = removed.NewerDuplicate;
            if (removed.NewerDuplicate != null)
                removed.NewerDuplicate.OlderDuplicate = removed.OlderDuplicate;
            else
                occurrences.Newest = removed.OlderDuplicate;
            if (occurrences.Oldest == null)
                byText.Remove(removed.Text);

            // Arbitrary deletes move the shorter side of the ring. Evicting
            // the oldest, or removing the newest, moves no entries at all.
            if (oldestIndex < count / 2)
            {
                for (int i = oldestIndex; i > 0; i--)
                    Move(At(i - 1), Slot(i));
                entries[head] = null;
                head = (head + 1) % entries.Length;
            }
            else
            {
                for (int i = oldestIndex; i < count - 1; i++)
                    Move(At(i + 1), Slot(i));
                entries[Slot(count - 1)] = null;
            }
            count--;
            if (count == 0)
                head = 0;
        }

        private void Move(Entry entry, int slot)
        {
            entries[slot] = entry;
            entry.Slot = slot;
        }

        // Stateless helpers retained for the naive-marshalling benchmark.
        public static int FindDuplicateIndex(string[] texts, string candidate)
        {
            if (texts == null || candidate == null)
                return -1;
            for (int i = texts.Length - 1; i >= 0; i--)
                if (string.Equals(texts[i], candidate, StringComparison.Ordinal))
                    return i;
            return -1;
        }

        public static string[] InsertTop(string[] texts, string entry, int max)
        {
            if (entry == null)
                return texts ?? new string[0];
            if (max <= 0)
                max = int.MaxValue;
            int length = Math.Min(max, (texts == null ? 0 : texts.Length) + 1);
            var result = new string[length];
            result[0] = entry;
            if (length > 1)
                Array.Copy(texts, 0, result, 1, length - 1);
            return result;
        }

        public static string[] RemoveAt(string[] texts, int index)
        {
            if (texts == null || index < 0 || index >= texts.Length)
                return texts ?? new string[0];
            var result = new string[texts.Length - 1];
            Array.Copy(texts, 0, result, 0, index);
            Array.Copy(texts, index + 1, result, index, texts.Length - index - 1);
            return result;
        }

        public static int[] Search(string[] texts, string query)
        {
            if (texts == null || string.IsNullOrEmpty(query))
                return new int[0];
            var search = new AhkSearch(query);
            var hits = new List<int>();
            for (int i = 0; i < texts.Length; i++)
                if (texts[i] != null && search.Contains(texts[i], AhkSearch.IsAscii(texts[i])))
                    hits.Add(i);
            return hits.ToArray();
        }
    }
}
