#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Provisioning for the optional C# backend (issue #12).
;
; The boundary needs exactly two files on disk before the CLR can start:
;
;   lib\CapsLockSharp.dll            the precompiled services (AnyCPU)
;   lib\ahk#\lib\ahk#.bridge.dll     the pinned AHK# bridge
;
; Nothing in here starts the CLR, so `Services.Boot()` remains the only place
; that pays the boot/JIT cost, and only for a service that is actually called.
; This module only makes those two files exist:
;
;   * a compiled EXE built by scripts\build.ps1 carries both of them as RCDATA
;     resources (see the generated CSharpPayload.ahk include). ExtractPackaged()
;     writes them next to the EXE - or into %LOCALAPPDATA%\CapsLock- when the
;     install folder is read-only - comparing SHA-256 first, so a second start
;     neither rewrites nor re-locks an already loaded DLL. It touches only the
;     local disk, because it runs inside a service call;
;   * a source checkout builds them (`dotnet build`) or, without the .NET SDK,
;     downloads the pinned AHK# bridge and the published assembly. That can
;     take seconds and needs the network, so it belongs to the explicit
;     one-click setup (EnsureFiles/Install), never to a hotkey path.
;
; Both routes keep the hash check AHK# performs at boot: the digest pinned in
; ahk#.ahk is parsed back out of the file and compared with the DLL, so a
; truncated or intercepted download is reported here instead of turning into a
; CLR boot failure later.
; ---------------------------------------------------------------------------
class CSharpRuntime {
    ; Resource names written by the generated CSharpPayload.ahk directives.
    static AssemblyResource := "CSHARP_DLL"
    static BridgeResource := "AHK_BRIDGE_DLL"

    ; Pinned AHK# commit. Keep in sync with docs/perf/csharp-boundary.md,
    ; .github/workflows/dotnet.yml and scripts\Setup-CSharpBackend.ps1.
    static BridgeCommit := "e3b895c7590eba47748b0ed963b7978c237d1daf"
    static BridgeOwner := "owhs"
    static BridgeRepo := "AHKSharp"

    ; Assembly source for a checkout without the .NET SDK: release builds
    ; publish the same AnyCPU artifact the EXE carries embedded.
    static AssemblyOwner := "CYoJkoY"
    static AssemblyRepo := "CapsLock-"

    static exitCode := 0

    ; Diagnostics of the last provisioning attempt, one line per step.
    static report := []

    static targetDir := ""
    static relocated := false
    ; Set when a write failed, so the per-user retry runs only for the one
    ; failure it can fix instead of repeating a download that cannot work.
    static writeFailed := false

    ; =======================================================================
    ; Paths
    ; =======================================================================

    ; lib\ next to the script, or a per-user folder when that is not writable.
    static TargetDir() {
        if this.targetDir != ""
            return this.targetDir

        primary := A_ScriptDir "\lib"
        if this.IsWritable(primary) {
            this.targetDir := primary
        } else {
            this.relocated := true
            perUser := EnvGet("LOCALAPPDATA")
            this.targetDir := (perUser != "" ? perUser : A_Temp) "\CapsLock-\lib"
        }
        return this.targetDir
    }

    ; An explicit override wins: the perf/equivalence harnesses point Services
    ; at their own copies, including a deliberately missing one.
    static AssemblyFile() {
        return Services.assemblyPath != ""
            ? Services.assemblyPath
            : this.TargetDir() "\CapsLockSharp.dll"
    }

    static BridgeFile() {
        return Services.bridgePath != ""
            ? Services.bridgePath
            : this.TargetDir() "\ahk#\lib\ahk#.bridge.dll"
    }

    ; Where the AHK# source checkout lives in a source run. The entry script
    ; has `#Include *i lib\ahk#\lib\ahk#.ahk`, which is resolved at load time,
    ; so the library file always belongs next to the script even when the
    ; runtime files had to move to the per-user folder.
    static BridgeSourceDir() {
        return A_ScriptDir "\lib\ahk#\lib"
    }

    static HasOverride() {
        return Services.assemblyPath != "" || Services.bridgePath != ""
    }

    ; Only needed after a relocation: Services' own defaults already point at
    ; lib\ next to the script, which is the normal target.
    static PublishPaths() {
        Services.assemblyPath := this.TargetDir() "\CapsLockSharp.dll"
        Services.bridgePath := this.TargetDir() "\ahk#\lib\ahk#.bridge.dll"
    }

