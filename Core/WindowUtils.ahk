#Requires AutoHotkey v2.0

AdjustOpacity( step ) {
    hwnd := WinExist( "A" )
    if !hwnd
        return
    current := WinGetTransparent( hwnd )
    if current == ""
        current := 255
    newVal := Clamp( current + step, 20, 255 )
    WinSetTransparent( newVal, hwnd )
}
