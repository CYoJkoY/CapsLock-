#Requires AutoHotkey v2.0

; ---------------------------------------------------------------------------
; Provisioning for the optional C# backend (issue #12): the one-click setup in
; the Settings Center, and the headless switches behind it.
;
; The boundary needs exactly two files on disk before the CLR can start:
;
;   lib\CapsLockSharp.dll            the precompiled services (AnyCPU)
;   lib\ahk#\lib\ahk#.bridge.dll     the pinned AHK# bridge
;
; This module makes them exist:
;
;   * a compiled EXE carries both as resources; Core\CSharpPayload.ahk unpacks
;     them (Services.Boot() already does that on first need, so a packaged
;     build normally never reaches the routes below);
;   * a source checkout builds the assembly with the .NET SDK, or downloads the
;     pinned AHK# bridge and the published assembly when there is no SDK.
;
; Building and downloading can take seconds and needs the network, so none of
; it runs from a service call: Services.Boot() only unpacks a packaged payload
; (local disk, no CLR), and everything here is reached from the setup button or
; from -InstallCSharp.
;
; Both routes keep the hash check AHK# performs at boot: the digest pinned in
; ahk#.ahk is parsed back out of the file and compared with the DLL, so a
; truncated or intercepted download is reported here instead of turning into a
; CLR boot failure later.
;
; Unlike Core\CSharpPayload.ahk this file is loaded by CapsLock-.ahk only: it
; uses Lang(), ConfigManager and the Settings Center, which the headless
; harnesses do not define.
; ---------------------------------------------------------------------------
class CSharpRuntime {
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
    static lastFailureStage := ""
    static lastFailureHint := ""
    static lastReportPath := ""

    static cachedDir := ""
    static relocated := false

    ; =======================================================================
    ; Paths
    ; =======================================================================

    ; Per-user folder for an install whose own folder will not take files.
    static PerUserDir() {
        perUser := EnvGet("LOCALAPPDATA")
        return (perUser != "" ? perUser : A_Temp) "\CapsLock-\lib"
    }

