#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Mouse control mode
;
; A modal pointer layer that is available while the native CapsLock light is
; on. A double tap of Shift enters, while a single Shift or Esc exits. Cursor
; movement is vector-based so a diagonal key pair travels at the same speed as
; a single direction. Mouse buttons and the wheel are injected through Win32
; mouse_event, which keeps the generated input away from this script's own
; CapsLock mouse hotkeys.
; ---------------------------------------------------------------------------
class MouseControl {
    static Active := false
    static ShiftHeld := false
    static LastShiftTick := 0
    static ButtonsDown := Map()
    static MovementTimer := ""
    static ScrollTimer := ""
    static HorizontalScrollTimer := ""
    static CapsLockTimer := ""
    static ResidualX := 0.0
    static ResidualY := 0.0

    static MoveInterval := 16
    static MoveStep := 10
    static ScrollInterval := 80
    static ScrollStep := 120
    static ScrollFastStep := 480
    static CapsLockCheckInterval := 250
    static ShiftEntryWindow := 450

    ; The native CapsLock light is the mode's availability gate. The physical
    ; key state is deliberately not used here because CapsLock remains a
    ; modifier for the normal shortcut layer.
    static NativeCapsLockOn() {
        return GetKeyState("CapsLock", "T") != 0
    }

    static EntryAvailable() {
        return !this.Active
            && this.NativeCapsLockOn()
            && !AppState.QuickPhraseTransactionActive
            && ApplicationProfiles.IsHotkeysEnabledForActiveWindow()
    }

    static IsActive() {
        return this.Active
    }

    ; A double tap of Shift enters the mode; one Shift exits it. The physical-key
    ; latch stops keyboard auto-repeat from counting as another tap, while the
    ; unconditional Shift-up hotkey only clears that latch. The first-tap
    ; timestamp survives Shift release so the second tap can complete the pair.
    static ToggleFromShift(*) {
        if this.ShiftHeld
            return false

        this.ShiftHeld := true

        if this.Active {
            this.LastShiftTick := 0
            return this.Stop()
        }

        now := A_TickCount
        if !this.IsDoubleShiftWithinWindow(this.LastShiftTick, now) {
            this.LastShiftTick := now
            return false
        }

        this.LastShiftTick := 0
        return this.Toggle()
    }

    static ShiftReleased(*) {
        this.ShiftHeld := false
    }

    ; Pure timing helper so the entry gesture can be tested without a keyboard.
    ; A zero or reversed timestamp never forms a pair.
    static IsDoubleShiftWithinWindow(firstTick, secondTick) {
        if !(firstTick is Integer) || !(secondTick is Integer)
            return false
        if (firstTick <= 0 || secondTick < firstTick)
            return false
        return (secondTick - firstTick) <= this.ShiftEntryWindow
    }

    static Toggle() {
        if this.Active {
            this.Stop()
            return false
        }

        if !this.EntryAvailable() {
            this.LastShiftTick := 0
            return false
        }

        return this.Start()
    }

    static Start() {
        if this.Active || !this.EntryAvailable()
            return false

        ; The sequential Shift layer owns the same top-edge toast. Deactivate
        ; it first so its Hide() cannot remove the persistent indicator.
        DeactivateShiftLayer()

        this.Active := true
        this.LastShiftTick := 0
        this.ButtonsDown := Map()
        this.ResidualX := 0.0
        this.ResidualY := 0.0

        if !ShiftLayerToast.ShowStatic(WinExist("A")) {
            this.Stop()
            return false
        }

        this.CapsLockTimer := ObjBindMethod(this, "CheckCapsLock")
        SetTimer(this.CapsLockTimer, this.CapsLockCheckInterval)
        return true
    }

    static Stop(*) {
        ; A shutdown or programmatic stop also discards half of a Shift pair, so
        ; a tap from an earlier session cannot complete a new double tap.
        this.LastShiftTick := 0

        if !this.Active
            return false

        ; Flip the flag before releasing anything so a timer callback that is
        ; already queued cannot resume movement or scrolling.
        this.Active := false

        this._StopMovementTimer()
        this._StopScrollTimer()
        this._StopHorizontalScrollTimer()
        this._ReleaseAllButtons()
        this.ResidualX := 0.0
        this.ResidualY := 0.0

        if this.CapsLockTimer != "" {
            try SetTimer(this.CapsLockTimer, 0)
            this.CapsLockTimer := ""
        }

        ShiftLayerToast.Hide()
        return true
    }

