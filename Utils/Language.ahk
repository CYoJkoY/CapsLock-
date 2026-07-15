#Requires AutoHotkey v2.0

class Language {
    static current := "zh"
    static langCodes := []
    static currentIndex := 0
    static translations := Map()
    static loaded := false

    static Load( filePath := A_ScriptDir "\lang.csv" ) {
        if this.loaded
            return

        if !FileExist( filePath ) {
            this.translations := Map()
            this.langCodes := [ "en", "fr", "zh", "ja", "ko", "zh_TW", "ru", "pl", "es", "pt", "de", "tr", "it" ]
            this.currentIndex := 0
            this.loaded := true
            return
        }

        try {
            raw := FileRead( filePath, "UTF-8" )
            if SubStr( raw, 1, 1 ) == Chr( 0xFEFF )
                raw := SubStr( raw, 2 )

            lines := StrSplit( raw, "`n", "`r" )
            if lines.Length == 0
                return

            headerFields := this._ParseCSVLine( lines[ 1 ] )
            this.langCodes := []
            for h in headerFields {
                h := Trim( h )
                if h != "key"
                    this.langCodes.Push( h )
            }

            if this.langCodes.Length == 0
                return

            this.currentIndex := 0
            for i, code in this.langCodes {
                if code == this.current {
                    this.currentIndex := i - 1
                    break
                }
            }

            this.translations := Map()
            loop lines.Length - 1 {
                idx := A_Index + 1
                line := lines[ idx ]
                if Trim( line ) == ""
                    continue

                fields := this._ParseCSVLine( line )
                if fields.Length == 0
                    continue

                key := Trim( fields[ 1 ] )
                if key == ""
                    continue

                keyUpper := StrUpper( key )
                values := []
                loop this.langCodes.Length {
                    valIndex := A_Index + 1
                    if valIndex <= fields.Length
                        values.Push( Trim( fields[ valIndex ] ) )
                    else
                        values.Push( "" )
                }
                this.translations[ keyUpper ] := values
            }
            this.loaded := true
        } catch {
            this.translations := Map()
            this.loaded := true
        }
    }

    static Get( key, default := "", params* ) {
        if !this.loaded
            this.Load()
        keyUpper := StrUpper( key )
        if this.translations.Has( keyUpper ) {
            arr := this.translations[ keyUpper ]
            if this.currentIndex < arr.Length && arr[ this.currentIndex + 1 ] != ""
                text := arr[ this.currentIndex + 1 ]
            else if arr.Length > 0 && arr[ 1 ] != ""
                text := arr[ 1 ]
            else
                text := ""
            if text != "" {
                if params.Length > 0 {
                    for i, p in params {
                        text := StrReplace( text, "{" i "}", p )
                    }
                }
                return text
            }
        }

        return ( default != "" ) ? default : key
    }

    static SetLanguage( code ) {
        if code == this.current
            return true
        for i, c in this.langCodes {
            if c == code {
                this.current := code
                this.currentIndex := i - 1
                return true
            }
        }
        return false
    }

    static GetCurrent() {
        return this.current
    }

    static GetLanguages() {
        return this.langCodes
    }

    static _ParseCSVLine( line ) {
        fields := []
        field := ""
        inQuotes := false
        i := 1
        len := StrLen( line )
        while i <= len {
            char := SubStr( line, i, 1 )
            if ( char == '"' ) {
                if inQuotes && SubStr( line, i + 1, 1 ) == '"' {
                    field .= '"'
                    i += 2
                    continue
                }
                inQuotes := !inQuotes
                i++
                continue
            }

            if ( char == "," && !inQuotes ) {
                fields.Push( field )
                field := ""
                i++
                continue
            }

            field .= char
            i++
        }

        fields.Push( field )
        return fields
    }
}

Lang( key, default := "", params* ) {
    if params.Length == 0
        return Language.Get( key, default )
    else
        return Language.Get( key, default, params* )
}
