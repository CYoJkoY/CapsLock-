using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;

namespace CapsLockSharp
{
    /// <summary>
    /// Candidate C# implementation of the ignore-rule matcher. Mirrors
    /// <c>FileHelper.BuildIgnoreRegexes</c> and <c>FileHelper.ShouldIgnore</c>
    /// in Core/FileOperations.ahk.
    /// </summary>
    /// <remarks>
    /// The AHK version keeps two buckets: simple globs answered by the native
    /// <c>PathMatchSpecW</c>, and gitignore-style patterns converted to regex.
    /// This port keeps the same split, but answers both from compiled .NET
    /// Regex objects instead of one DllCall per pattern per path.
    ///
    /// The compiled matchers are cached against the exact rule set, so the
    /// caller pays for compilation once, not per path. The cache key is the
    /// joined rule text; a different rule set simply compiles a new matcher.
    /// </remarks>
    public static class IgnoreMatcher
    {
        private sealed class Compiled
        {
            public Regex[] Simple;
            public Regex[] Complex;
        }

        private static readonly object Sync = new object();
        private static readonly Dictionary<string, Compiled> Cache =
            new Dictionary<string, Compiled>(StringComparer.Ordinal);

        /// <summary>Rules are passed newline separated, in file order.</summary>
        public static bool IsMatch(string rules, string path)
        {
            if (string.IsNullOrEmpty(rules) || string.IsNullOrEmpty(path))
                return false;

            Compiled compiled = GetCompiled(rules);
            if (compiled == null)
                return false;

            string normalized = path.Replace('\\', '/');
            while (normalized.EndsWith("/", StringComparison.Ordinal))
                normalized = normalized.Substring(0, normalized.Length - 1);

            string fileName = normalized;
            int slash = normalized.LastIndexOf('/');
            if (slash >= 0 && slash < normalized.Length - 1)
                fileName = normalized.Substring(slash + 1);

            for (int i = 0; i < compiled.Simple.Length; i++)
            {
                if (compiled.Simple[i].IsMatch(normalized))
                    return true;
                if (fileName.Length > 0 && compiled.Simple[i].IsMatch(fileName))
                    return true;
            }

            for (int i = 0; i < compiled.Complex.Length; i++)
            {
                if (compiled.Complex[i].IsMatch(normalized))
                    return true;
            }

            return false;
        }

        /// <summary>Drops the cache. Call after the rule set changes.</summary>
        public static void Invalidate()
        {
            lock (Sync)
            {
                Cache.Clear();
            }
        }

        /// <summary>Number of cached rule sets, for the leak checks.</summary>
        public static int CacheCount
        {
            get
            {
                lock (Sync)
                {
                    return Cache.Count;
                }
            }
        }

        private static Compiled GetCompiled(string rules)
        {
            lock (Sync)
            {
                Compiled found;
                if (Cache.TryGetValue(rules, out found))
                    return found;

                var simple = new List<Regex>();
                var complex = new List<Regex>();

                string[] lines = rules.Split('\n');
                for (int i = 0; i < lines.Length; i++)
                {
                    string pattern = lines[i].Trim().TrimEnd('\r');
                    if (pattern.Length == 0)
                        continue;
                    if (pattern[0] == '#' || pattern[0] == '!')
                        continue;

                    if (pattern.Contains("**") || pattern.Contains("?"))
                    {
                        string regex = GitignoreToRegex(pattern);
                        if (regex.Length > 0)
                            complex.Add(new Regex(regex, RegexOptions.IgnoreCase | RegexOptions.CultureInvariant));
                    }
                    else
                    {
                        string regex = GlobToRegex(pattern);
                        if (regex.Length > 0)
                            simple.Add(new Regex(regex, RegexOptions.IgnoreCase | RegexOptions.CultureInvariant));
                    }
                }

                var compiled = new Compiled
                {
                    Simple = simple.ToArray(),
                    Complex = complex.ToArray()
                };

                Cache[rules] = compiled;
                return compiled;
            }
        }

        /// <summary>
        /// Translates one gitignore-style pattern, following the conversion
        /// rules documented in FileHelper._GitignoreToRegex.
        /// </summary>
        private static string GitignoreToRegex(string pattern)
        {
            var sb = new StringBuilder();
            sb.Append('^');

            int i = 0;
            while (i < pattern.Length)
            {
                if (pattern[i] == '*')
                {
                    if (i + 1 < pattern.Length && pattern[i + 1] == '*')
                    {
                        i += 2;

                        if (i < pattern.Length && pattern[i] == '/')
                        {
                            // "**/" -> optional leading directories
                            sb.Append("(?:.*[/])?");
                            i++;
                        }
                        else
                        {
                            // "/**" -> optional trailing subpath
                            sb.Append("(?:[/].*)?");
                        }
                    }
                    else
                    {
                        // "*" -> anything but a path separator
                        sb.Append("[^/]*");
                        i++;
                    }
                    continue;
                }

                if (pattern[i] == '?')
                {
                    sb.Append("[^/]");
                    i++;
                    continue;
                }

                if (pattern[i] == '/')
                {
                    sb.Append("[/]");
                    i++;
                    continue;
                }

                sb.Append(Regex.Escape(pattern[i].ToString()));
                i++;
            }

            sb.Append('$');
            return sb.ToString();
        }

        /// <summary>
        /// Translates a simple glob such as "*.tmp" to an anchored regex. The
        /// AHK version hands these to PathMatchSpecW instead.
        /// </summary>
        private static string GlobToRegex(string pattern)
        {
            var sb = new StringBuilder();
            sb.Append('^');

            for (int i = 0; i < pattern.Length; i++)
            {
                char c = pattern[i];

                if (c == '*')
                    sb.Append("[^/]*");
                else if (c == '?')
                    sb.Append("[^/]");
                else if (c == '/' || c == '\\')
                    sb.Append("[/]");
                else
                    sb.Append(Regex.Escape(c.ToString()));
            }

            sb.Append('$');
            return sb.ToString();
        }
    }
}
