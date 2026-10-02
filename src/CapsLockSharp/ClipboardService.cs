using System;
using System.IO;
using System.Text;

namespace CapsLockSharp
{
    /// <summary>
    /// Candidate C# implementation of the pure part of the clipboard service.
    /// Mirrors the file-path-list test inside <c>ClipboardHelper.CopyAsPlainText</c>
    /// in Core/Clipboard.ahk.
    /// </summary>
    /// <remarks>
    /// This is deliberately the smallest useful surface of the service.
    /// <c>CopyAsPlainText</c> itself backs up the clipboard, sends Ctrl+C and
    /// waits for the result: that is a high-frequency input path, it stays in
    /// AutoHotkey, and no benchmark result will change that.
    ///
    /// What is worth moving is the decision it makes afterwards, because that
    /// is plain string and file-system work.
    ///
    /// The AHK expression being mirrored is:
    ///     InStr(text, "`n") &amp;&amp; FileExist(StrSplit(text, "`n", "`r")[1])
    /// </remarks>
    public static class ClipboardService
    {
        /// <summary>
        /// True when <paramref name="text"/> looks like a list of copied file
        /// paths: it spans several lines and its first line names something
        /// that exists on disk.
        /// </summary>
        public static bool LooksLikeFilePathList(string text)
        {
            if (string.IsNullOrEmpty(text))
                return false;

            int newline = text.IndexOf('\n');
            if (newline < 0)
                return false;

            string first = text.Substring(0, newline).Trim('\r');
            if (first.Length == 0)
                return false;

            try
            {
                return File.Exists(first) || Directory.Exists(first);
            }
            catch (ArgumentException)
            {
                return false;
            }
            catch (PathTooLongException)
            {
                return false;
            }
            catch (NotSupportedException)
            {
                return false;
            }
        }

        /// <summary>
        /// Explicitly normalises line endings to CRLF and trims trailing spaces
        /// and tabs per line. Clipboard/history contents are NOT automatically
        /// passed through this helper; original text stays unchanged.
        /// </summary>
        public static string NormalizeText(string text)
        {
            if (string.IsNullOrEmpty(text))
                return string.Empty;

            // A single pass avoids three whole-string replacements and a Split.
            // Keep separators: the previous implementation joined every line
            // together, silently changing the contents of multiline clips.
            var sb = new StringBuilder(text.Length);
            int start = 0;
            for (int i = 0; i < text.Length; i++)
            {
                if (text[i] != '\r' && text[i] != '\n')
                    continue;

                AppendTrimmedLine(sb, text, start, i);
                sb.Append("\r\n");
                if (text[i] == '\r' && i + 1 < text.Length && text[i + 1] == '\n')
                    i++;
                start = i + 1;
            }
            AppendTrimmedLine(sb, text, start, text.Length);
            return sb.ToString();
        }

        private static void AppendTrimmedLine(StringBuilder sb, string text, int start, int end)
        {
            while (end > start && (text[end - 1] == ' ' || text[end - 1] == '\t'))
                end--;
            sb.Append(text, start, end - start);
        }

        /// <summary>
        /// Truncates to <paramref name="maxChars"/> for display, appending an
        /// ellipsis only when something was actually removed. Character count,
        /// not byte count: the AHK side counts characters too.
        /// </summary>
        public static string Preview(string text, int maxChars)
        {
            if (string.IsNullOrEmpty(text))
                return string.Empty;

            if (maxChars <= 0 || text.Length <= maxChars)
                return text;

            if (maxChars <= 1)
                return "\u2026";

            return text.Substring(0, maxChars - 1) + "\u2026";
        }
    }
}
