#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; The C# payload a compiled EXE carries, and nothing else.
;
; scripts\build.ps1 has the generated CSharpPayload.ahk include add two RCDATA
; resources to the executable:
;
;   CSHARP_DLL        lib\CapsLockSharp.dll          the services (AnyCPU)
;   AHK_BRIDGE_DLL    lib\ahk#\lib\ahk#.bridge.dll   the pinned AHK# bridge
;
; This class reads those resources and writes them to disk. The CLR needs real
; files: the bridge is loaded by path and the assembly is loaded by path, so
; extraction happens before Services.Boot() asks for either.
;
; It is deliberately dependency-free apart from Utils\Hash.ahk. Core\Services.ahk
; unpacks the payload on first need, and Services is also loaded by the headless
; harnesses (scripts\perf\ServiceEquivalence.ahk, scripts\HistoryGuiPaging.ahk,
; scripts\perf\CapsLockProfile.ahk) - a reference to Lang(), ConfigManager or
; anything else they do not define would fail their load, which is exactly what
; a setup/UI-facing module would do here. Setup, downloads and the one-click
; flow live in Core\CSharpRuntime.ahk instead.
;
; Nothing in this file starts the CLR.
; ---------------------------------------------------------------------------
class CSharpPayload {
    static AssemblyResource := "CSHARP_DLL"
    static BridgeResource := "AHK_BRIDGE_DLL"

    ; One line per attempt, for the diagnostics that report on a failure.
    static report := []

    ; Size without copying the bytes, for the cheap "is it packaged" check.
    static ResourceSize(name) {
        if !A_IsCompiled
            return 0

        module := DllCall("kernel32\GetModuleHandle", "Ptr", 0, "Ptr")
        if !module
            return 0

        ; 10 = RT_RCDATA, the type Ahk2Exe picks for a .dll AddResource.
        resource := DllCall("kernel32\FindResource", "Ptr", module, "Str", name, "Ptr", 10, "Ptr")
        if !resource
            return 0

        return DllCall("kernel32\SizeofResource", "Ptr", module, "Ptr", resource, "UInt")
    }

    ; A pure-AHK build has no payload at all, which is a valid configuration.
    static HasPayload() {
        return this.ResourceSize(this.AssemblyResource) > 0
            && this.ResourceSize(this.BridgeResource) > 0
    }

    ; Returns a Buffer, or "" when running from source or when the resource is
    ; absent.
    static ReadResource(name) {
        size := this.ResourceSize(name)
        if !size
            return ""

        module := DllCall("kernel32\GetModuleHandle", "Ptr", 0, "Ptr")
        resource := DllCall("kernel32\FindResource", "Ptr", module, "Str", name, "Ptr", 10, "Ptr")
        handle := DllCall("kernel32\LoadResource", "Ptr", module, "Ptr", resource, "Ptr")
        if !handle
            return ""

        source := DllCall("kernel32\LockResource", "Ptr", handle, "Ptr")
        if !source
            return ""

        data := Buffer(size, 0)
        DllCall("kernel32\RtlMoveMemory", "Ptr", data.Ptr, "Ptr", source, "UPtr", size)
        return data
    }

    ; Writes both files under libDir, falling back to fallbackDir when libDir
    ; will not take them (an install under Program Files). Returns
    ; [assemblyPath, bridgePath], or "" when neither location worked.
    static ExtractTo(libDir, fallbackDir := "") {
        this.report := []

        found := this.WriteBoth(libDir)
        if IsObject(found)
            return found

        if fallbackDir == "" || fallbackDir == libDir
            return ""

        this.report.Push("install folder is not writable, using the per-user folder")
        return this.WriteBoth(fallbackDir)
    }

    static WriteBoth(libDir) {
        assembly := libDir "\CapsLockSharp.dll"
        bridge := libDir "\ahk#\lib\ahk#.bridge.dll"

        wroteAssembly := this.WriteResource(this.AssemblyResource, assembly, "CapsLockSharp.dll")
        wroteBridge := this.WriteResource(this.BridgeResource, bridge, "ahk#.bridge.dll")

        return (wroteAssembly && wroteBridge) ? [assembly, bridge] : ""
    }

    ; Writes only when the bytes differ, so a normal start writes nothing and a
    ; bridge the CLR has already loaded is never deleted underneath it.
    static WriteResource(resource, path, label) {
        data := this.ReadResource(resource)
        if !IsObject(data)
            return false

        try {
            if FileExist(path) {
                existing := Sha256File(path)
                if existing != "" && existing == Sha256BufferHex(data) {
                    this.report.Push("already present: " path)
                    return true
                }
                FileDelete(path)
            }

            SplitPath(path, , &dir)
            if !DirExist(dir)
                DirCreate(dir)

            ; RawWrite is byte-exact and writes no BOM, which is what the
            ; history file relies on too (History\HistoryStorage.ahk). The
            ; "RAW" encoding people remember from v1 does not exist in v2 -
            ; FileOpen only knows "UTF-8", "UTF-8-RAW", "UTF-16",
            ; "UTF-16-RAW" and CP0/CPnnn, and throws for anything else.
            file := FileOpen(path, "w")
            file.RawWrite(data, data.Size)
            file.Close()

            if FileGetSize(path) != data.Size
                throw Error("written size mismatch")

            this.report.Push("wrote " label ": " path " (" data.Size " bytes)")
            return true
        } catch as err {
            this.report.Push("could not write " path ": " err.Message)
            return false
        }
    }

    static ReportLines() {
        lines := []
        for entry in this.report
            lines.Push(entry)
        return lines
    }
}
