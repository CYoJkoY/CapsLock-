using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using CapsLockSharp;

namespace CapsLockSharp.Tests
{
    // No extra test-framework packages; only the service project/SDK restore is needed.
    public static class Program
    {
        private static int assertions;

        public static int Main(string[] args)
        {
            var tests = new Dictionary<string, Action>
            {
                { "snapshot framing and atomic replacement", SnapshotTests },
                { "resident duplicate order and deltas", HistoryTests },
                { "ring wraparound, growth, and eviction", RingTests },
                { "randomized history/reference equivalence", RandomizedHistoryTests },
                { "raw and display-preview search", SearchTests },
                { "randomized ASCII/Unicode search equivalence", RandomizedSearchTests },
                { "clipboard multiline normalization", ClipboardTests },
                { "ignore batch order, rule updates, and bounded cache", IgnoreTests },
                { "native Windows glob semantics", WindowsGlobTests },
                { "stateless benchmark helpers", StatelessTests }
            };
            int failures = 0;
            foreach (var test in tests)
            {
                try { test.Value(); Console.WriteLine("PASS " + test.Key); }
                catch (Exception error) { failures++; Console.Error.WriteLine("FAIL " + test.Key + ": " + error); }
            }
            Console.WriteLine(tests.Count + " tests, " + assertions + " assertions, " + failures + " failures.");
            if (failures == 0 && Array.IndexOf(args, "--benchmark") >= 0)
                Benchmark();
            return failures == 0 ? 0 : 1;
        }

        private static void Assert(bool condition, string description)
        {
            assertions++;
            if (!condition) throw new InvalidOperationException(description);
        }

        private static void Equal<T>(T expected, T actual, string description)
        {
            Assert(EqualityComparer<T>.Default.Equals(expected, actual),
                description + ": expected " + expected + ", actual " + actual);
        }

        private static void Throws<T>(Action action) where T : Exception
        {
            try { action(); }
            catch (T) { assertions++; return; }
            throw new InvalidOperationException("Expected " + typeof(T).Name);
        }

        // Test-side framing, independent of the production encoder/decoder.
        private static string Pack(params string[] values)
        {
            return string.Concat(values.Select(value => value.Length.ToString(CultureInfo.InvariantCulture) + ":" + value));
        }

        private static void SnapshotTests()
        {
            var history = new HistoryService();
            string[] texts = { "", "first\r\nsecond:line", "中文🚀", "\u001f|,0:|", "same", "same" };
            string payload = Pack(texts);
            history.LoadSnapshot(payload);
            Equal(texts.Length, history.Count, "snapshot count");
            Equal(payload, history.ExportSnapshot(), "UTF-16/delimiter round trip");
            Equal(5, history.FindDuplicate("same"), "oldest loaded duplicate");
            foreach (string invalid in new[] { "x", ":", "-1:x", "+1:x", "1.0:x", "999999999999:x", "3:ab", "0:x" })
            {
                Throws<FormatException>(() => history.LoadSnapshot(invalid));
                Equal(payload, history.ExportSnapshot(), "failed replacement leaves state intact");
            }
            Throws<ArgumentNullException>(() => history.LoadSnapshot(null));
            history.LoadSnapshot("");
            Equal(0, history.Count, "empty snapshot");
            Equal(-1, history.FindDuplicate(null), "null candidate");
        }

        private static void HistoryTests()
        {
            var history = new HistoryService();
            history.LoadSnapshot(Pack("dup", "middle", "dup", "tail"));
            Equal(2, history.FindDuplicate("dup"), "reverse scan order");
            Equal(-1, history.FindDuplicate("DUP"), "ordinal case-sensitive duplicate");
            Equal(4, history.ApplyAdd("dup", 2, 4), "move oldest duplicate to top");
            Equal(Pack("dup", "dup", "middle", "tail"), history.ExportSnapshot(), "loaded duplicates preserved");
            Equal(1, history.FindDuplicate("dup"), "duplicate rank after move");
            Equal(3, history.DeleteAt(1), "delete old duplicate");
            Equal(0, history.FindDuplicate("dup"), "remaining top duplicate");
            string before = history.ExportSnapshot();
            Throws<InvalidOperationException>(() => history.ApplyAdd("dup", -1, 4));
            Throws<InvalidOperationException>(() => history.ApplyAdd("new", 0, 4));
            Throws<ArgumentOutOfRangeException>(() => history.ApplyAdd("new", -1, -1));
            Throws<ArgumentOutOfRangeException>(() => history.DeleteAt(-1));
            Throws<ArgumentOutOfRangeException>(() => history.DeleteAt(3));
            Equal(before, history.ExportSnapshot(), "invalid deltas do not mutate");
            Equal(2, history.TrimTo(2), "trim count");
            Equal(-1, history.FindDuplicate("tail"), "evicted text removed from index");
            Equal(0, history.ApplyAdd("discarded", -1, 0), "disabled history");
            Equal("", history.SearchIndices(""), "empty search after clear");
            Equal(-1, history.FindDuplicate("dup"), "clear removes all occurrence links");
        }

