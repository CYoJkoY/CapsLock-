#Requires AutoHotkey v2.0

class OSD {
    static currentOSD := ""
    static ShowTopMostOSD( targetHwnd, isOnTop ) {
        if IsObject( this.currentOSD ) {
            try this.currentOSD.Destroy()
            this.currentOSD := ""
        }
        myOSD := Gui( "+AlwaysOnTop -Caption +ToolWindow +E0x20" )
        myOSD.BackColor := "1E1E1E"
        myOSD.SetFont( "s12 cWhite bold", "Segoe UI" )
        text := isOnTop ? "📌 Always Top" : "📌 Unpinned"
        myOSD.Add( "Text", "w120 Center", text )
        try {
            WinGetPos( &wx, &wy, &ww, &wh, targetHwnd )
            myOSD.Show( "Hide" )
            myOSD.GetPos(, , &ow, &oh )
            posX := wx + ( ww / 2 ) - ( ow / 2 )
            posY := wy + 10
            myOSD.Show( "x" posX " y" posY " NoActivate" )
            WinSetTransparent( 0, myOSD )
            this.currentOSD := myOSD
            SetTimer( this.Fade.Bind( this, myOSD, "in" ), -10 )
        } catch {
            myOSD.Destroy()
        }
    }

    static Fade( myOSD, state ) {
        static step := 20, maxAlpha := 220, holdTime := 1000
        try {
            trans := WinGetTransparent( myOSD )
        } catch {
            return
        }
        if state == "in" {
            if trans < maxAlpha {
                WinSetTransparent( trans + step, myOSD )
                SetTimer( this.Fade.Bind( this, myOSD, "in" ), -16 )
            } else {
                SetTimer( this.Fade.Bind( this, myOSD, "hold" ), -holdTime )
            }
        } else if state == "hold" {
            SetTimer( this.Fade.Bind( this, myOSD, "out" ), -16 )
        } else if state == "out" {
            if trans > 0 {
                WinSetTransparent( trans - step, myOSD )
                SetTimer( this.Fade.Bind( this, myOSD, "out" ), -16 )
            } else {
                try myOSD.Destroy()
                this.currentOSD := ""
            }
        }
    }
}
