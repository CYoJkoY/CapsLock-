#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Window Hole service
;
; CapsLock + X temporarily removes a region around the mouse from the
; foreground window. Because the removed area is outside the window region,
; mouse hit-testing can reach the next window underneath.
;
; Region operations are native Win32 calls. Some modern/special windows reject
; SetWindowRgn or render their non-client frame incorrectly. Such windows are
; handled by a temporary minimize fallback and restored when the mode ends.
; ---------------------------------------------------------------------------
class WindowHole {
    static Active := false
    static SecondLevelActive := false
    static PrimaryHwnd := 0
    static OriginalForeground := 0
    static OriginalTopmost := false
    static Targets := Map()
    static FallbackMinimized := Map()
    static LastMouseX := ""
    static LastMouseY := ""
    static TimerCallback := ""

    static IsActive() {
        return this.Active
    }

    static HandleXDown(*) {
        mode := StrLower(AppState.WindowHoleActivation)
        if mode == "toggle"
            this.Toggle()
        else
            this.Start()
    }

    static HandleXUp(*) {
        if StrLower(AppState.WindowHoleActivation) == "hold"
            this.Stop()
    }

    static Toggle(*) {
        if this.Active
            this.Stop()
        else
            this.Start()
    }

    static Start(*) {
        if this.Active
            return

        hwnd := WinExist("A")
        if !hwnd || !this.IsEligible(hwnd)
            return

        this.Active := true
        this.SecondLevelActive := false
        this.PrimaryHwnd := hwnd
        this.OriginalForeground := hwnd
        this.OriginalTopmost := this.IsTopmost(hwnd)
        this.Targets := Map()
        this.FallbackMinimized := Map()
        this.LastMouseX := ""
        this.LastMouseY := ""

        ; Keep the original foreground window above the revealed content.
        ; The previous topmost state is restored when the mode ends.
        if !this.OriginalTopmost {
            try WinSetAlwaysOnTop(1, "ahk_id " hwnd)
        }

        if !this._ApplyHole(hwnd, true) {
            this._RestoreAll()
            this._RestorePrimaryTopmost()
            this._ResetState()
            return
        }

        this.TimerCallback := (*) => this._Update()
        interval := Clamp(Integer(AppState.WindowHoleUpdateInterval), 15, 200)
        SetTimer(this.TimerCallback, interval)
        this._Update()
    }

    static Stop(*) {
        if !this.Active
            return

        try {
            if IsObject(this.TimerCallback)
                SetTimer(this.TimerCallback, 0)
        }

        this._RestoreAll()
        this._RestorePrimaryTopmost()

        original := this.OriginalForeground
        this._ResetState()

        if original && WinExist("ahk_id " original) {
            try WinActivate("ahk_id " original)
        }
    }

    static ToggleSecondLevel(*) {
        if !this.Active || !AppState.WindowHoleSecondLevelEnabled
            return

        this.SecondLevelActive := !this.SecondLevelActive

        if !this.SecondLevelActive {
            this._RemoveSecondaryTargets()
            ShowToolTip(Lang("MSG_WINDOW_HOLE_SECOND_DISABLED", "Second penetration disabled."), 1200)
        } else {
            ShowToolTip(Lang("MSG_WINDOW_HOLE_SECOND_ENABLED", "Second penetration enabled."), 1200)
            this._Update(true)
        }
    }

    static IsEligible(hwnd) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false