    ; Nothing is created here: a read-only install must not gain an empty lib\
    ; folder just because the Settings Center rendered a status line.
    static IsWritable(dir) {
        try {
            probe := ""
            if DirExist(dir) {
                probe := dir "\.capslock-probe.tmp"
            } else {
                SplitPath(dir, , &parent)
                if !DirExist(parent)
                    return false
                probe := parent "\.capslock-probe.tmp"
            }
            FileAppend("x", probe, "UTF-8")
            FileDelete(probe)
            return true
        } catch {
            return false
        }
    }

    ; =======================================================================
    ; Packaged payload (compiled EXE)
    ; =======================================================================

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

    static HasPackagedPayload() {
        return this.ResourceSize(this.AssemblyResource) > 0
            && this.ResourceSize(this.BridgeResource) > 0
    }

    ; Read an RCDATA resource of this compiled EXE. Returns a Buffer, or ""
    ; when running from source or when the resource is absent - a pure-AHK
    ; build simply has no payload and stays pure AHK.
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

    ; The only provisioning a service call may trigger: unpack what this EXE
    ; already contains. No network, no compiler, no CLR.
    static ExtractPackaged() {
        if !A_IsCompiled || this.HasOverride()
            return false
        if !this.HasPackagedPayload()
            return false
        this.writeFailed := false
        if this.ExtractOnce()
            return true
        if this.relocated || !this.writeFailed
            return false

        ; A read-only install folder is the one recoverable failure.
        this.report.Push("install folder is not writable, using the per-user folder")
        this.relocated := true
        this.targetDir := ""
        this.PublishPaths()
        return this.ExtractOnce()
    }

    static ExtractOnce() {
        this.WritePackaged(this.AssemblyResource, this.AssemblyFile(), "CapsLockSharp.dll")
        this.WritePackaged(this.BridgeResource, this.BridgeFile(), "ahk#.bridge.dll")
        return FileExist(this.AssemblyFile()) && FileExist(this.BridgeFile())
    }

    static WritePackaged(resource, path, label) {
        data := this.ReadResource(resource)
        if data == ""
            return false
        return this.WriteIfDifferent(path, data, label " (packaged)")
    }

