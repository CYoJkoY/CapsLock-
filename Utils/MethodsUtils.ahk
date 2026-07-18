#Requires AutoHotkey v2.0

Clamp( val, min, max ) => val < min ? min : ( val > max ? max : val )

ShowToolTip( msg, durationMs := 1500 ) {
    ToolTip( msg )
    if durationMs > 0
        SetTimer( () => ToolTip(), -durationMs )
}

Join( arr, sep := " " ) {
    s := ""
    for v in arr
        s .= v . sep
    return SubStr( s, 1, -StrLen( sep ) )
}