        try {
            if WinGetMinMax("ahk_id " hwnd) == -1
                return false

            exStyle := WinGetExStyle("ahk_id " hwnd)
            className := WinGetClass("ahk_id " hwnd)
            processName := WinGetProcessName("ahk_id " hwnd)

            ; Do not manipulate the shell/taskbar surface as a lower
            ; penetration target.
            if className == "Shell_TrayWnd"
                return false
            if className == "Shell_SecondaryTrayWnd"
                return false

            for blockedClass in ["Progman", "WorkerW"] {
                if className == blockedClass
                    return false
            }

            if AppState.WindowHoleAllowedExecutables.Length > 0
                && !this._ListContains(AppState.WindowHoleAllowedExecutables, processName)
                return false

            if AppState.WindowHoleExcludedExecutables.Length > 0
                && this._ListContains(AppState.WindowHoleExcludedExecutables, processName)
                return false

            if AppState.WindowHoleAllowedClasses.Length > 0
                && !this._ListContains(AppState.WindowHoleAllowedClasses, className)
                return false

            if AppState.WindowHoleExcludedClasses.Length > 0
                && this._ListContains(AppState.WindowHoleExcludedClasses, className)
                return false

            return true
        } catch {
            return false
        }
    }

    static _Update(force := false) {
        if !this.Active
            return

        try {
            MouseGetPos(&mx, &my, &mouseHwnd)
        } catch {
            return
        }

        if !force && mx == this.LastMouseX && my == this.LastMouseY
            return

        this.LastMouseX := mx
        this.LastMouseY := my

        if this.PrimaryHwnd {
            primaryState := this.Targets.Has(this.PrimaryHwnd) ? this.Targets[this.PrimaryHwnd] : ""
            if IsObject(primaryState) && !primaryState.fallback {
                if !this._ApplyHole(this.PrimaryHwnd, true, mx, my)
                    this.Stop()
                    return
            }
        }

        if !this.SecondLevelActive
            return

        secondaryHwnd := this._GetRootWindowAtPoint(mouseHwnd)
        if !secondaryHwnd || secondaryHwnd == this.PrimaryHwnd
            return

        if this.Targets.Has(secondaryHwnd)
            return

        if !this.IsEligible(secondaryHwnd)
            return

        ; Only one additional penetration layer is exposed.
        if this.Targets.Count >= 2
            return

        this._ApplyHole(secondaryHwnd, false, mx, my)
    }

    static _GetRootWindowAtPoint(hwnd) {
        if !hwnd
            return 0

        try {
            root := DllCall(
                "GetAncestor",
                "Ptr", hwnd,
                "UInt", 2,
                "Ptr"
            )
            return root ? root : hwnd
        } catch {
            return hwnd
        }
    }

    static _ApplyHole(hwnd, isPrimary, mouseX := "", mouseY := "") {
        if !this.IsEligible(hwnd)
            return false

        if !this.Targets.Has(hwnd) {
            state := this._CaptureState(hwnd)
            if !IsObject(state)
                return false
            this.Targets[hwnd] := state
        }

        state := this.Targets[hwnd]

        if state.fallback
            return "minimized"

        try {
            WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
            if (ww <= 0 || wh <= 0)
                throw Error("Invalid window dimensions.")

            if mouseX == ""
                MouseGetPos(&mx, &my)
            else {
                mx := mouseX
                my := mouseY
            }

            relativeX := mx - wx
            relativeY := my - wy
            region := this._CreateDifferenceRegion(
                ww,
                wh,
                relativeX,
                relativeY
            )

            if !region
                throw Error("Could not create window-hole region.")

            applied := DllCall(
                "SetWindowRgn",
                "Ptr", hwnd,
                "Ptr", region,
                "Int"
            )

            if !applied {
                DllCall("DeleteObject", "Ptr", region)
                throw Error("SetWindowRgn failed.")
            }

            ; After SetWindowRgn succeeds, Windows owns the region handle.
            state.regionActive := true
            return true
        } catch {
            if isPrimary || AppState.WindowHoleFallbackToMinimize {
                if state.regionActive
                    this._RestoreOriginalRegion(hwnd, state)

                if this._MinimizeFallback(hwnd, state)
                    return "minimized"
            }

            this.Targets.Delete(hwnd)
            return false
        }
    }

    static _CreateDifferenceRegion(width, height, centerX, centerY) {
        diameter := Clamp(Integer(AppState.WindowHoleDiameter), 80, 1200)
        radius := Floor(diameter / 2)

        outer := DllCall(
            "CreateRectRgn",
            "Int", 0,
            "Int", 0,
            "Int", width,
            "Int", height,
            "Ptr"
        )

        if !outer
            return 0

        shape := StrLower(AppState.WindowHoleShape)
        hole := 0

        try {
            if shape == "square" {
                hole := DllCall(
                    "CreateRectRgn",
                    "Int", centerX - radius,
                    "Int", centerY - radius,
                    "Int", centerX + radius,
                    "Int", centerY + radius,
                    "Ptr"
                )
            } else if shape == "rounded" {
                corner := Max(20, Floor(diameter / 4))
                hole := DllCall(
                    "CreateRoundRectRgn",
                    "Int", centerX - radius,
                    "Int", centerY - radius,
                    "Int", centerX + radius,
                    "Int", centerY + radius,
                    "Int", corner,
                    "Int", corner,
                    "Ptr"
                )
            } else {
                hole := DllCall(
                    "CreateEllipticRgn",
                    "Int", centerX - radius,
                    "Int", centerY - radius,
                    "Int", centerX + radius,
                    "Int", centerY + radius,
                    "Ptr"
                )
            }

            if !hole
                throw Error("Could not create hole region.")

            result := DllCall(
                "CreateRectRgn",
                "Int", 0,
                "Int", 0,
                "Int", 0,
                "Int", 0,
                "Ptr"
            )

            if !result
                throw Error("Could not create result region.")

            combined := DllCall(
                "CombineRgn",
                "Ptr", result,
                "Ptr", outer,
                "Ptr", hole,
                "Int", 4,
                "Int"
            )

            if combined == 0 {
                DllCall("DeleteObject", "Ptr", result)
                throw Error("Could not combine window-hole regions.")
            }

            return result
        } catch {
            return 0
        } finally {
            if hole
                DllCall("DeleteObject", "Ptr", hole)
            if outer
                DllCall("DeleteObject", "Ptr", outer)
        }
    }

    static _CaptureState(hwnd) {
        state := {
            originalRegion: 0,
            hadOriginalRegion: false,
            regionActive: false,
            fallback: false,
            fallbackPreviousState: 0
        }

        tempRegion := DllCall(
            "CreateRectRgn",
            "Int", 0,
            "Int", 0,
            "Int", 1,
            "Int", 1,
            "Ptr"
        )

        if !tempRegion
            return 0

        try {
            type := DllCall(
                "GetWindowRgn",
                "Ptr", hwnd,
                "Ptr", tempRegion,
                "Int"
            )

            if type > 0 {
                state.hadOriginalRegion := true
                state.originalRegion := tempRegion
                tempRegion := 0
            }

            return state
        } catch {
            return 0
        } finally {
            if tempRegion
                DllCall("DeleteObject", "Ptr", tempRegion)
        }
    }

    static _RestoreOriginalRegion(hwnd, state) {
        if !IsObject(state) || !WinExist("ahk_id " hwnd)
            return

        if state.regionActive {
            if state.hadOriginalRegion && state.originalRegion {
                restored := 0
                try {
                    restored := DllCall(
                        "SetWindowRgn",
                        "Ptr", hwnd,
                        "Ptr", state.originalRegion,
                        "Int"
                    )
                }

                if restored {
                    ; Windows owns the restored original-region handle.
                    state.originalRegion := 0
                } else if state.originalRegion {
                    DllCall("DeleteObject", "Ptr", state.originalRegion)
                    state.originalRegion := 0
                    try DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", 0, "Int")
                }
            } else {
                try DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", 0, "Int")
            }

            state.regionActive := false
        }
    }

    static _MinimizeFallback(hwnd, state) {
        if !AppState.WindowHoleFallbackToMinimize
            return false

        if !WinExist("ahk_id " hwnd)
            return false

        try {
            previousState := WinGetMinMax("ahk_id " hwnd)
            if previousState == -1
                return false

            if !WinMinimize("ahk_id " hwnd) {
                throw Error("WinMinimize failed.")
            }

            state.fallback := true
            state.fallbackPreviousState := previousState
            this.FallbackMinimized[hwnd] := previousState
            return true
        } catch {
            return false
        }
    }

    static _RestoreFallback(hwnd, previousState) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return

        try {
            WinRestore("ahk_id " hwnd)

            if previousState == 1
                WinMaximize("ahk_id " hwnd)
        } catch {
        }
    }

    static _RestoreAll() {
        secondaryHwnds := []
        for hwnd, state in this.Targets {
            if hwnd == this.PrimaryHwnd
                continue
            secondaryHwnds.Push(hwnd)
        }

        ; Restore lower layers first, then the primary window.
        for hwnd in secondaryHwnds {
            if this.Targets.Has(hwnd)
                this._RestoreTarget(hwnd, this.Targets[hwnd])
        }

        if this.PrimaryHwnd && this.Targets.Has(this.PrimaryHwnd)
            this._RestoreTarget(this.PrimaryHwnd, this.Targets[this.PrimaryHwnd])

        this.Targets := Map()
        this.FallbackMinimized := Map()
    }

    static _RestoreTarget(hwnd, state) {
        if !IsObject(state)
            return

        if state.regionActive
            this._RestoreOriginalRegion(hwnd, state)

        if state.fallback
            this._RestoreFallback(hwnd, state.fallbackPreviousState)

        state.fallback := false
    }

    static _RemoveSecondaryTargets() {
        secondaryHwnds := []
        for hwnd, state in this.Targets {
            if hwnd != this.PrimaryHwnd
                secondaryHwnds.Push(hwnd)
        }

        for hwnd in secondaryHwnds {
            if this.Targets.Has(hwnd)
                this._RestoreTarget(hwnd, this.Targets[hwnd])
            this.Targets.Delete(hwnd)
            this.FallbackMinimized.Delete(hwnd)
        }
    }

    static _RestorePrimaryTopmost() {
        hwnd := this.PrimaryHwnd
        if !hwnd || !WinExist("ahk_id " hwnd)
            return

        try WinSetAlwaysOnTop(this.OriginalTopmost ? 1 : 0, "ahk_id " hwnd)
    }

    static _ResetState() {
        this.Active := false
        this.SecondLevelActive := false
        this.PrimaryHwnd := 0
        this.OriginalForeground := 0
        this.OriginalTopmost := false
        this.Targets := Map()
        this.FallbackMinimized := Map()
        this.LastMouseX := ""
        this.LastMouseY := ""
        this.TimerCallback := ""
    }

    static IsTopmost(hwnd) {
        try {
            return (WinGetExStyle("ahk_id " hwnd) & 0x8) != 0
        } catch {
            return false
        }
    }

    static _ListContains(arr, value) {
        needle := StrLower(Trim(value))
        if needle == ""
            return false

        for item in arr {
            if StrLower(Trim(item)) == needle
                return true
        }
        return false
    }
}