    static CheckCapsLock(*) {
        if this.Active && !this.NativeCapsLockOn()
            this.Stop()
    }

    ; -----------------------------------------------------------------------
    ; Cursor movement
    ; -----------------------------------------------------------------------

    ; Pure vector helper: cardinal input has length 1 and a diagonal pair is
    ; divided by sqrt(2), so no direction combination outruns another.
    static MovementVector(up, left, down, right) {
        dx := (right ? 1 : 0) - (left ? 1 : 0)
        dy := (down ? 1 : 0) - (up ? 1 : 0)

        if (dx == 0 && dy == 0)
            return { x: 0.0, y: 0.0 }

        if (dx != 0 && dy != 0) {
            scale := 1 / Sqrt(2)
            return { x: dx * scale, y: dy * scale }
        }

        return { x: dx * 1.0, y: dy * 1.0 }
    }

    static NormalizeSpeedPercent(value) {
        if !IsNumber(value)
            return 100

        percent := Round(value)
        if (percent < AppState.MouseControlSpeedMin)
            return AppState.MouseControlSpeedMin
        if (percent > AppState.MouseControlSpeedMax)
            return AppState.MouseControlSpeedMax
        return percent
    }

    static UpdateMovementTimer(*) {
        if !this.Active
            return

        if this._AnyDirectionHeld() {
            if !IsObject(this.MovementTimer) {
                this.MovementTimer := ObjBindMethod(this, "MovementTick")
                SetTimer(this.MovementTimer, this.MoveInterval)
            }
            return
        }

        this._StopMovementTimer()
    }

    static MovementTick(*) {
        if !this.Active {
            this._StopMovementTimer()
            return
        }

        vector := this.MovementVector(
            GetKeyState("w", "P"),
            GetKeyState("a", "P"),
            GetKeyState("s", "P"),
            GetKeyState("d", "P")
        )

        if (vector.x == 0 && vector.y == 0) {
            this.ResidualX := 0.0
            this.ResidualY := 0.0
            return
        }

        ; Fractional pixels are carried between ticks, which keeps diagonal
        ; movement smooth instead of losing the same rounding remainder every
        ; frame.
        if vector.x == 0
            this.ResidualX := 0.0
        if vector.y == 0
            this.ResidualY := 0.0

        multiplier := this.NormalizeSpeedPercent(AppState.MouseControlSpeedPercent) / 100
        this.ResidualX += vector.x * this.MoveStep * multiplier
        this.ResidualY += vector.y * this.MoveStep * multiplier

        dx := Round(this.ResidualX)
        dy := Round(this.ResidualY)
        this.ResidualX -= dx
        this.ResidualY -= dy

        if (dx != 0 || dy != 0)
            this._MouseEvent(0x0001, dx, dy)
    }

    static _AnyDirectionHeld() {
        return GetKeyState("w", "P")
            || GetKeyState("a", "P")
            || GetKeyState("s", "P")
            || GetKeyState("d", "P")
    }

    static _StopMovementTimer() {
        if IsObject(this.MovementTimer) {
            try SetTimer(this.MovementTimer, 0)
            this.MovementTimer := ""
        }
    }

    ; -----------------------------------------------------------------------
    ; Mouse buttons
    ; -----------------------------------------------------------------------

    static PressButton(name) {
        if !this.Active
            return false
        if this.ButtonsDown.Has(name)
            return true

        flags := this._ButtonDownFlag(name)
        if !flags
            return false

        this._MouseEvent(flags)
        this.ButtonsDown[name] := true
        return true
    }

    static ReleaseButton(name) {
        return this._ReleaseButton(name)
    }

    static _ReleaseButton(name) {
        if !this.ButtonsDown.Has(name)
            return false

        flags := this._ButtonUpFlag(name)
        if !flags
            return false

        this.ButtonsDown.Delete(name)
        this._MouseEvent(flags)
        return true
    }

    static _ReleaseAllButtons() {
        for name in this.ButtonsDown.Clone()
            this._ReleaseButton(name)
        this.ButtonsDown := Map()
    }

