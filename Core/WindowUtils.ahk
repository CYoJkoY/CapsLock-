#Requires AutoHotkey v2.0
#Include "..\Utils\MathUtils.ahk"

AdjustOpacity( step ) {
    hwnd := WinExist( "A" )
    if !hwnd {
        return
    }
    currentTrans := WinGetTransparent( hwnd )
    if ( currentTrans = "" ) {
        currentTrans := 255
    }
    newTrans := Clamp( currentTrans + step, 20, 255 )
    WinSetTransparent( newTrans, hwnd )
}