    ; Writes only when the bytes differ, so an already loaded bridge DLL is
    ; never deleted underneath the CLR and a normal start writes nothing.
    static WriteIfDifferent(path, data, label := "") {
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

            file := FileOpen(path, "w", "RAW")
            file.RawWrite(data, data.Size)
            file.Close()

            if FileGetSize(path) != data.Size
                throw Error("written size mismatch")

            this.report.Push("wrote " label ": " path " (" data.Size " bytes)")
            return true
        } catch as err {
            this.writeFailed := true
            this.report.Push("could not write " path ": " err.Message)
            return false
        }
    }

    ; =======================================================================
    ; Full provisioning (explicit setup only)
    ; =======================================================================

    ; Makes both runtime files exist without starting the CLR. May build or
    ; download, so it is only called by the one-click setup and the CLI.
    static EnsureFiles() {
        this.report := []

        if this.HasOverride() {
            this.report.Push("service paths are explicitly configured, not provisioning")
            return FileExist(this.AssemblyFile()) && FileExist(this.BridgeFile())
        }

        this.writeFailed := false
        ok := this.Provision()
        if !ok && this.writeFailed && !this.relocated {
            this.report.Push("retrying in the per-user folder")
            this.relocated := true
            this.targetDir := ""
            this.PublishPaths()
            ok := this.Provision()
        }

        if !FileExist(this.AssemblyFile())
            this.report.Push("missing: " this.AssemblyFile())
        if !FileExist(this.BridgeFile())
            this.report.Push("missing: " this.BridgeFile())

        return ok
    }

    static Provision() {
        try {
            ; Repeatable and cheap when the payload is present: only what
            ; actually differs is written.
            if this.HasPackagedPayload() {
                this.WritePackaged(this.AssemblyResource, this.AssemblyFile(), "CapsLockSharp.dll")
                this.WritePackaged(this.BridgeResource, this.BridgeFile(), "ahk#.bridge.dll")
            } else if A_IsCompiled {
                this.report.Push("this build carries no packaged C# payload")
            }

            if !FileExist(this.AssemblyFile())
                this.FetchAssembly()
            if !FileExist(this.BridgeFile())
                this.FetchBridge()
        } catch as err {
            this.report.Push("provisioning failed: " err.Message)
            return false
        }
        return FileExist(this.AssemblyFile()) && FileExist(this.BridgeFile())
    }

    ; --- assembly ----------------------------------------------------------

    static FetchAssembly() {
        ; An assembly built by scripts\Setup-CSharpBackend.ps1 is already at
        ; the default path and is found before this runs.
        project := A_ScriptDir "\src\CapsLockSharp\CapsLockSharp.csproj"
        if FileExist(project) && this.BuildAssembly(project)
            return true

        ; Without the .NET SDK: the published AnyCPU assembly.
        this.DownloadAssembly()
        return FileExist(this.AssemblyFile())
    }

    static BuildAssembly(project) {
        out := A_ScriptDir "\lib"
        command := 'dotnet build "' project '" -c Release --nologo -v quiet -o "' out '"'
        exitCode := 0
        try {
            ; RunWait throws when dotnet is not on PATH, which is the normal
            ; case on a machine that only runs the application.
            RunWait(command, A_ScriptDir, "Hide", &exitCode)
        } catch as err {
            this.report.Push("dotnet build unavailable: " err.Message)
            return false
        }

        if exitCode != 0 {
            this.report.Push("dotnet build exited with code " exitCode)
            return false
        }

        built := out "\CapsLockSharp.dll"
        if !FileExist(built) {
            this.report.Push("dotnet build produced no " built)
            return false
        }

        ; A relocated target needs a copy of the freshly built assembly.
        if this.AssemblyFile() != built
            return this.CopyFile(built, this.AssemblyFile(), "CapsLockSharp.dll (built)")

        this.report.Push("built " built)
        return true
    }

    static DownloadAssembly() {
        url := "https://github.com/" this.AssemblyOwner "/" this.AssemblyRepo
            . "/releases/latest/download/CapsLockSharp.dll"
        this.DownloadTo(url, this.AssemblyFile(), "CapsLockSharp.dll")
    }

    ; --- bridge ------------------------------------------------------------

    static FetchBridge() {
        ; The documented checkout location already has it (git clone or an
        ; earlier download): copy it when the runtime location differs.
        source := this.BridgeSourceDir() "\ahk#.bridge.dll"
        if this.BridgeFile() != source && FileExist(source)
            return this.CopyFile(source, this.BridgeFile(), "ahk#.bridge.dll (checkout)")

        this.DownloadBridge()
        return FileExist(this.BridgeFile())
    }

    ; One pinned commit, three files: the library the entry script #Includes
    ; (used by a source run), the bridge DLL the CLR loads, and the rebuild
    ; script that keeps the folder working like a git clone.
    static DownloadBridge() {
        base := "https://raw.githubusercontent.com/" this.BridgeOwner "/" this.BridgeRepo
            . "/" this.BridgeCommit "/lib/"
        dir := this.BridgeSourceDir()

        this.DownloadTo(base "ahk%23.ahk", dir "\ahk#.ahk", "ahk#.ahk")
        this.DownloadTo(base "ahk%23.bridge.dll", dir "\ahk#.bridge.dll", "ahk#.bridge.dll")
        this.DownloadTo(base "build.ps1", dir "\build.ps1", "build.ps1")

        if !FileExist(dir "\ahk#.bridge.dll")
            return false

        if !this.VerifyBridgeDigest(dir "\ahk#.ahk", dir "\ahk#.bridge.dll") {
            try FileDelete(dir "\ahk#.bridge.dll")
            return false
        }

        if this.BridgeFile() != dir "\ahk#.bridge.dll"
            return this.CopyFile(dir "\ahk#.bridge.dll", this.BridgeFile(), "ahk#.bridge.dll (downloaded)")

        return true
    }

    ; AHK# refuses a bridge whose SHA-256 differs from the digest pinned in its
    ; own source. Check it here as well: a corrupt download then produces one
    ; understandable line instead of a failed CLR boot.
    static VerifyBridgeDigest(libraryPath, bridgePath) {
        pinned := ""
        try {
            text := FileRead(libraryPath, "UTF-8")
            if RegExMatch(text, "i)AHK_SHARP_BRIDGE_SHA256[^0-9a-fA-F]+([0-9a-fA-F]{64})", &match)
                pinned := StrLower(match[1])
        } catch as err {
            this.report.Push("bridge digest unreadable: " err.Message)
        }

        if pinned == "" {
            ; AHK# still verifies at boot, so this is not a file failure.
            this.report.Push("bridge digest not found in ahk#.ahk (AHK# checks it at boot)")
            return true
        }

        actual := Sha256File(bridgePath)
        if actual != pinned {
            this.report.Push("bridge SHA-256 mismatch: expected " pinned ", got " actual)
            return false
        }

        this.report.Push("bridge SHA-256 verified: " pinned)
        return true
    }

    ; --- shared helpers ----------------------------------------------------

    static DownloadTo(url, path, label) {
        try {
            SplitPath(path, , &dir)
            if !DirExist(dir)
                DirCreate(dir)
            if FileExist(path)
                FileDelete(path)

            ; Download follows redirects and writes the response body verbatim.
            Download(url, path)

            if !FileExist(path) || FileGetSize(path) == 0
                throw Error("empty response")

            this.report.Push("downloaded " label " (" FileGetSize(path) " bytes)")
            return true
        } catch as err {
            this.report.Push("download failed for " label ": " err.Message)
            try {
                if FileExist(path)
                    FileDelete(path)
            }
            return false
        }
    }

    static CopyFile(source, target, label) {
        try {
            SplitPath(target, , &dir)
            if !DirExist(dir)
                DirCreate(dir)

            if FileExist(target) {
                existing := Sha256File(target)
                if existing != "" && existing == Sha256File(source) {
                    this.report.Push("already present: " target)
                    return true
                }
                FileDelete(target)
            }

            FileCopy(source, target)
            this.report.Push("wrote " label ": " target)
            return true
        } catch as err {
            this.writeFailed := true
            this.report.Push("could not copy " source ": " err.Message)
            return false
        }
    }

    ; =======================================================================
    ; One-click setup
    ; =======================================================================

    ; The whole setup in one call, from the Settings Center button:
    ; files -> setting -> one real managed call. Returns a Map with
    ; ok / message / details / restartNeeded / active.
    static Install() {
        result := Map(
            "ok", false, "message", "", "details", [],
            "restartNeeded", false, "active", false
        )

        try {
            hasBridgeCode := Services.HaveBridge()

            ; The AHK# library is #Included at compile time. An EXE built
            ; without it can never reach the CLR, and no file on disk can add
            ; it - say so instead of downloading anything.
            if !hasBridgeCode && A_IsCompiled {
                result.message := Lang("MSG_CSHARP_NO_BRIDGE")
                result.details.Push("this build has no AHK# bridge compiled in")
                return result
            }

            ensured := this.EnsureFiles()
            result.details := this.ReportLines()

            if !ensured {
                result.message := Lang("MSG_CSHARP_FAILED")
                return result
            }

            if !hasBridgeCode {
                ; Source run: the files are in place, but `#Include *i` was
                ; resolved when this process started, so CS does not exist yet.
                this.Enable()
                result.ok := true
                result.restartNeeded := true
                result.message := Lang("MSG_CSHARP_RESTART")
                return result
            }

            if Services.tripped {
                ; The files are in place, but the breaker is deliberately sticky
                ; for the whole process, so only a restart finishes the switch.
                result.ok := true
                result.restartNeeded := true
                result.message := Lang("MSG_CSHARP_RESTART")
                result.details.Push("circuit breaker tripped: " Services.reason)
                return result
            }

            this.Enable()
            if !this.Verify() {
                result.details := this.ReportLines()
                result.details.Push("backend: " Services.reason)
                result.message := Lang("MSG_CSHARP_FAILED")
                return result
            }

            result.ok := true
            result.active := true
            result.message := Lang("MSG_CSHARP_DONE")
            return result
        } catch as err {
            result.message := Lang("MSG_CSHARP_FAILED")
            result.details.Push(err.Message)
            return result
        }
    }

    static Enable() {
        AppState.ServiceBackend := "csharp"
        Services.Configure()
        ConfigManager.Save()
    }

    static Disable() {
        AppState.ServiceBackend := "ahk"
        Services.Configure()
        ConfigManager.Save()
    }

    ; One real call through the bridge. Dispatch falls back to AHK silently on
    ; failure, so success is read from Services' own counters.
    static Verify() {
        if !Services.HaveBridge()
            return false

        Services.Configure()
        if !Services.IsEnabled()
            return false

        calls := Services.calls
        try {
            Services.LooksLikeFilePathList("C:\Windows\notepad.exe")
        }

        if Services.ready && !Services.tripped && Services.calls > calls {
            this.report.Push("managed call succeeded")
            return true
        }

        this.report.Push("managed call failed: " Services.reason)
        return false
    }

    ; =======================================================================
    ; Status
    ; =======================================================================

    static HaveFiles() {
        return FileExist(this.AssemblyFile()) && FileExist(this.BridgeFile())
    }

    ; One line for the Settings Center. Never starts the CLR, never writes.
    static StatusText() {
        if Services.tripped
            return Lang("MSG_CSHARP_TRIPPED")
        if Services.backend == "csharp" && Services.ready
            return Lang("MSG_CSHARP_ACTIVE")
        if this.HaveFiles()
            return Lang("MSG_CSHARP_READY")
        if this.HasPackagedPayload()
            return Lang("MSG_CSHARP_PACKAGED")
        return Lang("MSG_CSHARP_MISSING")
    }

    static ReportLines() {
        lines := []
        for entry in this.report
            lines.Push(entry)
        return lines
    }

    ; =======================================================================
    ; Headless diagnostics
    ; =======================================================================

    ; Handles the diagnostic switches and returns true when one was given, so
    ; the entry script exits before any hotkey, tray icon or timer exists.
    ; #SingleInstance Force has already replaced a running instance by then,
    ; so run these while CapsLock- is not running.
    static HandleArgs(args) {
        for arg in args {
            value := StrLower(Trim(String(arg)))
            if value != "-probecsharp" && value != "-installcsharp"
                continue

            ; Headless.ahk is not injected into a compiled EXE, so an error
            ; dialog here would hang an unattended run until it is killed.
            try {
                if value == "-probecsharp"
                    return this.Probe()
                return this.RunInstall()
            } catch as err {
                this.Say("error: " err.Message)
                this.exitCode := 1
                return true
            }
        }
        return false
    }

    static Say(text) {
        try
            FileAppend(text "`n", "*", "UTF-8-RAW")
    }

    static RunInstall() {
        this.Say("installing the C# backend")
        result := this.Install()
        this.Say("ok=" (result["ok"] ? 1 : 0))
        this.Say("restart_needed=" (result["restartNeeded"] ? 1 : 0))
        this.Say("message=" result["message"])
        for line in result["details"]
            this.Say("  " line)
        this.exitCode := result["ok"] ? 0 : 1
        return true
    }

    ; Prints what the boundary looks like in this process and exits. The exit
    ; code is 1 only when a packaged payload failed to work: a pure-AHK build
    ; has nothing to verify and is a valid configuration.
    static Probe() {
        packaged := this.HasPackagedPayload()
        this.Say("compiled=" (A_IsCompiled ? 1 : 0))
        this.Say("bridge_code=" (Services.HaveBridge() ? 1 : 0))
        this.Say("packaged_assembly_bytes=" this.ResourceSize(this.AssemblyResource))
        this.Say("packaged_bridge_bytes=" this.ResourceSize(this.BridgeResource))

        ensured := this.EnsureFiles()
        this.Say("assembly=" this.AssemblyFile())
        this.Say("assembly_bytes=" (FileExist(this.AssemblyFile()) ? FileGetSize(this.AssemblyFile()) : 0))
        this.Say("bridge=" this.BridgeFile())
        this.Say("bridge_bytes=" (FileExist(this.BridgeFile()) ? FileGetSize(this.BridgeFile()) : 0))
        this.Say("files_ok=" (ensured ? 1 : 0))
        for line in this.ReportLines()
            this.Say("  " line)

        verified := false
        if Services.HaveBridge() {
            AppState.ServiceBackend := "csharp"
            verified := this.Verify()
            this.Say("managed_call_ok=" (verified ? 1 : 0))
            this.Say("backend=" Services.backend)
            this.Say("ready=" (Services.ready ? 1 : 0))
            this.Say("tripped=" (Services.tripped ? 1 : 0))
            this.Say("reason=" Services.reason)
        } else {
            this.Say("managed_call_ok=skipped (no AHK# in this build)")
        }

        this.exitCode := (packaged && !(ensured && verified)) ? 1 : 0
        this.Say("probe_exit=" this.exitCode)
        return true
    }
}
