using System;
using System.Collections.Generic;
using System.Text;

namespace CapsLockSharp
{
    public static class StringWire
    {
        public static string Pack(IEnumerable<string> values)
        {
            if (values == null)
                return string.Empty;

            var sb = new StringBuilder();
            foreach (var value in values)
            {
                string s = value ?? string.Empty;
                sb.Append(s.Length).Append(':').Append(s);
            }
            return sb.ToString();
        }

        public static List<string> Unpack(string payload)
        {
            var list = new List<string>();
            if (string.IsNullOrEmpty(payload))
                return list;

            int offset = 0;
            int total = payload.Length;

            while (offset < total)
            {
                int colon = payload.IndexOf(':', offset);
                if (colon < 0)
                    throw new InvalidOperationException("Missing service string length delimiter");

                string lenStr = payload.Substring(offset, colon - offset);
                if (!int.TryParse(lenStr, out int length) || length < 0)
                    throw new InvalidOperationException("Invalid service string length");

                offset = colon + 1;
                if (offset + length > total)
                    throw new InvalidOperationException("Truncated service string payload");

                list.Add(payload.Substring(offset, length));
                offset += length;
            }

            return list;
        }
    }
}
