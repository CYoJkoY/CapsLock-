#Requires AutoHotkey v2.0

class Json {
    static Stringify(value, pretty := false, indent := 0) {
        return this._Stringify(value, pretty, indent)
    }

    static _Stringify(value, pretty, indent) {
        if !IsObject(value) {
            if value is String
                return '"' this._Escape(String(value)) '"'
            if value == ""
                return "null"
            if value is Number
                return String(value)
            return '"' this._Escape(String(value)) '"'
        }

        nextIndent := indent + 1
        newline := pretty ? Chr(13) Chr(10) : ""
        pad := pretty ? this._Indent(indent) : ""
        nextPad := pretty ? this._Indent(nextIndent) : ""

        if value is Array {
            if value.Length == 0
                return "[]"

            parts := []
            for item in value
                parts.Push(nextPad this._Stringify(item, pretty, nextIndent))

            return "[" newline this._Join(parts, "," newline) newline pad "]"
        }

        entries := []
        keys := []

        if value is Map {
            for key in value
                keys.Push(String(key))
        } else {
            for name in ObjOwnProps(value)
                keys.Push(String(name))
        }

        this._SortStrings(keys)

        for key in keys {
            item := value is Map ? value[key] : value.%key%
            entries.Push(nextPad '"' this._Escape(key) '":' (pretty ? " " : "")
                this._Stringify(item, pretty, nextIndent))
        }

        if entries.Length == 0
            return "{}"

        return "{" newline this._Join(entries, "," newline) newline pad "}"
    }

    static Parse(text) {
        return JsonParser(String(text)).Parse()
    }

    static _Escape(text) {
        text := StrReplace(text, "\", "\\")
        text := StrReplace(text, '"', '\"')
        text := StrReplace(text, Chr(8), "\b")
        text := StrReplace(text, Chr(12), "\f")
        text := StrReplace(text, Chr(13), "\r")
        text := StrReplace(text, Chr(10), "\n")
        text := StrReplace(text, Chr(9), "\t")

        result := ""
        Loop Parse, text {
            code := Ord(A_LoopField)
            if code < 0x20
                result .= Format("\u{:04X}", code)
            else
                result .= A_LoopField
        }
        return result
    }

    static _Indent(level) {
        result := ""
        Loop level
            result .= "  "
        return result
    }

    static _Join(items, separator) {
        result := ""
        for index, item in items {
            if index > 1
                result .= separator
            result .= item
        }
        return result
    }

    static _SortStrings(arr) {
        n := arr.Length
        if n <= 1
            return

        Loop n - 1 {
            swapped := false
            Loop n - A_Index {
                if StrCompare(arr[A_Index], arr[A_Index + 1]) > 0 {
                    tmp := arr[A_Index]
                    arr[A_Index] := arr[A_Index + 1]
                    arr[A_Index + 1] := tmp
                    swapped := true
                }
            }
            if !swapped
                break
        }
    }
}

class JsonParser {
    __New(text) {
        this.Text := String(text)
        this.Length := StrLen(this.Text)
        this.Pos := 1
    }

    Parse() {
        this._SkipWhitespace()
        value := this._ParseValue()
        this._SkipWhitespace()
        if this.Pos <= this.Length
            throw Error("Unexpected JSON data at position " this.Pos)
        return value
    }

    _ParseValue() {
        this._SkipWhitespace()
        if this.Pos > this.Length
            throw Error("Unexpected end of JSON")

        ch := SubStr(this.Text, this.Pos, 1)

        switch ch {
            case '"':
                return this._ParseString()
            case "{":
                return this._ParseObject()
            case "[":
                return this._ParseArray()
            case "t":
                this._ExpectLiteral("true")
                return 1
            case "f":
                this._ExpectLiteral("false")
                return 0
            case "n":
                this._ExpectLiteral("null")
                return ""
            default:
                if ch == "-" || ch ~= "\d"
                    return this._ParseNumber()
        }

        throw Error("Invalid JSON value at position " this.Pos)
    }

