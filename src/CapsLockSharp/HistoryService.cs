using System;
using System.Collections.Generic;

namespace CapsLockSharp
{
    public class HistoryService
    {
        private readonly List<string> _history = new List<string>();

        public int Count => _history.Count;

        public void LoadSnapshot(string payload)
        {
            // 先解包以保证原子性：若 payload 损坏抛出异常，现有状态不被污染
            var items = StringWire.Unpack(payload);
            _history.Clear();
            _history.AddRange(items);
        }

        public string ExportSnapshot()
        {
            return StringWire.Pack(_history);
        }

        public int FindDuplicate(string candidate)
        {
            if (candidate == null)
                return -1;

            // 倒序匹配最新的重复项
            for (int i = _history.Count - 1; i >= 0; i--)
            {
                if (string.Equals(_history[i], candidate, StringComparison.Ordinal))
                    return i;
            }

            return -1;
        }

        public int FindDuplicateIndex(string candidate)
        {
            return FindDuplicate(candidate);
        }

        public int ApplyAdd(string text, int duplicateIndex, int max)
        {
            if (duplicateIndex < -1 || duplicateIndex >= _history.Count)
                throw new InvalidOperationException($"Duplicate index {duplicateIndex} out of range (count: {_history.Count})");
            if (max < 0)
                throw new InvalidOperationException($"Max {max} cannot be negative");

            if (duplicateIndex >= 0)
            {
                _history.RemoveAt(duplicateIndex);
            }

            // 常驻队列顺序：新项追加到末尾
            _history.Add(text);

            // 超过上限时驱逐最老的首项 (0 索引)
            while (_history.Count > max && _history.Count > 0)
            {
                _history.RemoveAt(0);
            }

            return _history.Count;
        }

        public int DeleteAt(int index)
        {
            if (index < 0 || index >= _history.Count)
                throw new InvalidOperationException($"Index {index} out of range (count: {_history.Count})");

            _history.RemoveAt(index);
            return _history.Count;
        }

        public int TrimTo(int max)
        {
            if (max < 0)
                throw new InvalidOperationException($"Max {max} cannot be negative");

            while (_history.Count > max && _history.Count > 0)
            {
                _history.RemoveAt(0);
            }

            return _history.Count;
        }

        public string SearchIndices(string query)
        {
            var indices = Search(_history, query);
            return indices.Count == 0 ? string.Empty : string.Join(",", indices);
        }

        public static string BuildPreview(string text)
        {
            return AhkSearch.GetPreview(text);
        }

        // --- 用于无状态基准测试与断言的辅助方法 ---

        public static int FindDuplicateIndex(IList<string> items, string candidate)
        {
            if (items == null || candidate == null)
                return -1;

            for (int i = items.Count - 1; i >= 0; i--)
            {
                if (string.Equals(items[i], candidate, StringComparison.Ordinal))
                    return i;
            }

            return -1;
        }

        public static List<string> InsertTop(IList<string> items, string text, int max)
        {
            var list = items as List<string> ?? (items != null ? new List<string>(items) : new List<string>());
            list.Insert(0, text);
            while (list.Count > max && list.Count > 0)
            {
                list.RemoveAt(list.Count - 1);
            }
            return list;
        }

        public static List<string> RemoveAt(IList<string> items, int index)
        {
            var list = items as List<string> ?? (items != null ? new List<string>(items) : new List<string>());
            if (index >= 0 && index < list.Count)
            {
                list.RemoveAt(index);
            }
            return list;
        }

        public static List<int> Search(IList<string> items, string query)
        {
            var indices = new List<int>();
            if (items == null)
                return indices;

            for (int i = 0; i < items.Count; i++)
            {
                if (AhkSearch.Matches(items[i], query))
                {
                    indices.Add(i);
                }
            }

            return indices;
        }
    }
}
