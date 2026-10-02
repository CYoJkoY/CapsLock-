using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;

namespace CapsLockSharp
{
    /// <summary>
    /// Batched ignore matching. AHK supplies its already converted regexes,
    /// rather than maintaining a second, subtly different gitignore parser.
    /// Simple globs still use PathMatchSpecW, preserving Windows semantics
    /// (including semicolon alternatives and extensionless '*.*' matches).
    /// </summary>
    public sealed class IgnoreMatcher
    {
        private sealed class Compiled
        {
            internal string[] Simple;
            internal Regex[] Complex;
        }

        private readonly object sync = new object();
        private string simpleKey;
        private string regexKey;
        private Compiled cached;

        [DllImport("shlwapi.dll", EntryPoint = "PathMatchSpecW", CharSet = CharSet.Unicode,
            ExactSpelling = true)]
        private static extern int PathMatchSpec(string path, string pattern);

        /// <summary>Three scalar strings use the bridge's fast call path.</summary>
        public bool IsMatch(string simpleRules, string regexRules, string path)
        {
            return IsMatch(GetCompiled(simpleRules, regexRules), path);
        }

        /// <summary>
        /// One transfer in and one out, in the same order as AHK's native file
        /// enumeration. Do not prune directories: the existing AHK matcher
        /// filters files, and a directory-name glob need not match its children.
        /// </summary>
        public string FilterPaths(string simpleRules, string regexRules, string paths)
        {
            Compiled compiled = GetCompiled(simpleRules, regexRules);
            string[] candidates = StringWire.Unpack(paths);
            var kept = new List<string>(candidates.Length);
            foreach (string path in candidates)
                if (!IsMatch(compiled, path))
                    kept.Add(path);
            return StringWire.Pack(kept);
        }

        public void Invalidate()
        {
            lock (sync)
            {
                cached = null;
                simpleKey = null;
                regexKey = null;
            }
        }

        /// <summary>At most one rule set is retained, even after many edits.</summary>
        public int CacheCount
        {
            get { lock (sync) { return cached == null ? 0 : 1; } }
        }

        private Compiled GetCompiled(string simpleRules, string regexRules)
        {
            lock (sync)
            {
                if (cached != null && string.Equals(simpleKey, simpleRules, StringComparison.Ordinal)
                    && string.Equals(regexKey, regexRules, StringComparison.Ordinal))
                    return cached;

                string[] simple = StringWire.Unpack(simpleRules);
                string[] patterns = StringWire.Unpack(regexRules);
                var regexes = new Regex[patterns.Length];
                for (int i = 0; i < patterns.Length; i++)
                {
                    // AHK's complex regexes are case-sensitive. Only its
                    // PathMatchSpecW bucket is case-insensitive.
                    regexes[i] = new Regex(patterns[i], RegexOptions.Compiled | RegexOptions.CultureInvariant,
                        TimeSpan.FromMilliseconds(250));
                }

                // Publish only after every rule has compiled successfully.
                cached = new Compiled { Simple = simple, Complex = regexes };
                simpleKey = simpleRules;
                regexKey = regexRules;
                return cached;
            }
        }

        private static bool IsMatch(Compiled compiled, string path)
        {
            if (path == null)
                return false;

            string normalized = path.Replace('\\', '/').TrimEnd('/');
            if (compiled.Simple.Length != 0)
            {
                string fileName = FileNameLikeAhk(path);
                foreach (string pattern in compiled.Simple)
                    if (PathMatchSpec(normalized, pattern) != 0 || PathMatchSpec(fileName, pattern) != 0)
                        return true;
            }
            foreach (Regex regex in compiled.Complex)
                if (regex.IsMatch(normalized))
                    return true;
            return false;
        }

        // Mirror SplitPath, not Path.GetFileName. In particular, non-URL paths
        // split on the last backslash (or colon if there is no backslash), not
        // on forward slashes. This quirk is part of the existing AHK behavior.
        private static string FileNameLikeAhk(string path)
        {
            int url = path.IndexOf("://", StringComparison.Ordinal);
            int delimiter;
            if (url >= 0)
            {
                int driveEnd = path.IndexOf('/', url + 3);
                if (driveEnd < 0)
                    driveEnd = path.IndexOf('\\', url + 3);
                if (driveEnd < 0 || driveEnd + 1 == path.Length)
                    return string.Empty;
                delimiter = path.LastIndexOf('/');
                if (delimiter == url + 2)
                    delimiter = path.LastIndexOf('\\');
            }
            else
            {
                delimiter = path.LastIndexOf('\\');
                if (delimiter < 0)
                    delimiter = path.LastIndexOf(':');
            }
            return path.Substring(delimiter + 1);
        }
    }
}