    _ParseObject() {
        result := Map()
        this.Pos++

        this._SkipWhitespace()
        if this._Take("}")
            return result

        loop {
            this._SkipWhitespace()
            if this.Pos > this.Length || SubStr(this.Text, this.Pos, 1) != '"'
                throw Error("Expected object key at position " this.Pos)

            key := this._ParseString()

            this._SkipWhitespace()
            if !this._Take(":")
                throw Error("Expected ':' at position " this.Pos)

            result[key] := this._ParseValue()

            this._SkipWhitespace()
            if this._Take("}")
                break
            if !this._Take(",")
                throw Error("Expected ',' or '}' at position " this.Pos)
        }

        return result
    }

    _ParseArray() {
        result := []
        this.Pos++

        this._SkipWhitespace()
        if this._Take("]")
            return result

        loop {
            result.Push(this._ParseValue())
            this._SkipWhitespace()

            if this._Take("]")
                break
            if !this._Take(",")
                throw Error("Expected ',' or ']' at position " this.Pos)
        }

        return result
    }

    _ParseString() {
        if !this._Take('"')
            throw Error("Expected string at position " this.Pos)

        result := ""

        while this.Pos <= this.Length {
            ch := SubStr(this.Text, this.Pos, 1)
            this.Pos++

            if ch == '"'
                return result

            if ch == "\" {
                if this.Pos > this.Length
                    throw Error("Incomplete JSON escape")

                escaped := SubStr(this.Text, this.Pos, 1)
                this.Pos++

                switch escaped {
                    case '"': result .= '"'
                    case "\": result .= "\"
                    case "/": result .= "/"
                    case "b": result .= Chr(8)
                    case "f": result .= Chr(12)
                    case "n": result .= Chr(10)
                    case "r": result .= Chr(13)
                    case "t": result .= Chr(9)
                    case "u":
                        codeText := SubStr(this.Text, this.Pos, 4)
                        if StrLen(codeText) != 4 || !RegExMatch(codeText, "^[0-9A-Fa-f]{4}$")
                            throw Error("Invalid Unicode escape")
                        result .= Chr("0x" codeText)
                        this.Pos += 4
                    default:
                        throw Error("Unsupported JSON escape")
                }
            } else {
                if Ord(ch) < 0x20
                    throw Error("Unescaped control character in JSON string")
                result .= ch
            }
        }

        throw Error("Unterminated JSON string")
    }

    _ParseNumber() {
        start := this.Pos

        if this._Take("-")
            this._ConsumeDigits()

        if this._Take(".") {
            if !this._IsDigitAtCurrent()
                throw Error("Invalid JSON number")
            this._ConsumeDigits()
        }

        if this.Pos <= this.Length {
            ch := SubStr(this.Text, this.Pos, 1)
            if ch == "e" || ch == "E" {
                this.Pos++
                if this.Pos <= this.Length {
                    sign := SubStr(this.Text, this.Pos, 1)
                    if sign == "+" || sign == "-"
                        this.Pos++
                }
                if !this._IsDigitAtCurrent()
                    throw Error("Invalid JSON exponent")
                this._ConsumeDigits()
            }
        }

        token := SubStr(this.Text, start, this.Pos - start)
        return token ~= "[eE.]" ? Float(token) : Integer(token)
    }

    _ConsumeDigits() {
        while this._IsDigitAtCurrent()
            this.Pos++
    }

    _IsDigitAtCurrent() {
        return this.Pos <= this.Length
            && SubStr(this.Text, this.Pos, 1) ~= "\d"
    }

    _SkipWhitespace() {
        while this.Pos <= this.Length {
            ch := SubStr(this.Text, this.Pos, 1)
            if ch != " " && ch != Chr(9) && ch != Chr(13) && ch != Chr(10)
                break
            this.Pos++
        }
    }

    _ExpectLiteral(literal) {
        if SubStr(this.Text, this.Pos, StrLen(literal)) != literal
            throw Error("Invalid JSON literal at position " this.Pos)
        this.Pos += StrLen(literal)
    }

    _Take(expected) {
        if SubStr(this.Text, this.Pos, StrLen(expected)) == expected {
            this.Pos += StrLen(expected)
            return true
        }
        return false
    }
}
