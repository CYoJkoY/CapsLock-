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
    static DWM_NCRENDERING_POLICY := 2
    static DWM_WINDOW_CORNER_PREFERENCE := 33
    static DWM_SYSTEMBACKDROP_TYPE := 38
    static DWMNCRP_DISABLED := 1
    static DWMWCP_DONOTROUND := 1
    static DWMSBT_NONE := 1
    static DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 := -4

    ; Chromium uses a high-frequency compositor path. Avoid issuing native
    ; region changes for sub-pixel-looking mouse motion and cap the update
    ; frequency without changing the normal-window configuration default.
    static CHROMIUM_MIN_UPDATE_INTERVAL := 60
    static CHROMIUM_MIN_MOVE_DISTANCE := 8
    static CHROMIUM_REGION_REPAIR_INTERVAL := 250

    static Active := false
    static SecondLevelActive := false
    static PrimaryHwnd := 0
    static SecondaryHwnd := 0
    static OriginalForeground := 0
    static OriginalTopmost := false
    static Targets := Map()
    static LastMouseX := ""
    static LastMouseY := ""
    static TimerCallback := ""
    static SecondLevelHotkeyCallback := ""
    static SecondLevelHotkeyEnabled := false

    static IsActive() {
        return this.Active
    }

    static InitializeSecondLevelHotkey() {
        if IsObject(this.SecondLevelHotkeyCallback)
            return true

        this.SecondLevelHotkeyCallback := ObjBindMethod(this, "ToggleSecondLevel")

        try {
            ; Always register the second-level key as a context-insensitive
            ; hotkey. Context-sensitive #HotIf evaluation can be delayed while
            ; the script is busy, which makes the X + 1 sequence intermittent.
            HotIf
            Hotkey("1", this.SecondLevelHotkeyCallback, "Off")
            this.SecondLevelHotkeyEnabled := false
            return true
        } catch {
            this.SecondLevelHotkeyCallback := ""
            this.SecondLevelHotkeyEnabled := false
            return false
        }
    }

    static _SetSecondLevelHotkeyEnabled(enabled) {
        if !IsObject(this.SecondLevelHotkeyCallback)
            return false

        try {
            HotIf
            Hotkey("1", enabled ? "On" : "Off")
            this.SecondLevelHotkeyEnabled := enabled
            return true
        } catch {
            this.SecondLevelHotkeyEnabled := false
            return false
        }
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
        this.SecondaryHwnd := 0
        this.OriginalForeground := hwnd
        this.OriginalTopmost := this.IsTopmost(hwnd)
        this.Targets := Map()
        this.LastMouseX := ""
        this.LastMouseY := ""

        if !this._SetSecondLevelHotkeyEnabled(true) {
            this._ResetState()
            return
        }

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
        if this._IsChromiumWindow(hwnd)
            interval := Max(interval, this.CHROMIUM_MIN_UPDATE_INTERVAL)
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

        this._SetSecondLevelHotkeyEnabled(false)
        this._RestoreAll()
        this._RestorePrimaryTopmost()

        original := this.OriginalForeground
        this._ResetState()

        if original && WinExist("ahk_id " original) {
            try WinActivate("ahk_id " original)
        }
    }

    static ToggleSecondLevel(*) {
        if !this.Active
            return

        if !AppState.WindowHoleSecondLevelEnabled {
            ShowToolTip(
                Lang(
                    "MSG_WINDOW_HOLE_SECOND_DISABLED",
                    "Second penetration disabled."
                ),
                1200
            )
            return
        }

        if !this.SecondLevelHotkeyEnabled {
            ShowToolTip(
                Lang(
                    "MSG_WINDOW_HOLE_SECOND_UNAVAILABLE",
                    "No eligible window is available for second penetration."
                ),
                1500
            )
            return
        }

        if this.SecondLevelActive {
            this.SecondLevelActive := false
            this.SecondaryHwnd := 0
            this._RemoveSecondaryTargets()

            ShowToolTip(
                Lang(
                    "MSG_WINDOW_HOLE_SECOND_DISABLED",
                    "Second penetration disabled."
                ),
                1200
            )
            return
        }

        try {
            MouseGetPos(&mouseX, &mouseY, &mouseHwnd)
            if !this._GetPhysicalCursorPosition(&mx, &my) {
                ShowToolTip(
                    Lang(
                        "MSG_WINDOW_HOLE_SECOND_UNAVAILABLE",
                        "No eligible window is available for second penetration."
                    ),
                    1500
                )
                return
            }

            secondaryHwnd := this._GetRootWindowAtPoint(mouseHwnd)
        } catch {
            ShowToolTip(
                Lang(
                    "MSG_WINDOW_HOLE_SECOND_UNAVAILABLE",
                    "No eligible window is available for second penetration."
                ),
                1500
            )
            return
        }

        if (
            !secondaryHwnd
            || secondaryHwnd == this.PrimaryHwnd
            || !this.IsEligible(secondaryHwnd)
        ) {
            ShowToolTip(
                Lang(
                    "MSG_WINDOW_HOLE_SECOND_UNAVAILABLE",
                    "No eligible window is available for second penetration."
                ),
                1500
            )
            return
        }

        result := this._ApplyHole(
            secondaryHwnd,
            false,
            mx,
            my
        )

        if !result {
            this.SecondaryHwnd := 0
            ShowToolTip(
                Lang(
                    "MSG_WINDOW_HOLE_SECOND_UNAVAILABLE",
                    "No eligible window is available for second penetration."
                ),
                1500
            )
            return
        }

        this.SecondaryHwnd := secondaryHwnd
        this.SecondLevelActive := true

        targetName := this._GetWindowLabel(secondaryHwnd)

        message := Lang(
            "MSG_WINDOW_HOLE_SECOND_ENABLED",
            "Second penetration enabled."
        )

        if targetName != ""
            message .= " — " targetName

        ShowToolTip(message, 1500)
    }

    static IsEligible(hwnd) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false

        try {
            if WinGetMinMax("ahk_id " hwnd) == -1
                return false

            className := WinGetClass("ahk_id " hwnd)
            processName := ""
            try processName := WinGetProcessName("ahk_id " hwnd)
            catch {
                ; Protected/special windows can reject process-name queries.
                ; They are still eligible unless an executable allow-list is
                ; explicitly configured.
            }

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

        if !this._GetPhysicalCursorPosition(&mx, &my)
            return

        mouseMoved := force || mx != this.LastMouseX || my != this.LastMouseY

        this.LastMouseX := mx
        this.LastMouseY := my

        primaryState := this.Targets.Has(this.PrimaryHwnd) ? this.Targets[this.PrimaryHwnd] : ""
        primaryRegionApplied := false

        if IsObject(primaryState) && !primaryState.fallback {
            ; The hole follows the cursor only while the cursor is still
            ; geometrically inside the primary window. Once the cursor passes
            ; through the hole into a lower window, freeze the hole in place.
            ; This is essential for real drag/drop: the cursor must be able
            ; to leave the hole and hit the primary window again.
            if mouseMoved && this._IsPointInsideWindow(this.PrimaryHwnd, mx, my) {
                if this._ShouldApplyPosition(primaryState, mx, my) {
                    if !this._ApplyHole(this.PrimaryHwnd, true, mx, my) {
                        this.Stop()
                        return
                    }

                    primaryRegionApplied := true
                }
            }

            ; Chromium-family windows can rebuild their native region during
            ; internal frame updates. Repair a lost region only when the
            ; movement path did not already apply one in this update cycle.
            if primaryState.isChromium
                && !primaryRegionApplied
                && !this._WindowHasActiveRegion(this.PrimaryHwnd)
                && A_TickCount >= primaryState.nextRegionRepairTick {
                primaryState.nextRegionRepairTick := A_TickCount
                    + this.CHROMIUM_REGION_REPAIR_INTERVAL

                if !this._ApplyHole(this.PrimaryHwnd, true, this.LastMouseX, this.LastMouseY) {
                    this.Stop()
                    return
                }
            }
        }

        if !this.SecondLevelActive || !this.SecondaryHwnd
            return

        ; Layer 2 is locked to the window selected when CapsLock + 1
        ; was pressed. Do not discover deeper windows while moving.
        if !WinExist("ahk_id " this.SecondaryHwnd) {
            this.SecondLevelActive := false
            this.SecondaryHwnd := 0
            this._RemoveSecondaryTargets()

            ShowToolTip(
                Lang(
                    "MSG_WINDOW_HOLE_SECOND_DISABLED",
                    "Second penetration disabled."
                ),
                1500
            )
            return
        }

        ; Apply the second-layer hole only while the cursor is inside that
        ; target. Once the cursor penetrates beyond it, freeze the layer too.
        if !this._IsPointInsideWindow(this.SecondaryHwnd, mx, my)
            return

        secondaryRegionApplied := false

        if mouseMoved && this._ShouldApplyPosition(this.Targets[this.SecondaryHwnd], mx, my) {
            result := this._ApplyHole(
                this.SecondaryHwnd,
                false,
                mx,
                my
            )

            if !result {
                this.SecondLevelActive := false
                this.SecondaryHwnd := 0
                this._RemoveSecondaryTargets()

                ShowToolTip(
                    Lang(
                        "MSG_WINDOW_HOLE_SECOND_DISABLED",
                        "Second penetration disabled."
                    ),
                    1500
                )
            } else {
                secondaryRegionApplied := true
            }
        }

        if !this.SecondLevelActive || !this.SecondaryHwnd
            return

        secondaryState := this.Targets.Has(this.SecondaryHwnd)
            ? this.Targets[this.SecondaryHwnd]
            : ""

        if IsObject(secondaryState) && !secondaryState.fallback
            && secondaryState.isChromium
            && !secondaryRegionApplied
            && !this._WindowHasActiveRegion(this.SecondaryHwnd)
            && A_TickCount >= secondaryState.nextRegionRepairTick {
            secondaryState.nextRegionRepairTick := A_TickCount
                + this.CHROMIUM_REGION_REPAIR_INTERVAL

            if !this._ApplyHole(
                this.SecondaryHwnd,
                false,
                this.LastMouseX,
                this.LastMouseY
            ) {
                this.SecondLevelActive := false
                this.SecondaryHwnd := 0
                this._RemoveSecondaryTargets()

                ShowToolTip(
                    Lang(
                        "MSG_WINDOW_HOLE_SECOND_DISABLED",
                        "Second penetration disabled."
                    ),
                    1500
                )
            }
        }
    }

    static _GetPhysicalCursorPosition(&x, &y) {
        x := 0
        y := 0

        previousContext := 0
        contextChanged := false

        try {
            previousContext := DllCall(
                "SetThreadDpiAwarenessContext",
                "Ptr", this.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2,
                "Ptr"
            )
            contextChanged := previousContext != 0

            point := Buffer(8, 0)
            if !DllCall("GetCursorPos", "Ptr", point, "Int")
                return false

            x := NumGet(point, 0, "Int")
            y := NumGet(point, 4, "Int")
            return true
        } catch {
            return false
        } finally {
            if contextChanged {
                try DllCall(
                    "SetThreadDpiAwarenessContext",
                    "Ptr", previousContext,
                    "Ptr"
                )
            }
        }
    }

    static _GetPhysicalWindowGeometry(hwnd, &x, &y, &width, &height) {
        x := 0
        y := 0
        width := 0
        height := 0

        if !hwnd
            return false

        previousContext := 0
        contextChanged := false

        try {
            previousContext := DllCall(
                "SetThreadDpiAwarenessContext",
                "Ptr", this.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2,
                "Ptr"
            )
            contextChanged := previousContext != 0

            rect := Buffer(16, 0)
            if !DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect, "Int")
                return false

            left := NumGet(rect, 0, "Int")
            top := NumGet(rect, 4, "Int")
            right := NumGet(rect, 8, "Int")
            bottom := NumGet(rect, 12, "Int")

            x := left
            y := top
            width := right - left
            height := bottom - top
            return width > 0 && height > 0
        } catch {
            return false
        } finally {
            if contextChanged {
                try DllCall(
                    "SetThreadDpiAwarenessContext",
                    "Ptr", previousContext,
                    "Ptr"
                )
            }
        }
    }

    static _IsChromiumWindow(hwnd) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false

        try {
            processName := StrLower(WinGetProcessName("ahk_id " hwnd))
            return processName == "chrome.exe"
                || processName == "msedge.exe"
                || processName == "brave.exe"
                || processName == "thorium.exe"
                || processName == "vivaldi.exe"
                || processName == "opera.exe"
                || processName == "chromium.exe"
        } catch {
            return false
        }
    }

    static _ShouldApplyPosition(state, x, y) {
        if !IsObject(state) || !state.isChromium || !state.hasAppliedPosition
            return true

        return Max(
            Abs(x - state.lastAppliedX),
            Abs(y - state.lastAppliedY)
        ) >= this.CHROMIUM_MIN_MOVE_DISTANCE
    }

    static _WindowHasActiveRegion(hwnd) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false

        region := DllCall(
            "CreateRectRgn",
            "Int", 0,
            "Int", 0,
            "Int", 1,
            "Int", 1,
            "Ptr"
        )

        if !region
            return false

        try {
            return DllCall(
                "GetWindowRgn",
                "Ptr", hwnd,
                "Ptr", region,
                "Int"
            ) > 0
        } catch {
            return false
        } finally {
            DllCall("DeleteObject", "Ptr", region)
        }
    }

    static _IsPointInsideWindow(hwnd, x, y) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false

        try {
            if !this._GetPhysicalWindowGeometry(hwnd, &wx, &wy, &ww, &wh)
                return false

            return x >= wx && x < wx + ww && y >= wy && y < wy + wh
        } catch {
            return false
        }
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
            this._PrepareWindowForHole(hwnd, state)
        }

        state := this.Targets[hwnd]

        if state.fallback
            return "minimized"

        try {
            if !this._GetPhysicalWindowGeometry(hwnd, &wx, &wy, &ww, &wh)
                throw Error("Could not get physical window geometry.")

            if (ww <= 0 || wh <= 0)
                throw Error("Invalid window dimensions.")

            if mouseX == "" {
                if !this._GetPhysicalCursorPosition(&mx, &my)
                    throw Error("Could not get physical cursor position.")
            } else {
                mx := mouseX
                my := mouseY
            }

            relativeX := mx - wx
            relativeY := my - wy
            baseRegion := state.hadOriginalRegion
                ? state.originalRegion
                : 0
            firstRegionApply := !state.hasAppliedPosition

            region := this._CreateDifferenceRegion(
                ww,
                wh,
                relativeX,
                relativeY,
                baseRegion
            )

            if !region
                throw Error("Could not create window-hole region.")

            if DllCall(
                "PtInRegion",
                "Ptr", region,
                "Int", Floor(relativeX),
                "Int", Floor(relativeY),
                "Int"
            ) != 0 {
                throw Error("Window-hole center remained inside the assigned region.")
            }

            applied := DllCall(
                "SetWindowRgn",
                "Ptr", hwnd,
                "Ptr", region,
                "Int", state.isChromium ? 0 : 1,
                "Int"
            )

            if !applied {
                DllCall("DeleteObject", "Ptr", region)
                throw Error("SetWindowRgn failed.")
            }

            ; After SetWindowRgn succeeds, Windows owns the region handle.
            state.regionActive := true
            state.lastAppliedX := mx
            state.lastAppliedY := my
            state.hasAppliedPosition := true

            ; Chromium's compositor is sensitive to repeated synchronous
            ; redraws. The native region change is sufficient for subsequent
            ; pointer moves; only refresh the first region application.
            if !state.isChromium || firstRegionApply
                this._RefreshWindow(hwnd, false, state.isChromium)

            return true
        } catch {
            if AppState.WindowHoleFallbackToMinimize {
                if state.regionActive
                    this._RestoreOriginalRegion(hwnd, state)

                if this._MinimizeFallback(hwnd, state)
                    return "minimized"
            }

            this._RestoreWindowVisualState(hwnd, state)
            this._DiscardCapturedRegion(state)
            this.Targets.Delete(hwnd)
            return false
        }
    }

    static _CreateDifferenceRegion(
        width,
        height,
        centerX,
        centerY,
        baseRegion := 0
    ) {
        diameter := Clamp(Integer(AppState.WindowHoleDiameter), 80, 1200)
        radius := Floor(diameter / 2)

        source := baseRegion
        ownsSource := false

        if !source {
            source := DllCall(
                "CreateRectRgn",
                "Int", 0,
                "Int", 0,
                "Int", width,
                "Int", height,
                "Ptr"
            )

            if !source
                return 0

            ownsSource := true
        }

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
                "Ptr", source,
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
            if ownsSource && source
                DllCall("DeleteObject", "Ptr", source)
        }
    }

    static _CaptureState(hwnd) {
        state := {
            originalRegion: 0,
            hadOriginalRegion: false,
            regionActive: false,
            fallback: false,
            fallbackPreviousState: 0,
            isChromium: this._IsChromiumWindow(hwnd),
            lastAppliedX: 0,
            lastAppliedY: 0,
            hasAppliedPosition: false,
            nextRegionRepairTick: 0,
            originalNCRenderingPolicy: 0,
            hadOriginalNCRenderingPolicy: false,
            visualPrepared: false,
            originalOpacity: 255,
            hadOriginalOpacity: false,
            originalCornerPreference: 0,
            hadOriginalCornerPreference: false,
            originalSystemBackdropType: 0,
            hadOriginalSystemBackdropType: false
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

            if this._DwmGetIntAttribute(
                hwnd,
                this.DWM_NCRENDERING_POLICY,
                &ncrp
            ) {
                state.hadOriginalNCRenderingPolicy := true
                state.originalNCRenderingPolicy := ncrp
            }

            return state
        } catch {
            return 0
        } finally {
            if tempRegion
                DllCall("DeleteObject", "Ptr", tempRegion)
        }
    }

    static _DwmGetIntAttribute(hwnd, attribute, &value) {
        value := 0
        attributeBuffer := Buffer(4, 0)

        try {
            hr := DllCall(
                "dwmapi\DwmGetWindowAttribute",
                "Ptr", hwnd,
                "UInt", attribute,
                "Ptr", attributeBuffer,
                "UInt", 4,
                "Int"
            )

            if hr != 0
                return false

            value := NumGet(attributeBuffer, 0, "Int")
            return true
        } catch {
            return false
        }
    }

    static _DwmSetIntAttribute(hwnd, attribute, value) {
        attributeBuffer := Buffer(4, 0)
        NumPut("Int", value, attributeBuffer)

        try {
            hr := DllCall(
                "dwmapi\DwmSetWindowAttribute",
                "Ptr", hwnd,
                "UInt", attribute,
                "Ptr", attributeBuffer,
                "UInt", 4,
                "Int"
            )
            return hr == 0
        } catch {
            return false
        }
    }

    static _PrepareWindowForHole(hwnd, state) {
        if !IsObject(state) || !WinExist("ahk_id " hwnd)
            return

        ; A window may already be partially transparent because of the
        ; CapsLock opacity controls. Window Hole needs an opaque source
        ; surface so the excluded region is the only visual gap.
        try {
            opacity := WinGetTransparent("ahk_id " hwnd)
            if IsNumber(opacity) {
                state.hadOriginalOpacity := true
                state.originalOpacity := Integer(opacity)

                if state.originalOpacity < 255
                    WinSetTransparent(255, "ahk_id " hwnd)
            }
        } catch {
        }

        ; Disable DWM non-client rendering while a custom region is active.
        ; Chromium-family windows use custom frame logic which can otherwise
        ; rebuild the frame and discard the externally assigned region.
        if state.hadOriginalNCRenderingPolicy {
            this._DwmSetIntAttribute(
                hwnd,
                this.DWM_NCRENDERING_POLICY,
                this.DWMNCRP_DISABLED
            )
        }

        ; Windows 11 can draw system backdrop material (Mica/Acrylic) across
        ; the window bounds independently of client pixels. Remove it while
        ; the region-hole mode is active so a carved region cannot retain a
        ; solid backdrop instead of revealing the window underneath.
        if this._DwmGetIntAttribute(hwnd, this.DWM_SYSTEMBACKDROP_TYPE, &backdropType) {
            state.hadOriginalSystemBackdropType := true
            state.originalSystemBackdropType := backdropType
            this._DwmSetIntAttribute(hwnd, this.DWM_SYSTEMBACKDROP_TYPE, this.DWMSBT_NONE)
        }

        ; Do not let Windows 11 add rounded-corner pixels around a custom
        ; window region. The region itself owns the hole geometry.
        if this._DwmGetIntAttribute(hwnd, this.DWM_WINDOW_CORNER_PREFERENCE, &cornerPreference) {
            state.hadOriginalCornerPreference := true
            state.originalCornerPreference := cornerPreference
            this._DwmSetIntAttribute(hwnd, this.DWM_WINDOW_CORNER_PREFERENCE, this.DWMWCP_DONOTROUND)
        }

        state.visualPrepared := true
        this._RefreshWindow(hwnd, true, state.isChromium)
    }

    static _RestoreWindowVisualState(hwnd, state) {
        if !IsObject(state) || !state.visualPrepared
            return

        if WinExist("ahk_id " hwnd) {
            ; Restore DWM attributes before restoring the final opacity so
            ; the compositor rebuilds the window from its original policy.
            if state.hadOriginalNCRenderingPolicy
                this._DwmSetIntAttribute(
                    hwnd,
                    this.DWM_NCRENDERING_POLICY,
                    state.originalNCRenderingPolicy
                )

            if state.hadOriginalSystemBackdropType
                this._DwmSetIntAttribute(hwnd, this.DWM_SYSTEMBACKDROP_TYPE, state.originalSystemBackdropType)

            if state.hadOriginalCornerPreference
                this._DwmSetIntAttribute(hwnd, this.DWM_WINDOW_CORNER_PREFERENCE, state.originalCornerPreference)

            if state.hadOriginalOpacity
                try WinSetTransparent(state.originalOpacity, "ahk_id " hwnd)

            this._RefreshWindow(hwnd, true, state.isChromium)
        }

        state.visualPrepared := false
    }

    static _RefreshWindow(hwnd, frameChanged := false, chromium := false) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return

        ; DWM-backed/custom-framed windows may cache their non-client metrics.
        ; SWP_FRAMECHANGED forces Windows to recalculate the frame after a
        ; temporary DWM non-client rendering policy change.
        if frameChanged {
            try DllCall(
                "SetWindowPos",
                "Ptr", hwnd,
                "Ptr", 0,
                "Int", 0,
                "Int", 0,
                "Int", 0,
                "Int", 0,
                "UInt",
                0x0001 ; SWP_NOSIZE
                | 0x0002 ; SWP_NOMOVE
                | 0x0004 ; SWP_NOZORDER
                | 0x0010 ; SWP_NOACTIVATE
                | 0x0020 ; SWP_FRAMECHANGED
            )
        }

        redrawFlags := chromium
            ? 0x0001 | 0x0020
            : 0x0001 | 0x0004 | 0x0080 | 0x0100 | 0x0200 | 0x0400

        try DllCall(
            "RedrawWindow",
            "Ptr", hwnd,
            "Ptr", 0,
            "Ptr", 0,
            "UInt", redrawFlags
        )

        if !chromium
            try DllCall("UpdateWindow", "Ptr", hwnd)


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
                        "Int", state.isChromium ? 0 : 1,
                        "Int"
                    )
                }

                if restored {
                    ; Windows owns the restored original-region handle.
                    state.originalRegion := 0
                } else if state.originalRegion {
                    DllCall("DeleteObject", "Ptr", state.originalRegion)
                    state.originalRegion := 0
                    try DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", 0, "Int", 1, "Int")
                }
            } else {
                try DllCall(
                    "SetWindowRgn",
                    "Ptr", hwnd,
                    "Ptr", 0,
                    "Int", state.isChromium ? 0 : 1,
                    "Int"
                )
            }

            this._RefreshWindow(hwnd, false, state.isChromium)
            state.regionActive := false
        }
    }


    static _DiscardCapturedRegion(state) {
        if IsObject(state) && state.originalRegion {
            try DllCall("DeleteObject", "Ptr", state.originalRegion)
            state.originalRegion := 0
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

            WinMinimize("ahk_id " hwnd)
            Sleep(10)

            if WinGetMinMax("ahk_id " hwnd) != -1
                throw Error("WinMinimize failed.")

            state.fallback := true
            state.fallbackPreviousState := previousState
            ShowToolTip(
                Lang("MSG_WINDOW_HOLE_FALLBACK_USED", "Incompatible window temporarily minimized."),
                1500
            )
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
    }

    static _RestoreTarget(hwnd, state) {
        if !IsObject(state)
            return

        ; Restore DWM/opacity state before returning the original region.
        this._RestoreWindowVisualState(hwnd, state)

        if state.regionActive
            this._RestoreOriginalRegion(hwnd, state)

        if state.fallback
            this._RestoreFallback(hwnd, state.fallbackPreviousState)

        if state.originalRegion
            this._DiscardCapturedRegion(state)

        state.fallback := false
    }

    static _RemoveSecondaryTargets() {
        secondaryHwnds := []
        for hwnd, state in this.Targets {
            if hwnd != this.PrimaryHwnd
                secondaryHwnds.Push(hwnd)
        }

        for hwnd in secondaryHwnds {
            state := this.Targets[hwnd]
            this._RestoreTarget(hwnd, state)
            this.Targets.Delete(hwnd)
        }

        this.SecondaryHwnd := 0
    }

    static _RestorePrimaryTopmost() {
        hwnd := this.PrimaryHwnd
        if !hwnd || !WinExist("ahk_id " hwnd)
            return

        try WinSetAlwaysOnTop(this.OriginalTopmost ? 1 : 0, "ahk_id " hwnd)
    }

    static _ResetState() {
        this._SetSecondLevelHotkeyEnabled(false)
        this.Active := false
        this.SecondLevelActive := false
        this.PrimaryHwnd := 0
        this.SecondaryHwnd := 0
        this.OriginalForeground := 0
        this.OriginalTopmost := false
        this.Targets := Map()
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

    static _GetWindowLabel(hwnd) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return ""

        try {
            title := Trim(WinGetTitle("ahk_id " hwnd))
            if title != ""
                return title

            return Trim(WinGetProcessName("ahk_id " hwnd))
        } catch {
            return ""
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