    ; lib\ next to the script, or the per-user folder when that is not writable.
    static TargetDir() {
        if this.cachedDir != ""
            return this.cachedDir

        primary := A_ScriptDir "\lib"
        this.cachedDir := this.IsWritable(primary) ? primary : this.PerUserDir()
        if this.cachedDir != primary
            this.relocated := true
        return this.cachedDir
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

    ; Tell Services where the files ended up, so its own defaults are not the
    ; only places Boot() looks.
    static AdoptPaths(assemblyPath, bridgePath) {
        Services.assemblyPath := assemblyPath
        Services.bridgePath := bridgePath
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
    ; Environment and .NET 8 / winget detection
    ; =======================================================================

    ; Refreshes process PATH from machine and user registry so recently
    ; installed tools (e.g. dotnet or winget) are visible immediately.
    static RefreshEnvironmentPath() {
        hklmPath := ""
        hkcuPath := ""
        try hklmPath := RegRead("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment", "Path")
        try hkcuPath := RegRead("HKEY_CURRENT_USER\Environment", "Path")
        combined := hklmPath . (hklmPath != "" && hkcuPath != "" ? ";" : "") . hkcuPath

        for dir in this.StandardDotNetDirs() {
            if DirExist(dir) && !InStr(";" . combined . ";", ";" . dir . ";") {
                combined := dir . ";" . combined
            }
        }

        if combined != ""
            EnvSet("PATH", combined)
        return combined
    }

    static StandardDotNetDirs() {
        dirs := []
        pf := EnvGet("ProgramFiles")
        if pf != ""
            dirs.Push(pf "\dotnet")
        pf86 := EnvGet("ProgramFiles(x86)")
        if pf86 != ""
            dirs.Push(pf86 "\dotnet")
        pf64 := EnvGet("ProgramW6432")
        if pf64 != ""
            dirs.Push(pf64 "\dotnet")
        localApp := EnvGet("LOCALAPPDATA")
        if localApp != ""
            dirs.Push(localApp "\Microsoft\dotnet")
        return dirs
    }

    static AddDotNetCandidate(candidates, seen, candidate) {
        candidate := Trim(String(candidate))
        if candidate == ""
            return

        key := StrLower(candidate)
        if seen.Has(key)
            return

        seen[key] := true
        candidates.Push(candidate)
    }

    ; Return every plausible host, not just the first `dotnet.exe` found.
    ; A 32-bit CapsLock- process can see the x86 installation first even when
    ; the only .NET 8 SDK is under ProgramW6432; selecting the first host made
    ; setup report a missing SDK and then fail its build on those machines.
    static DotNetCandidates() {
        this.RefreshEnvironmentPath()
        candidates := []
        seen := Map()

        for dir in this.StandardDotNetDirs() {
            if dir == ""
                continue
            candidate := dir "\dotnet.exe"
            if FileExist(candidate)
                this.AddDotNetCandidate(candidates, seen, candidate)
        }

        tempFile := A_Temp "\capslock_where_dotnet_" A_TickCount ".tmp"
        try {
            exitCode := 0
            RunWait('cmd.exe /c "where dotnet > "' tempFile '" 2>nul"', , "Hide", &exitCode)
            if exitCode == 0 && FileExist(tempFile) {
                out := FileRead(tempFile, "UTF-8")
                for line in StrSplit(out, "`n", "`r") {
                    candidate := Trim(line)
                    if candidate != "" && FileExist(candidate)
                        this.AddDotNetCandidate(candidates, seen, candidate)
                }
            }
        } catch {
        }
        try if FileExist(tempFile)
            FileDelete(tempFile)

        ; Keep PATH resolution as the last candidate for installations in a
        ; non-standard directory that `where` can still resolve.
        this.AddDotNetCandidate(candidates, seen, "dotnet")
        return candidates
    }

    static HasDotNet8Sdk(dotnetExe) {
        if dotnetExe == ""
            return false

        processId := DllCall("kernel32\GetCurrentProcessId", "UInt")
        tempFile := A_Temp "\capslock_dotnet_probe_" processId "_" A_TickCount ".tmp"
        try {
            exitCode := 0
            command := 'cmd.exe /c ""' dotnetExe '" --list-sdks > "' tempFile '" 2>&1"'
            RunWait(command, , "Hide", &exitCode)
            if exitCode != 0 || !FileExist(tempFile)
                return false

            raw := FileRead(tempFile, "UTF-8")
            for line in StrSplit(raw, "`n", "`r") {
                if RegExMatch(Trim(line), "i)^8\.")
                    return true
            }
        } catch {
            return false
        } finally {
            try if FileExist(tempFile)
                FileDelete(tempFile)
        }

        return false
    }

    static GetDotNetExecutable() {
        candidates := this.DotNetCandidates()

        ; Prefer a host with the SDK required by the project, even if a
        ; different architecture/version happens to appear first on PATH.
        for candidate in candidates {
            if this.HasDotNet8Sdk(candidate)
                return candidate
        }

        for candidate in candidates {
            if candidate == "dotnet" || FileExist(candidate)
                return candidate
        }
        return "dotnet"
    }

    ; Detects whether .NET is installed, whether .NET 8 SDK is specifically present,
    ; and whether .NET Framework 4.7.2+ is available for AHK# bridge.
    static DetectDotNet8() {
        dotnetExe := this.GetDotNetExecutable()
        info := {
            installed: false,
            dotnetExe: "",
            hasSdk8: false,
            sdk8Version: "",
            allSdks: [],
            version: "",
            hasNetFramework48: this.DetectNetFramework48()
        }

        tempFile := A_Temp "\capslock_dotnet_sdks_" A_TickCount ".tmp"
        try {
            exitCode := 0
            RunWait('cmd.exe /c ""' dotnetExe '" --list-sdks > "' tempFile '" 2>&1"', , "Hide", &exitCode)
            if exitCode == 0 && FileExist(tempFile) {
                raw := FileRead(tempFile, "UTF-8")
                for line in StrSplit(raw, "`n", "`r") {
                    trimmed := Trim(line)
                    if !RegExMatch(trimmed, "i)^(\d+\.\d+)", &versionMatch)
                        continue

                    info.installed := true
                    info.dotnetExe := dotnetExe
                    info.allSdks.Push(trimmed)
                    if RegExMatch(trimmed, "i)^8\.\d+[\.\d\w\-]*", &match) {
                        info.hasSdk8 := true
                        if info.sdk8Version == ""
                            info.sdk8Version := match[0]
                    }
                }
            }
        } catch {
        }
        try if FileExist(tempFile)
            FileDelete(tempFile)

        if !info.hasSdk8 {
            tempVerFile := A_Temp "\capslock_dotnet_ver_" A_TickCount ".tmp"
            try {
                exitCode := 0
                RunWait('cmd.exe /c ""' dotnetExe '" --version > "' tempVerFile '" 2>&1"', , "Hide", &exitCode)
                if exitCode == 0 && FileExist(tempVerFile) {
                    ver := Trim(FileRead(tempVerFile, "UTF-8"))
                    if RegExMatch(ver, "i)^(\d+\.\d+)", &match) {
                        info.installed := true
                        info.dotnetExe := dotnetExe
                        info.version := ver
                        if RegExMatch(ver, "^8\.\d+", &match) {
                            info.hasSdk8 := true
                            info.sdk8Version := ver
                        }
                    }
                }
            } catch {
            }
            try if FileExist(tempVerFile)
                FileDelete(tempVerFile)
        }

        return info
    }

    static DetectNetFramework48() {
        try {
            rel := RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full", "Release")
            return Integer(rel) >= 461808
        } catch {
            return false
        }
    }

    static DetectWinget() {
        this.RefreshEnvironmentPath()

        localApp := EnvGet("LOCALAPPDATA")
        if localApp != "" {
            candidate := localApp "\Microsoft\WindowsApps\winget.exe"
            if FileExist(candidate)
                return candidate
        }

        tempFile := A_Temp "\capslock_where_winget_" A_TickCount ".tmp"
        try {
            exitCode := 0
            RunWait('cmd.exe /c "where winget > "' tempFile '" 2>nul"', , "Hide", &exitCode)
            if exitCode == 0 && FileExist(tempFile) {
                out := Trim(FileRead(tempFile, "UTF-8"))
                FileDelete(tempFile)
                if out != "" {
                    firstLine := StrSplit(out, "`n", "`r")[1]
                    if FileExist(firstLine)
                        return firstLine
                }
            }
        } catch {
        }
        try if FileExist(tempFile)
            FileDelete(tempFile)

        return "winget"
    }

    static HasWinget() {
        wingetExe := this.DetectWinget()
        exitCode := 0
        try {
            RunWait('cmd.exe /c ""' wingetExe '" --version >nul 2>&1"', , "Hide", &exitCode)
            return exitCode == 0
        } catch {
            return false
        }
    }

    ; Installs .NET 8 SDK strictly via winget source (--source winget) without Microsoft Store.
    ; Runs with console progress so the user sees live download/install percentage.
    static InstallDotNet8ViaWinget(onProgress := "") {
        wingetExe := this.DetectWinget()

        if IsObject(onProgress)
            onProgress.Call(25, Lang("MSG_CSHARP_WINGET_INSTALLING"), "winget install --id Microsoft.DotNet.SDK.8 --source winget")

        installCmd := '"' wingetExe '" install --id Microsoft.DotNet.SDK.8 --source winget --accept-source-agreements --accept-package-agreements'
        consoleCmd := 'cmd.exe /c "title CapsLock- .NET 8 SDK 安装向导 && echo =================================================== && echo   CapsLock- .NET 8 SDK 安装向导 && echo   正在通过 winget 下载并安装 .NET 8 SDK，请稍候... && echo   [数据源: winget 官方源，不依赖微软商店] && echo =================================================== && echo. && ' installCmd ' && echo. && echo 安装流程已完成，窗口即将自动关闭... && timeout /t 3 >nul"'

        exitCode := 0
        try {
            RunWait(consoleCmd, , "", &exitCode)
        } catch as err {
            this.report.Push("winget execution failed: " err.Message)
            return false
        }

        this.RefreshEnvironmentPath()

        dotNetInfo := this.DetectDotNet8()
        if dotNetInfo.hasSdk8 {
            this.report.Push("installed .NET 8 SDK (" dotNetInfo.sdk8Version ") via winget")
            return true
        }

        this.report.Push("winget finished (exit code " exitCode "), but .NET 8 SDK was not detected")
        return false
    }

    ; =======================================================================
    ; Provisioning
    ; =======================================================================

    ; Makes both runtime files exist without starting the CLR. May build or
    ; download, so it is only called by the one-click setup and the CLI.
    static EnsureFiles(onProgress := "") {
        ; Callers initialise `report` once per attempt. Preserve environment and
        ; winget diagnostics recorded before provisioning instead of silently
        ; replacing them here.
        if this.HasOverride() {
            this.report.Push("service paths are explicitly configured, not provisioning")
            return FileExist(this.AssemblyFile()) && FileExist(this.BridgeFile())
        }

        ok := this.Provision(onProgress)

        if !FileExist(this.AssemblyFile())
            this.report.Push("missing: " this.AssemblyFile())
        if !FileExist(this.BridgeFile())
            this.report.Push("missing: " this.BridgeFile())

        return ok
    }

    static Provision(onProgress := "") {
        try {
            ; Repeatable and cheap when the payload is present: only bytes that
            ; actually differ are written, and an unwritable install folder
            ; falls back to the per-user one.
            if CSharpPayload.HasPayload() {
                found := CSharpPayload.ExtractTo(this.TargetDir(), this.PerUserDir())
                for line in CSharpPayload.ReportLines()
                    this.report.Push(line)
                if IsObject(found) {
                    if found[1] != this.AssemblyFile() || found[2] != this.BridgeFile()
                        this.AdoptPaths(found[1], found[2])
                }
            } else if A_IsCompiled {
                this.report.Push("this build carries no packaged C# payload")
            }

            ; A previous interrupted setup can leave a non-empty but damaged
            ; bridge DLL. Do not copy it forward just because it exists: AHK#
            ; validates the bridge against the digest in its adjacent library.
            bridgeSource := this.BridgeSourceDir()
            bridgeLibrary := bridgeSource "\ahk#.ahk"
            bridgeAssembly := bridgeSource "\ahk#.bridge.dll"
            if (FileExist(bridgeLibrary) && FileExist(bridgeAssembly)
                && !this.VerifyBridgeDigest(bridgeLibrary, bridgeAssembly)) {
                this.report.Push("discarding an invalid existing AHK# bridge and fetching it again")
                try FileDelete(bridgeAssembly)
            }

            ; An assembly built by scripts\Setup-CSharpBackend.ps1 is already at
            ; the default path and is found by the checks above.
            if !FileExist(this.AssemblyFile())
                this.FetchAssembly(onProgress)
            if !FileExist(this.BridgeFile())
                this.FetchBridge(onProgress)
        } catch as err {
            detail := this.FormatException(err)
            this.report.Push("provisioning failed:`n" detail)
            this.lastFailureStage := "provisioning"
            this.lastFailureHint := detail
            return false
        }
        return FileExist(this.AssemblyFile()) && FileExist(this.BridgeFile())
    }

    ; --- assembly ----------------------------------------------------------

    static FetchAssembly(onProgress := "") {
        project := A_ScriptDir "\src\CapsLockSharp\CapsLockSharp.csproj"
        if FileExist(project) && this.BuildAssembly(project, onProgress)
            return true

        ; Without the .NET SDK or on build failure: fall back to the published AnyCPU assembly.
        this.DownloadAssembly(onProgress)
        return FileExist(this.AssemblyFile())
    }

    static BuildAssembly(project, onProgress := "") {
        out := A_ScriptDir "\lib"
        if !DirExist(out)
            DirCreate(out)

        dotnetExe := this.GetDotNetExecutable()
        logFile := A_Temp "\capslock_build_" A_TickCount ".log"

        if IsObject(onProgress)
            onProgress.Call(50, Lang("MSG_CSHARP_BUILDING"), "dotnet build " project " -c Release")

        command := 'cmd.exe /c ""' dotnetExe '" build "' project '" -c Release --nologo -o "' out '" > "' logFile '" 2>&1"'
        exitCode := 0
        try {
            RunWait(command, A_ScriptDir, "Hide", &exitCode)
        } catch as err {
            this.report.Push("dotnet build unavailable: " this.FormatException(err))
            this.lastFailureStage := "dotnet_build"
            this.lastFailureHint := Lang("MSG_CSHARP_ERR_BUILD_FAILED") . "`n`n" . this.FormatException(err)
            return false
        }

        buildOutput := ""
        if FileExist(logFile) {
            try buildOutput := FileRead(logFile, "UTF-8")
        }

        if exitCode != 0 {
            this.report.Push("dotnet build exited with code " exitCode)
            if FileExist(logFile)
                this.report.Push("complete dotnet build output saved to " logFile)
            errorLines := []
            for line in StrSplit(buildOutput, "`n", "`r") {
                trimmed := Trim(line)
                if trimmed == ""
                    continue
                if InStr(trimmed, ": error ") || InStr(trimmed, "error NETSDK") || InStr(trimmed, "error CS") || InStr(trimmed, "FAILED") {
                    errorLines.Push(trimmed)
                    this.report.Push("  " trimmed)
                }
            }
            if errorLines.Length == 0 && buildOutput != "" {
                lines := StrSplit(buildOutput, "`n", "`r")
                count := 0
                Loop lines.Length {
                    idx := lines.Length - A_Index + 1
                    t := Trim(lines[idx])
                    if t != "" {
                        this.report.Push("  " t)
                        count++
                        if count >= 3
                            break
                    }
                }
            }
            this.lastFailureStage := "dotnet_build"
            this.lastFailureHint := Lang("MSG_CSHARP_ERR_BUILD_FAILED")
            return false
        }

        try if FileExist(logFile)
            FileDelete(logFile)

        built := out "\CapsLockSharp.dll"
        if !FileExist(built) {
            this.report.Push("dotnet build produced no " built)
            this.lastFailureStage := "dotnet_build"
            this.lastFailureHint := "dotnet build did not produce CapsLockSharp.dll"
            return false
        }

        try FileDelete(built ":Zone.Identifier")

        if this.AssemblyFile() != built
            return this.CopyFile(built, this.AssemblyFile(), "CapsLockSharp.dll (built)")

        this.report.Push("built " built)
        return true
    }

    static DownloadAssembly(onProgress := "") {
        if IsObject(onProgress)
            onProgress.Call(60, Lang("MSG_CSHARP_DOWNLOADING_ASSEMBLY"), "下载 CapsLockSharp.dll...")

        urls := [
            "https://github.com/" this.AssemblyOwner "/" this.AssemblyRepo "/releases/latest/download/CapsLockSharp.dll",
            "https://ghfast.top/https://github.com/" this.AssemblyOwner "/" this.AssemblyRepo "/releases/latest/download/CapsLockSharp.dll",
            "https://raw.gitmirror.com/" this.AssemblyOwner "/" this.AssemblyRepo "/releases/latest/download/CapsLockSharp.dll"
        ]
        ok := this.DownloadTo(urls, this.AssemblyFile(), "CapsLockSharp.dll")
        if !ok {
            this.lastFailureStage := "assembly_download"
            this.lastFailureHint := Lang(
                "MSG_CSHARP_ERR_ASSEMBLY_FAILED",
                "无法构建或下载 CapsLockSharp.dll。请检查 .NET SDK、网络连接，并查看完整诊断日志。"
            )
        } else {
            this.report.Push("using the published CapsLockSharp.dll (local SDK build was unavailable)")
        }
        return ok
    }

    ; --- bridge ------------------------------------------------------------

    static FetchBridge(onProgress := "") {
        sourceDir := this.BridgeSourceDir()
        source := sourceDir "\ahk#.bridge.dll"
        library := sourceDir "\ahk#.ahk"
        if this.BridgeFile() != source && FileExist(source) && FileExist(library) {
            if this.VerifyBridgeDigest(library, source)
                return this.CopyFile(source, this.BridgeFile(), "ahk#.bridge.dll (checkout)")
            try FileDelete(source)
            this.report.Push("existing AHK# bridge was rejected; downloading a clean copy")
        }

        this.DownloadBridge(onProgress)
        return FileExist(this.BridgeFile())
    }

    ; One pinned commit, three files: the library the entry script #Includes
    ; (used by a source run), the bridge DLL the CLR loads, and the rebuild
    ; script that keeps the folder working like a git clone.
    static DownloadBridge(onProgress := "") {
        dir := this.BridgeSourceDir()
        if !DirExist(dir)
            DirCreate(dir)

        if IsObject(onProgress)
            onProgress.Call(70, Lang("MSG_CSHARP_DOWNLOADING_BRIDGE"), "下载 AHK# 桥接组件...")

        commit := this.BridgeCommit
        files := ["ahk#.ahk", "ahk#.bridge.dll", "build.ps1"]

        for fileName in files {
            encodedName := (fileName == "ahk#.ahk") ? "ahk%23.ahk" : ((fileName == "ahk#.bridge.dll") ? "ahk%23.bridge.dll" : fileName)
            targetPath := dir "\" fileName

            candidateUrls := [
                "https://raw.githubusercontent.com/" this.BridgeOwner "/" this.BridgeRepo "/" commit "/lib/" encodedName,
                "https://raw.gitmirror.com/" this.BridgeOwner "/" this.BridgeRepo "/" commit "/lib/" encodedName,
                "https://ghfast.top/https://raw.githubusercontent.com/" this.BridgeOwner "/" this.BridgeRepo "/" commit "/lib/" encodedName,
                "https://cdn.jsdelivr.net/gh/" this.BridgeOwner "/" this.BridgeRepo "@" commit "/lib/" encodedName
            ]

            if !this.DownloadTo(candidateUrls, targetPath, fileName) {
                this.lastFailureStage := "bridge_download"
                this.lastFailureHint := Lang("MSG_CSHARP_ERR_BRIDGE_FAILED")
                return false
            }
        }

        if !FileExist(dir "\ahk#.bridge.dll") {
            this.lastFailureStage := "bridge_download"
            this.lastFailureHint := Lang("MSG_CSHARP_ERR_BRIDGE_FAILED")
            return false
        }

        if !this.VerifyBridgeDigest(dir "\ahk#.ahk", dir "\ahk#.bridge.dll") {
            try FileDelete(dir "\ahk#.bridge.dll")
            this.lastFailureStage := "bridge_verify"
            this.lastFailureHint := "ahk#.bridge.dll SHA-256 hash mismatch with ahk#.ahk"
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

    static DownloadTo(urls, path, label) {
        if !IsObject(urls)
            urls := [urls]

        SplitPath(path, , &dir)
        if !DirExist(dir)
            DirCreate(dir)

        attemptErrors := []
        for url in urls {
            try {
                if FileExist(path)
                    FileDelete(path)

                Download(url, path)

                if FileExist(path) && FileGetSize(path) > 0 {
                    try FileDelete(path ":Zone.Identifier")
                    for failure in attemptErrors
                        this.report.Push("download fallback: " failure)
                    this.report.Push("downloaded " label " from " url " (" FileGetSize(path) " bytes)")
                    return true
                }
                attemptErrors.Push(url " -> server returned an empty file")
            } catch as err {
                attemptErrors.Push(url " -> " err.Message)
            }
        }

        try {
            if FileExist(path)
                FileDelete(path)
        }
        this.report.Push("download failed for " label)
        for failure in attemptErrors
            this.report.Push("  " failure)
        return false
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
            try FileDelete(target ":Zone.Identifier")
            this.report.Push("wrote " label ": " target)
            return true
        } catch as err {
            this.report.Push("could not copy " source ": " err.Message)
            return false
        }
    }

    ; Writes CSharpPayload.ahk in repo root so future builds will embed the payload.
    static WritePayloadIncludeIfSourceRun() {
        if A_IsCompiled || !FileExist(A_ScriptDir "\CapsLock-.ahk")
            return

        assembly := this.AssemblyFile()
        bridge := this.BridgeFile()
        if !FileExist(assembly) || !FileExist(bridge)
            return

        payloadInclude := A_ScriptDir "\CSharpPayload.ahk"
        lines := "; GENERATED FILE - do not edit and do not commit.`n"
            . ";`n"
            . "; Written by Core\CSharpRuntime.ahk. These are the only lines that make`n"
            . "; Ahk2Exe embed the C# backend into CapsLock-.exe; CapsLock-.ahk picks the file up`n"
            . "; through `#Include *i CSharpPayload.ahk`. Delete it for a pure-AHK executable.`n"
            . "; Core\CSharpPayload.ahk extracts both resources on first use and verifies them.`n"
            . ";@Ahk2Exe-AddResource lib\CapsLockSharp.dll, CSHARP_DLL`n"
            . ";@Ahk2Exe-AddResource lib\ahk#\lib\ahk#.bridge.dll, AHK_BRIDGE_DLL`n"
        try {
            if FileExist(payloadInclude)
                FileDelete(payloadInclude)
            FileAppend(lines, payloadInclude, "UTF-8")
            this.report.Push("wrote " payloadInclude)
        }
    }

    ; =======================================================================
    ; One-click setup
    ; =======================================================================

    ; The whole setup in one call, from the Settings Center button or CLI.
    ; Returns a Map with ok / message / hint / details / restartNeeded / active / stage.
    static Install(interactive := false, onProgress := "") {
        result := Map(
            "ok", false, "message", "", "hint", "", "details", [],
            "restartNeeded", false, "active", false, "stage", ""
        )
        this.lastFailureStage := ""
        this.lastFailureHint := ""
        this.report := []

        try {
            hasBridgeCode := Services.HaveBridge()

            if !hasBridgeCode && A_IsCompiled {
                result.message := Lang("MSG_CSHARP_NO_BRIDGE")
                result.hint := "当前运行的 EXE 未在编译时打包 AHK# 桥接代码。请使用已打包 C# 核心的发行版 EXE。"
                result.stage := "bridge_code"
                result.details.Push("this build has no AHK# bridge compiled in")
                return this.CompleteInstall(result)
            }

            ; Step 1: Detect environment (.NET 8 SDK & .NET Framework)
            if IsObject(onProgress)
                onProgress.Call(15, Lang("MSG_CSHARP_STEP_ENV"), "检测系统环境...")

            dotNetInfo := this.DetectDotNet8()
            if dotNetInfo.hasSdk8 {
                this.report.Push("detected .NET 8 SDK: " dotNetInfo.sdk8Version " (" dotNetInfo.dotnetExe ")")
            } else if dotNetInfo.installed {
                installedVersion := dotNetInfo.allSdks.Length > 0
                    ? dotNetInfo.allSdks[1]
                    : dotNetInfo.version
                this.report.Push("detected dotnet, but .NET 8 SDK is missing (installed: " installedVersion "; host: " dotNetInfo.dotnetExe ")")
            } else {
                this.report.Push(".NET 8 SDK is not installed or no dotnet host could be run")
            }

            if dotNetInfo.hasNetFramework48 {
                this.report.Push("detected .NET Framework 4.8/4.7.2+")
            } else {
                this.report.Push("warning: .NET Framework 4.8 release key not confirmed")
            }

            ; Step 2: Handle missing .NET 8 SDK
            project := A_ScriptDir "\src\CapsLockSharp\CapsLockSharp.csproj"
            if !dotNetInfo.hasSdk8 && FileExist(project) && !FileExist(this.AssemblyFile()) {
                hasWinget := this.HasWinget()
                shouldInstallWinget := false

                if hasWinget {
                    if interactive {
                        promptText := Lang("MSG_CSHARP_PROMPT_WINGET_DOTNET")
                        shouldInstallWinget := (MsgBox(promptText, Lang("MSG_CSHARP_SETUP_TITLE"), "YesNo Icon? T30") == "Yes")
                    } else {
                        shouldInstallWinget := true
                    }
                }

                if shouldInstallWinget {
                    wingetOk := this.InstallDotNet8ViaWinget(onProgress)
                    if wingetOk {
                        dotNetInfo := this.DetectDotNet8()
                    } else {
                        this.report.Push("winget installation did not complete; will try the precompiled assembly route")
                    }
                } else if !hasWinget {
                    this.report.Push("winget is not available on this system")
                } else {
                    this.report.Push(".NET 8 SDK installation was declined; will try the precompiled assembly route")
                }
            }

            ; Step 3: Ensure files exist
            ensured := this.EnsureFiles(onProgress)
            result.details := this.ReportLines()

            if !ensured {
                result.message := Lang("MSG_CSHARP_FAILED")
                result.stage := this.lastFailureStage
                result.hint := this.lastFailureHint
                return this.CompleteInstall(result)
            }

            ; Step 4: Write payload include for future builds
            this.WritePayloadIncludeIfSourceRun()

            ; Step 5: A source run can only use a bridge include loaded at
            ; process startup, so persist the configuration and request reload.
            if !hasBridgeCode {
                this.Enable()
                result.ok := true
                result.restartNeeded := true
                result.message := Lang("MSG_CSHARP_RESTART")
                return this.CompleteInstall(result)
            }

            if Services.tripped {
                this.Enable()
                result.ok := true
                result.restartNeeded := true
                result.message := Lang("MSG_CSHARP_RESTART")
                result.details.Push("circuit breaker tripped: " Services.reason)
                if Services.lastError != ""
                    result.details.Push("last managed error: " Services.lastError)
                return this.CompleteInstall(result)
            }

            ; Step 6: Enable and verify one real managed call.
            if IsObject(onProgress)
                onProgress.Call(90, Lang("MSG_CSHARP_WORKING"), "正在验证 C# 后端服务...")

            this.Enable()
            if !this.Verify() {
                result.details := this.ReportLines()
                result.details.Push("backend: " Services.reason)
                result.message := Lang("MSG_CSHARP_FAILED")
                result.stage := this.lastFailureStage
                result.hint := this.lastFailureHint

                ; A failed verification must not leave a broken C# choice saved;
                ; the AHK backend remains the safe fallback until the user retries.
                try this.Disable()
                catch as disableErr
                    result.details.Push("could not restore the AHK backend: " this.FormatException(disableErr))
                return this.CompleteInstall(result)
            }

            if IsObject(onProgress)
                onProgress.Call(100, Lang("MSG_CSHARP_DONE"), "C# 后端已配置并启用！")

            result.ok := true
            result.active := true
            result.message := Lang("MSG_CSHARP_DONE")
            return this.CompleteInstall(result)
        } catch as err {
            result.message := Lang("MSG_CSHARP_FAILED")
            result.stage := result.stage != "" ? result.stage : "unexpected_error"
            result.hint := this.FormatException(err)
            result.details := this.ReportLines()
            result.details.Push("unexpected setup exception:`n" this.FormatException(err))
            return this.CompleteInstall(result)
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
        } catch as err {
            this.report.Push("managed call threw: " err.Message)
        }

        if Services.ready && !Services.tripped && Services.calls > calls {
            this.report.Push("managed call succeeded")
            return true
        }

        this.report.Push("managed call failed: " Services.reason)
        if Services.lastError != ""
            this.report.Push("managed exception details:`n" Services.lastError)
        this.lastFailureStage := "verify"

        hint := Lang("MSG_CSHARP_ERR_VERIFY_FAILED")
        if InStr(Services.reason, "CorBindToRuntimeEx") {
            hint .= "`n`n" . "诊断提示：CLR 启动失败。AHK# 桥接依赖 .NET Framework 4.8 或 4.7.2 运行时，请确认 Windows 已启用 .NET Framework 4.8 功能。"
        } else if InStr(Services.reason, "hash") || InStr(Services.reason, "mismatch") {
            hint .= "`n`n" . "诊断提示：桥接 DLL 哈希校验失败，文件可能已损坏，建议重新配置以重新下载。"
        } else if InStr(Services.reason, "tripped") || Services.tripped {
            hint .= "`n`n" . "诊断提示：C# 后端熔断器已被触发，需要完全退出并重新启动 CapsLock- 才能恢复。"
        }
        this.lastFailureHint := hint
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
        if CSharpPayload.HasPayload()
            return Lang("MSG_CSHARP_PACKAGED")
        return Lang("MSG_CSHARP_MISSING")
    }

    static ReportLines() {
        lines := []
        for entry in this.report
            lines.Push(entry)
        return lines
    }

    ; Preserve the actionable fields of AHK's Error object. The previous setup
    ; dialog often reduced an exception to a blank/generic message; file, line,
    ; operation and stack are now retained in both the dialog and diagnostic log.
    static FormatException(err) {
        lines := []
        message := ""
        what := ""
        extra := ""
        sourceFile := ""
        sourceLine := ""
        stack := ""

        try message := err.Message
        try what := err.What
        try extra := err.Extra
        try sourceFile := err.File
        try sourceLine := err.Line
        try stack := err.Stack

        if message != ""
            lines.Push("Message: " message)
        if what != ""
            lines.Push("Operation: " what)
        if extra != ""
            lines.Push("Extra: " extra)
        if sourceFile != "" || sourceLine != ""
            lines.Push("Location: " sourceFile (sourceLine != "" ? " (line " sourceLine ")" : ""))
        if stack != ""
            lines.Push("Stack:`n" stack)

        if lines.Length == 0
            return "Unexpected error (no additional AHK error details were available)."

        text := ""
        for line in lines
            text .= (text == "" ? "" : "`n") line
        return text
    }

    static DiagnosticLogPath() {
        localApp := ""
        try localApp := EnvGet("LOCALAPPDATA")
        base := localApp != "" ? localApp : A_Temp
        return base "\CapsLock-\Logs\csharp-setup.log"
    }

    ; Merge every stage's report into one result and persist it even when the
    ; Settings GUI cannot display the complete error. The fixed per-user log is
    ; intentionally small (one attempt) and never contains clipboard content.
    static CompleteInstall(result) {
        details := result["details"]
        if !IsObject(details) {
            details := []
            result["details"] := details
        }

        seen := Map()
        for line in details
            seen[StrLower(String(line))] := true
        for line in this.report {
            key := StrLower(String(line))
            if !seen.Has(key) {
                details.Push(String(line))
                seen[key] := true
            }
        }

        if !result["ok"] {
            if result["stage"] == "" {
                result["stage"] := this.lastFailureStage != ""
                    ? this.lastFailureStage
                    : "setup"
            }
            if result["hint"] == "" && this.lastFailureHint != ""
                result["hint"] := this.lastFailureHint
        }

        logPath := this.DiagnosticLogPath()
        logFile := ""
        try {
            SplitPath(logPath, , &logDir)
            if !DirExist(logDir)
                DirCreate(logDir)

            logFile := FileOpen(logPath, "w", "UTF-8")
            if !IsObject(logFile)
                throw Error("Could not open the C# setup diagnostic log for writing")

            logFile.WriteLine("CapsLock- C# backend setup diagnostics")
            logFile.WriteLine("time=" FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"))
            logFile.WriteLine("ok=" (result["ok"] ? 1 : 0))
            logFile.WriteLine("stage=" result["stage"])
            logFile.WriteLine("compiled=" (A_IsCompiled ? 1 : 0) " ahk=" A_AhkVersion " pointer_size=" A_PtrSize)
            logFile.WriteLine("script_dir=" A_ScriptDir)
            logFile.WriteLine("assembly=" this.AssemblyFile())
            logFile.WriteLine("bridge=" this.BridgeFile())
            logFile.WriteLine("message=" result["message"])
            if result["hint"] != ""
                logFile.WriteLine("hint=" result["hint"])
            for line in details
                logFile.WriteLine("  " String(line))
            logFile.Close()
            logFile := ""

            this.lastReportPath := logPath
            if !result["ok"] {
                details.Push("Full diagnostic log: " logPath)
            }
        } catch as err {
            if IsObject(logFile) {
                try logFile.Close()
            }
            details.Push("Could not write the diagnostic log: " this.FormatException(err))
            this.lastReportPath := ""
        }

        return result
    }

    ; Used by the Settings UI as a last-resort guard around progress-window and
    ; result-dialog errors that occur outside Install() itself.
    static UnexpectedInstallFailure(err) {
        this.lastFailureStage := "setup_ui"
        this.lastFailureHint := this.FormatException(err)
        this.report.Push("unexpected setup UI exception:`n" this.FormatException(err))
        result := Map(
            "ok", false,
            "message", Lang("MSG_CSHARP_FAILED"),
            "hint", this.lastFailureHint,
            "details", this.ReportLines(),
            "restartNeeded", false,
            "active", false,
            "stage", this.lastFailureStage
        )
        return this.CompleteInstall(result)
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
        result := this.Install(false)
        this.Say("ok=" (result["ok"] ? 1 : 0))
        this.Say("restart_needed=" (result["restartNeeded"] ? 1 : 0))
        this.Say("stage=" result["stage"])
        this.Say("message=" result["message"])
        if result["hint"] != ""
            this.Say("hint=" result["hint"])
        for line in result["details"]
            this.Say("  " line)
        this.exitCode := result["ok"] ? 0 : 1

        if this.exitCode != 0 {
            this.Say("FAIL install: " result["message"])
            for line in result["details"]
                this.Say("FAIL install: " line)
        }
        return true
    }

    ; Prints what the boundary looks like in this process and exits. The exit
    ; code is 1 only when a packaged payload failed to work: a pure-AHK build
    ; has nothing to verify and is a valid configuration.
    static Probe() {
        this.report := []
        this.lastFailureStage := ""
        this.lastFailureHint := ""
        packaged := CSharpPayload.HasPayload()
        this.Say("compiled=" (A_IsCompiled ? 1 : 0))
        this.Say("bridge_code=" (Services.HaveBridge() ? 1 : 0))
        this.Say("packaged_assembly_bytes=" CSharpPayload.ResourceSize(CSharpPayload.AssemblyResource))
        this.Say("packaged_bridge_bytes=" CSharpPayload.ResourceSize(CSharpPayload.BridgeResource))

        dotNetInfo := this.DetectDotNet8()
        this.Say("dotnet_installed=" (dotNetInfo.installed ? 1 : 0))
        this.Say("dotnet_sdk8=" (dotNetInfo.hasSdk8 ? 1 : 0))
        this.Say("dotnet_sdk8_version=" dotNetInfo.sdk8Version)
        this.Say("winget_available=" (this.HasWinget() ? 1 : 0))

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
            if Services.lastError != ""
                this.Say("last_error=" Services.lastError)
        } else {
            this.Say("managed_call_ok=skipped (no AHK# in this build)")
        }

        this.exitCode := (packaged && !(ensured && verified)) ? 1 : 0

        if this.exitCode != 0 {
            this.Say("FAIL packaged payload unusable: files_ok=" (ensured ? 1 : 0)
                . " managed_call_ok=" (verified ? 1 : 0)
                . " bridge_code=" (Services.HaveBridge() ? 1 : 0))
            this.Say("FAIL backend=" Services.backend
                . " ready=" (Services.ready ? 1 : 0)
                . " tripped=" (Services.tripped ? 1 : 0)
                . " reason=" Services.reason)
            for line in this.ReportLines()
                this.Say("FAIL provisioning: " line)
        }

        this.Say("probe_exit=" this.exitCode)
        return true
    }
}