        private static void RingTests()
        {
            var history = new HistoryService();
            var reference = new List<string>();
            for (int i = 0; i < 20000; i++)
            {
                string text = "unique-" + i;
                history.ApplyAdd(text, -1, 127);
                reference.Insert(0, text);
                if (reference.Count > 127) reference.RemoveAt(reference.Count - 1);
                if (i % 127 == 0) VerifyHistory(history, reference);
            }
            for (int i = 0; i < 500; i++)
            {
                string text = "grow-" + i;
                history.ApplyAdd(text, -1, 1000);
                reference.Insert(0, text);
            }
            VerifyHistory(history, reference);
            foreach (int max in new[] { 64, 16, 1, 0 })
            {
                history.TrimTo(max);
                reference.RemoveRange(max, reference.Count - max);
                VerifyHistory(history, reference);
            }
            history.ApplyAdd("after-clear", -1, 1);
            Equal(0, history.FindDuplicate("after-clear"), "reuse after compaction");
        }

        private static void RandomizedHistoryTests()
        {
            string[] pool = { "a", "A", "01", "1", "dup", "你好", "é", "🚀:x", "a\r\nb", "\t", "|,\u001f" };
            var random = new Random(20261002);
            var history = new HistoryService();
            var reference = new List<string>();
            for (int step = 0; step < 10000; step++)
            {
                int operation = random.Next(10);
                if (operation < 6)
                {
                    string text = random.Next(3) == 0 ? "new-" + step : pool[random.Next(pool.Length)];
                    if (reference.Count == 0 || reference[0] != text)
                    {
                        int duplicate = reference.FindLastIndex(value => value == text);
                        Equal(duplicate, history.FindDuplicate(text), "lookup before delta");
                        int max = random.Next(1, 200);
                        if (duplicate >= 0) reference.RemoveAt(duplicate);
                        reference.Insert(0, text);
                        if (reference.Count > max) reference.RemoveRange(max, reference.Count - max);
                        history.ApplyAdd(text, duplicate, max);
                    }
                }
                else if (operation == 6 && reference.Count > 0)
                {
                    int index = random.Next(reference.Count);
                    reference.RemoveAt(index);
                    history.DeleteAt(index);
                }
                else if (operation == 7)
                {
                    int max = random.Next(20);
                    if (reference.Count > max) reference.RemoveRange(max, reference.Count - max);
                    history.TrimTo(max);
                }
                else if (operation == 8)
                {
                    reference = Enumerable.Range(0, random.Next(200)).Select(_ => pool[random.Next(pool.Length)]).ToList();
                    history.LoadSnapshot(Pack(reference.ToArray()));
                }
                else
                {
                    string query = pool[random.Next(pool.Length)];
                    Equal(ReferenceSearch(reference, query), history.SearchIndices(query), "randomized search");
                }
                VerifyHistory(history, reference);
                foreach (string text in pool)
                    Equal(reference.FindLastIndex(value => value == text), history.FindDuplicate(text), "randomized duplicate rank");
            }
        }

        private static void VerifyHistory(HistoryService history, List<string> reference)
        {
            Equal(reference.Count, history.Count, "resident count");
            Equal(Pack(reference.ToArray()), history.ExportSnapshot(), "resident order/content");
            for (int i = 0; i < reference.Count; i++)
                Equal(reference.FindLastIndex(value => value == reference[i]), history.FindDuplicate(reference[i]), "ring slot rank");
        }

        private static string ReferencePreview(string text)
        {
            return Regex.Replace(text.Substring(0, Math.Min(80, text.Length)), "[\r\n\t\v\f\u0085\u2028\u2029]+", " ")
                + (text.Length > 80 ? "…" : "");
        }

        private static string ReferenceFold(string text)
        {
            return new string(text.Select(c => c >= 'A' && c <= 'Z' ? (char)(c + 32) : c).ToArray());
        }

        private static string ReferenceSearch(List<string> texts, string query)
        {
            string folded = ReferenceFold(query);
            return string.Join(",", Enumerable.Range(0, texts.Count).Where(index => query.Length == 0 ||
                ReferenceFold(texts[index]).IndexOf(folded, StringComparison.Ordinal) >= 0 ||
                ReferenceFold(ReferencePreview(texts[index])).IndexOf(folded, StringComparison.Ordinal) >= 0));
        }

