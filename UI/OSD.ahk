#Requires AutoHotkey v2.0

class OSD {
    static currentOSD := ""
    static fadeTimer := ""

    static ShowTopMostOSD( targetHwnd, isOnTop ) {
        if this.fadeTimer != "" {
            SetTimer( this.fadeTimer, 0 )
            this.fadeTimer := ""
        }
        if IsObject( this.currentOSD ) {
            try this.currentOSD.Destroy()
            this.currentOSD := ""
        }

        myOSD := Gui( "+AlwaysOnTop -Caption +ToolWindow +E0x20" )
        myOSD.BackColor := "1E1E1E"
        myOSD.SetFont( "s12 cWhite bold", "Segoe UI" )
        text := isOnTop ? Lang( "UI_ALWAYS_TOP" ) : Lang( "UI_UNPINNED" )
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

            this.fadeTimer := ObjBindMethod( this, "Fade", myOSD, "in" )
            SetTimer( this.fadeTimer, -10 )
        } catch {
            myOSD.Destroy()
        }
    }

    static Fade( myOSD, state ) {
        try {
            if !IsObject( myOSD ) || !WinExist( "ahk_id " myOSD.Hwnd ) {
                this.StopFade()
                return
            }
            trans := WinGetTransparent( myOSD )
        } catch {
            this.StopFade()
            return
        }

        static step := 20, maxAlpha := 220, holdTime := 1000

        if state == "in" {
            if trans < maxAlpha {
                WinSetTransparent( trans + step, myOSD )
                this.fadeTimer := ObjBindMethod( this, "Fade", myOSD, "in" )
                SetTimer( this.fadeTimer, -16 )
            } else {
                this.fadeTimer := ObjBindMethod( this, "Fade", myOSD, "hold" )
                SetTimer( this.fadeTimer, -holdTime )
            }
        } else if state == "hold" {
            this.fadeTimer := ObjBindMethod( this, "Fade", myOSD, "out" )
            SetTimer( this.fadeTimer, -16 )
        } else if state == "out" {
            if trans > 0 {
                WinSetTransparent( trans - step, myOSD )
                this.fadeTimer := ObjBindMethod( this, "Fade", myOSD, "out" )
                SetTimer( this.fadeTimer, -16 )
            } else {
                try myOSD.Destroy()
                this.currentOSD := ""
                this.StopFade()
            }
        }
    }

    static StopFade() {
        if this.fadeTimer != "" {
            SetTimer( this.fadeTimer, 0 )
            this.fadeTimer := ""
        }
    }
}
