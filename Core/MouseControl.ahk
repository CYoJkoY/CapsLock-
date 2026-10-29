#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Mouse control mode
;
; A modal pointer layer that is available while the native CapsLock light is
; on. Shift enters or exits, Esc exits. Cursor movement is vector-based so a
; diagonal key pair travels at the same speed as a single direction. Mouse
; buttons and the wheel are injected through Win32 mouse_event, which keeps
; the generated input away from this script's own CapsLock mouse hotkeys.
; ---------------------------------------------------------------------------
class MouseControl {
    static Active := false
    static ShiftHeld := false
    static ButtonsDown := Map()
    static MovementTimer := ""
    static ScrollTimer := ""
    static CapsLockTimer := ""
    static ResidualX := 0.0
    static ResidualY := 0.0

    static MoveInterval := 16
    static MoveStep := 10
    static ScrollInterval := 80
    static ScrollStep := 120
    static ScrollFastStep := 480
    static CapsLockCheckInterval := 250

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

    ; Shift is both the entry and exit trigger. The physical-key latch stops
    ; keyboard auto-repeat from toggling the mode repeatedly while Shift is
    ; held down; the unconditional Shift-up hotkey clears the latch.
    static ToggleFromShift(*) {
        if this.ShiftHeld
            return false

        this.ShiftHeld := true
        return this.Toggle()
    }

    static ShiftReleased(*) {
        this.ShiftHeld := false
    }

    static Toggle() {
        if this.Active {
            this.Stop()
            return false
        }

        if !this.EntryAvailable()
            return false

        return this.Start()
    }

    static Start() {
        if this.Active || !this.EntryAvailable()
            return false

        ; The sequential Shift layer owns the same top-edge toast. Deactivate
        ; it first so its Hide() cannot remove the persistent indicator.
        DeactivateShiftLayer()

        this.Active := true
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
        if !this.Active
            return false

        ; Flip the flag before releasing anything so a timer callback that is
        ; already queued cannot resume movement or scrolling.
        this.Active := false

        this._StopMovementTimer()
        this._StopScrollTimer()
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

        this.ResidualX += vector.x * this.MoveStep
        this.ResidualY += vector.y * this.MoveStep

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
