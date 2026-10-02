using System;
using System.Collections.Generic;
using System.Globalization;
using System.Text;

namespace CapsLockSharp
{
    /// <summary>
    /// One BSTR per bulk transfer, framed as UTF-16-length:text. Unlike a joined
    /// array, this also round-trips clipboard text containing any delimiter.
    /// AHK StrLen and System.String.Length both count UTF-16 code units.
    /// </summary>
    internal static class StringWire
    {
        internal static string Pack(IEnumerable<string> values)
        {
            var output = new StringBuilder();
            foreach (string value in values)
            {
                if (value == null)
                    throw new ArgumentException("Null strings cannot cross the service boundary.");
                output.Append(value.Length.ToString(CultureInfo.InvariantCulture));
                output.Append(':');
                output.Append(value);
            }
            return output.ToString();
        }

        internal static string[] Unpack(string payload)
        {
            if (payload == null)
                throw new ArgumentNullException(nameof(payload));

            var values = new List<string>();
            int offset = 0;
            while (offset < payload.Length)
            {
                int colon = payload.IndexOf(':', offset);
                if (colon < 0 || colon == offset)
                    throw new FormatException("Missing string length.");

                int length;
                if (!int.TryParse(payload.Substring(offset, colon - offset),
                    NumberStyles.None, CultureInfo.InvariantCulture, out length))
                    throw new FormatException("Invalid string length.");

                offset = colon + 1;
                if (length > payload.Length - offset)
                    throw new FormatException("Truncated string payload.");

                values.Add(payload.Substring(offset, length));
                offset += length;
            }
            return values.ToArray();
        }
    }
}
