using System;
using System.IO;
using System.Text;

namespace CapsLockSharp
{
    /// <summary>
    /// Candidate C# implementation of the pure part of the clipboard service.
    /// Mirrors the file-path-list test inside <c>ClipboardHandler.CopyAsPlainText</c>
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

            string first = text.Substring(0, newline).TrimEnd('\r');
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
        /// Normalises line endings to CRLF and trims trailing whitespace, which
        /// is what the history menu shows and what a pasted fragment needs.
        /// </summary>
        public static string NormalizeText(string text)
        {
            if (string.IsNullOrEmpty(text))
                return string.Empty;

            string normalized = text.Replace("\r\n", "\n").Replace('\r', '\n').Replace("\n", "\r\n");

            var lines = normalized.Split(new[] { "\r\n" }, StringSplitOptions.None);
            var sb = new StringBuilder(normalized.Length);

            for (int i = 0; i < lines.Length; i++)
                sb.Append(lines[i].TrimEnd(' ', '\t'));

            return sb.ToString();
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