        private static void SearchTests()
        {
            var history = new HistoryService();
            var texts = new List<string> { "alpha\r\n\tBeta", "你好🚀", "ÉCOLE", new string('x', 80) + "tail", "", "\v\f\t", "KΣİı", "kσi", new string('a', 10000) + "🚀b", "alpha\u0085\u2028\u2029Beta" };
            history.LoadSnapshot(Pack(texts.ToArray()));
            foreach (string query in new[] { "", "alpha beta", "beta", "école", "École", "你好", "🚀", "tail", "…", "missing", " ", "K", "K", "Σ", "σ", "İ", "i", "ı", "aa🚀b", "aab" })
            {
                Equal(ReferenceSearch(texts, query), history.SearchIndices(query), "raw/preview search: " + query);
                Equal(ReferenceSearch(texts, query), history.SearchIndices(query), "warm preview cache: " + query);
            }
            Equal("", history.SearchIndices("école"), "non-ASCII case is exact, like default AHK InStr");
            Equal("2", history.SearchIndices("École"), "ASCII letters still fold beside Unicode");
            foreach (string text in texts)
                Equal(ReferencePreview(text), HistoryService.BuildPreview(text), "AHK preview shape");
            Equal("", HistoryService.BuildPreview(null), "null preview");
        }

        private static void RandomizedSearchTests()
        {
            var random = new Random(731);
            string[] units = { "a", "A", "b", "B", "c", "é", "É", "Σ", "σ", "İ", "ı", "K", "k", "🚀", "\t", "\n", "\u0085", "\u2028", "\u2029", " " };
            var history = new HistoryService();
            for (int step = 0; step < 5000; step++)
            {
                string text = string.Concat(Enumerable.Range(0, random.Next(180)).Select(_ => units[random.Next(units.Length)]));
                string query = string.Concat(Enumerable.Range(0, random.Next(8)).Select(_ => units[random.Next(units.Length)]));
                if (step % 3 == 0 && text.Length > 0)
                {
                    int start = random.Next(text.Length);
                    query = text.Substring(start, Math.Min(random.Next(1, 12), text.Length - start));
                }
                history.LoadSnapshot(Pack(text));
                Equal(ReferenceSearch(new List<string> { text }, query), history.SearchIndices(query), "randomized UTF-16/ASCII search");
            }
        }