    static _ButtonDownFlag(name) {
        switch name {
            case "left":
                return 0x0002
            case "middle":
                return 0x0020
            case "right":
                return 0x0008
        }
        return 0
    }

    static _ButtonUpFlag(name) {
        switch name {
            case "left":
                return 0x0004
            case "middle":
                return 0x0040
            case "right":
                return 0x0010
        }
        return 0
    }

    ; -----------------------------------------------------------------------
    ; Wheel scrolling
    ; -----------------------------------------------------------------------

    static StartScroll(direction) {
        if !this.Active
            return false
        if (direction != "up" && direction != "down")
            return false
        if !this._ScrollKeysHeld()
            return false

        ; The hotkey fires again on keyboard auto-repeat; the running timer
        ; already provides the repeat cadence, so do not add an extra pulse.
        if IsObject(this.ScrollTimer)
            return true

        this.ScrollTimer := ObjBindMethod(this, "ScrollTick")
        SetTimer(this.ScrollTimer, this.ScrollInterval)
        this.ScrollTick()
        return true
    }

    static StopScroll(direction := "") {
        if (direction != "" && direction != "up" && direction != "down")
            return false
        if !this._ScrollKeysHeld()
            this._StopScrollTimer()
        return true
    }

    static ScrollTick(*) {
        if !this.Active {
            this._StopScrollTimer()
            return
        }

        up := GetKeyState("i", "P")
        down := GetKeyState("m", "P")

        if (up && down)
            return
        if (!up && !down) {
            this._StopScrollTimer()
            return
        }

        step := GetKeyState("Alt", "P") ? this.ScrollFastStep : this.ScrollStep
        this._MouseEvent(0x0800, 0, 0, up ? step : -step)
    }

    static _ScrollKeysHeld() {
        return GetKeyState("i", "P") || GetKeyState("m", "P")
    }

    static _StopScrollTimer() {
        if IsObject(this.ScrollTimer) {
            try SetTimer(this.ScrollTimer, 0)
            this.ScrollTimer := ""
        }
    }

    ; Horizontal wheel input uses MOUSEEVENTF_HWHEEL (0x1000). Positive data
    ; scrolls right and negative data scrolls left, matching the native wheel
    ; convention used by the vertical path above.
    static StartHorizontalScroll(direction) {
        if !this.Active
            return false
        if (direction != "left" && direction != "right")
            return false
        if !this._HorizontalScrollKeysHeld()
            return false

        if IsObject(this.HorizontalScrollTimer)
            return true

        this.HorizontalScrollTimer := ObjBindMethod(this, "HorizontalScrollTick")
        SetTimer(this.HorizontalScrollTimer, this.ScrollInterval)
        this.HorizontalScrollTick()
        return true
    }

    static StopHorizontalScroll(direction := "") {
        if (direction != "" && direction != "left" && direction != "right")
            return false
        if !this._HorizontalScrollKeysHeld()
            this._StopHorizontalScrollTimer()
        return true
    }

    static HorizontalScrollTick(*) {
        if !this.Active {
            this._StopHorizontalScrollTimer()
            return
        }

        left := GetKeyState("q", "P")
        right := GetKeyState("e", "P")

        if (left && right)
            return
        if (!left && !right) {
            this._StopHorizontalScrollTimer()
            return
        }

        step := GetKeyState("Alt", "P") ? this.ScrollFastStep : this.ScrollStep
        this._MouseEvent(0x1000, 0, 0, right ? step : -step)
    }

    static _HorizontalScrollKeysHeld() {
        return GetKeyState("q", "P") || GetKeyState("e", "P")
    }

    static _StopHorizontalScrollTimer() {
        if IsObject(this.HorizontalScrollTimer) {
            try SetTimer(this.HorizontalScrollTimer, 0)
            this.HorizontalScrollTimer := ""
        }
    }

    ; -----------------------------------------------------------------------
    ; Win32 input
    ; -----------------------------------------------------------------------

    static _MouseEvent(flags, dx := 0, dy := 0, data := 0) {
        DllCall(
            "mouse_event",
            "UInt", flags,
            "Int", dx,
            "Int", dy,
            "Int", data,
            "UPtr", 0
        )
    }
}
