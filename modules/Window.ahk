ShowTopMostOSD( targetHwnd, isOnTop ) {
    static currentOSD := ""

    if IsObject( currentOSD ) {
        try currentOSD.Destroy()
        currentOSD := ""
    }

    osd := Gui( "+AlwaysOnTop -Caption +ToolWindow +E0x20" )
    osd.BackColor := "1E1E1E"
    osd.SetFont( "s12 cWhite bold", "Segoe UI" )

    text := isOnTop ? "📌 已置顶" : "解除置顶"
    osd.Add( "Text", "w120 Center", text )

    try {
        WinGetPos( &wx, &wy, &ww, &wh, targetHwnd )
        osd.Show( "Hide" )
        osd.GetPos(, , &ow, &oh )

        posX := wx + ( ww / 2 ) - ( ow / 2 )
        posY := wy + 10

        osd.Show( "x" . posX . " y" . posY . " NoActivate" )
        WinSetTransparent( 0, osd )

        currentOSD := osd

        SetTimer( FadeOSD.Bind( osd, "fade_in" ), -10 )
    } catch {
        osd.Destroy()
    }
}

FadeOSD( osd, state ) {
    static step := 15
    static maxAlpha := 220
    static holdTime := 1200

    try {
        trans := WinGetTransparent( osd )
    } catch {
        return
    }

    if ( state = "fade_in" ) {
        if ( trans < maxAlpha ) {
            WinSetTransparent( trans + step, osd )
            SetTimer( FadeOSD.Bind( osd, "fade_in" ), -16 )
        } else {
            SetTimer( FadeOSD.Bind( osd, "hold" ), -holdTime )
        }
    }
    else if ( state = "hold" ) {
        SetTimer( FadeOSD.Bind( osd, "fade_out" ), -16 )
    }
    else if ( state = "fade_out" ) {
        if ( trans > 0 ) {
            WinSetTransparent( trans - step, osd )
            SetTimer( FadeOSD.Bind( osd, "fade_out" ), -16 )
        } else {
            try osd.Destroy()
        }
    }
}