        private static void ClipboardTests()
        {
            string[,] cases = {
                { "", "" }, { "one  \t", "one" }, { "  one\n two \t\n", "  one\r\n two\r\n" },
                { "a\r\nb\rc\nd", "a\r\nb\r\nc\r\nd" }, { "\n\r\n", "\r\n\r\n" },
                { "中文🚀\t\r\nsecond\t", "中文🚀\r\nsecond" }, { " \t", "" }
            };
            for (int i = 0; i < cases.GetLength(0); i++)
            {
                string normalized = ClipboardService.NormalizeText(cases[i, 0]);
                Equal(cases[i, 1], normalized, "normalize line boundaries");
                Equal(normalized, ClipboardService.NormalizeText(normalized), "normalize idempotence");
            }
            Equal("", ClipboardService.NormalizeText(null), "null normalization");
            Equal("ab…", ClipboardService.Preview("abcd", 3), "truncated preview");
            Equal("…", ClipboardService.Preview("abcd", 1), "one-char preview");
            Equal("abcd", ClipboardService.Preview("abcd", 0), "unlimited preview");
            string directory = Path.Combine(Path.GetTempPath(), "CapsLockSharpTests-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(directory);
            try
            {
                string file = Path.Combine(directory, "中文.txt");
                File.WriteAllText(file, "test");
                Assert(ClipboardService.LooksLikeFilePathList(file + "\r\nsecond"), "file-list first file");
                Assert(ClipboardService.LooksLikeFilePathList("\r" + directory + "\r\nsecond"), "AHK CR trim on first directory");
                Assert(!ClipboardService.LooksLikeFilePathList(file), "requires newline");
                Assert(!ClipboardService.LooksLikeFilePathList(directory + "-missing\nsecond"), "missing first path");
                Assert(!ClipboardService.LooksLikeFilePathList("\n" + file), "blank first path");
            }
            finally { Directory.Delete(directory, true); }
        }

        private static void IgnoreTests()
        {
            var matcher = new IgnoreMatcher();
            string complex = Pack("^(?:.*[/])?obj(?:[/].*)?$", "^temp[^/](?:[/].*)?$");
            string[] paths = { "C:\\repo\\obj\\keep.txt", "C:\\repo\\OBJ\\keep.txt", "temp1/file.txt", "keep:🚀.txt", "keep.txt" };
            Assert(matcher.IsMatch("", complex, paths[0]), "normalized complex path");
            Assert(!matcher.IsMatch("", complex, paths[1]), "complex AHK regex is case-sensitive");
            Equal(Pack(paths[1], paths[3], paths[4]), matcher.FilterPaths("", complex, Pack(paths)), "batch preserves order/text");
            Equal("", matcher.FilterPaths("", complex, ""), "empty batch");
            Assert(matcher.IsMatch("", Pack("^$"), ""), "empty paths use the actual regex semantics");
            Equal(1, matcher.CacheCount, "one cached rule set");
            for (int i = 0; i < 300; i++)
                matcher.IsMatch("", Pack("^rule" + i + "$"), "keep.txt");
            Equal(1, matcher.CacheCount, "rule edits do not grow cache");
            Assert(matcher.IsMatch("", Pack("^rule299$"), "rule299"), "updated rules");
            Throws<ArgumentException>(() => matcher.IsMatch("", Pack("["), "keep"));
            Assert(matcher.IsMatch("", Pack("^rule299$"), "rule299"), "failed rule build retains previous cache");
            Throws<FormatException>(() => matcher.FilterPaths("", "", "100:short"));
            Throws<FormatException>(() => matcher.IsMatch("malformed", "", "keep"));
            Throws<RegexMatchTimeoutException>(() => matcher.IsMatch("", Pack("^(a+)+$"), new string('a', 30000) + "!"));
            matcher.Invalidate();
            Equal(0, matcher.CacheCount, "explicit invalidation");
        }

        private static void WindowsGlobTests()
        {
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            {
                Console.WriteLine("SKIP PathMatchSpecW fixtures require Windows (covered by CI).");
                return;
            }
            var matcher = new IgnoreMatcher();
            Assert(matcher.IsMatch(Pack("*.tmp"), "", "C:\\repo\\UPPER.TMP"), "native case-insensitive glob");
            Assert(matcher.IsMatch(Pack("*.*"), "", "C:\\repo\\README"), "native extensionless *.*");
            Assert(matcher.IsMatch(Pack("*.txt;*.md"), "", "C:\\repo\\readme.md"), "native alternatives");
            Assert(matcher.IsMatch(Pack("file.txt"), "", "C:file.txt"), "drive-relative filename matching");
            Assert(!matcher.IsMatch(Pack("file.txt"), "", "C:/repo/file.txt"), "AHK forward-slash filename quirk");
            Assert(matcher.IsMatch(Pack("file.txt"), "", "http://example.test/file.txt"), "AHK URL filename matching");
            Assert(!matcher.IsMatch(Pack("obj"), "", "C:\\repo\\obj\\keep.txt"), "do not prune directory-name globs");
            Equal(Pack("keep.txt"), matcher.FilterPaths(Pack("*.tmp"), "", Pack("drop.TMP", "keep.txt")), "native batch");
        }

        private static void StatelessTests()
        {
            Equal(2, HistoryService.FindDuplicateIndex(new[] { "a", "b", "a" }, "a"), "naive reverse scan");
            Equal(-1, HistoryService.FindDuplicateIndex(null, "a"), "null scan");
            Assert(HistoryService.InsertTop(new[] { "a", "b" }, "x", 2).SequenceEqual(new[] { "x", "a" }), "bounded prepend");
            Assert(HistoryService.RemoveAt(new[] { "a", "b", "c" }, 1).SequenceEqual(new[] { "a", "c" }), "remove array copy");
            Assert(HistoryService.Search(new[] { "a", null, "A" }, "a").SequenceEqual(new[] { 0, 2 }), "stateless search");
        }

        private static void Benchmark()
        {
            Console.WriteLine("Managed-only diagnostic; excludes AHK, COM, cold CLR boot, and GUI work.");
            Console.WriteLine("entries,linear_miss_us,resident_miss_us,linear_mid_hit_us,resident_mid_hit_us");
            foreach (int size in new[] { 1000, 10000, 50000 })
            {
                string[] texts = Enumerable.Range(0, size).Select(i => "history entry " + i).ToArray();
                var history = new HistoryService();
                history.LoadSnapshot(Pack(texts));
                Console.WriteLine(string.Format(CultureInfo.InvariantCulture, "{0},{1:F3},{2:F3},{3:F3},{4:F3}", size,
                    TimeLookup(() => HistoryService.FindDuplicateIndex(texts, "missing")),
                    TimeLookup(() => history.FindDuplicate("missing")),
                    TimeLookup(() => HistoryService.FindDuplicateIndex(texts, texts[size / 2])),
                    TimeLookup(() => history.FindDuplicate(texts[size / 2]))));
            }
        }

        private static double TimeLookup(Func<int> lookup)
        {
            int result = 0;
            for (int i = 0; i < 100; i++) result ^= lookup();
            var timer = Stopwatch.StartNew();
            for (int i = 0; i < 2000; i++) result ^= lookup();
            timer.Stop();
            GC.KeepAlive(result);
            return timer.Elapsed.TotalMilliseconds * 1000 / 2000;
        }
    }
}
