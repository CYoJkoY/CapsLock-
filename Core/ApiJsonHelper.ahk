#Requires AutoHotkey v2.0

; JSON string escaping and unescaping utilities.
class ApiJsonHelper {
    ; Escape a string for JSON: quotes, backslashes, control chars.
    static Escape(str) {
        str := StrReplace(str, "\", "\\")
        str := StrReplace(str, '"', '\"')
        str := StrReplace(str, "`n", "\n")
        str := StrReplace(str, "`r", "\r")
        str := StrReplace(str, "`t", "\t")
        str := RegExReplace(str, "[\x00-\x08\x0B\x0C\x0E-\x1F]", "")
        return '"' . str . '"'
    }

    ; Unescape a JSON string content (without outer quotes).
    static Unescape(str) {
        result := ""
        i := 1
        len := StrLen(str)
        while i <= len {
            ch := SubStr(str, i, 1)
            if (ch == "\") {
                i++
                if (i > len) 
                    break

                nextCh := SubStr(str, i, 1)
                switch nextCh {
                    case "n": result .= "`n"
                    case "r": result .= "`r"
                    case "t": result .= "`t"
                    case '"': result .= '"'
                    case "\": result .= "\"
                    case "/": result .= "/"
                    case "u":
                        if (i + 4 <= len) {
                            hexStr := SubStr(str, i + 1, 4)
                            i += 4
                            try result .= Chr(Integer("0x" . hexStr))
                            catch
                                result .= "?"
                        }
                    default: result .= nextCh
                }
                i++
                continue
            }
            result .= ch
            i++
        }
        return result
    }
}
