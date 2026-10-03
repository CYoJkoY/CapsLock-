using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;

namespace CapsLockSharp
{
    public class IgnoreMatcher
    {
        [DllImport("shlwapi.dll", CharSet = CharSet.Unicode, ExactSpelling = true)]
        private static extern bool PathMatchSpecW(string pszFile, string pszSpec);

        private readonly Dictionary<string, Regex> _regexCache = new Dictionary<string, Regex>(StringComparer.Ordinal);

        public int CacheCount => _regexCache.Count;

        public void Invalidate()
        {
            _regexCache.Clear();
        }

        public bool IsMatch(string simpleRulesPacked, string regexRulesPacked, string path)
        {
            var simpleRules = StringWire.Unpack(simpleRulesPacked);
            var regexRules = StringWire.Unpack(regexRulesPacked);

            return MatchesCore(simpleRules, GetOrCreateRegexes(regexRules), path);
        }

        public string FilterPaths(string simpleRulesPacked, string regexRulesPacked, string pathsPacked)
        {
            var simpleRules = StringWire.Unpack(simpleRulesPacked);
            var regexRules = StringWire.Unpack(regexRulesPacked);
            var paths = StringWire.Unpack(pathsPacked);

            var compiledRegexes = GetOrCreateRegexes(regexRules);
            var kept = new List<string>(paths.Count);

            foreach (var path in paths)
            {
                if (!MatchesCore(simpleRules, compiledRegexes, path))
                {
                    kept.Add(path);
                }
            }

            return StringWire.Pack(kept);
        }

        private List<Regex> GetOrCreateRegexes(List<string> patterns)
        {
            var list = new List<Regex>(patterns.Count);
            foreach (var pattern in patterns)
            {
                if (string.IsNullOrEmpty(pattern))
                    continue;

                if (!_regexCache.TryGetValue(pattern, out var regex))
                {
                    try
                    {
                        regex = new Regex(pattern, RegexOptions.Compiled);
                        _regexCache[pattern] = regex;
                    }
                    catch
                    {
                        continue;
                    }
                }

                list.Add(regex);
            }
            return list;
        }

        private static bool MatchesCore(List<string> simpleRules, List<Regex> regexRules, string filePath)
        {
            filePath = filePath ?? string.Empty;

            string normalized = filePath.Replace('\\', '/');
            while (normalized.Length > 0 && normalized.EndsWith("/"))
            {
                normalized = normalized.Substring(0, normalized.Length - 1);
            }

            // AHK SplitPath 特性：在 Windows 下只认 '\'，不把 '/' 当作目录分隔符
            int lastBackslash = filePath.LastIndexOf('\\');
            string fileName = lastBackslash >= 0 ? filePath.Substring(lastBackslash + 1) : filePath;

            foreach (var pattern in simpleRules)
            {
                try
                {
                    if (PathMatchSpecW(normalized, pattern))
                        return true;
                    if (!string.IsNullOrEmpty(fileName) && PathMatchSpecW(fileName, pattern))
                        return true;
                }
                catch
                {
                }
            }

            foreach (var regex in regexRules)
            {
                try
                {
                    if (regex.IsMatch(normalized))
                        return true;
                }
                catch
                {
                }
            }

            return false;
        }
    }
}
