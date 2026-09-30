#Requires -Version 5.1
<#
.SYNOPSIS
    Compares two CapsLock- build benchmark results and prints a verdict.

.DESCRIPTION
    Reads two JSON files produced by Measure-CapsLockBuild.ps1 and compares
    them metric by metric, so the AHKCompiler evaluation (issue #46) ends with
    a decision instead of two piles of numbers.

    Every metric gets its own noise band, because the interesting differences
    are small and the uninteresting ones are everywhere:

      * a percentage of the baseline value, and
      * an absolute floor, so tiny baselines do not produce "100% worse"
        verdicts out of sub-millisecond jitter.

    A metric only counts when the change is outside that band. Anything inside
    it is reported as "same", which is a result, not a failure to measure.

    The two runs must come from the same machine and the same power plan. If
    they do not, the script still prints the table but marks every verdict as
    "not comparable", because a different CPU or a different power plan moves
    these numbers far more than a compiler does.

    Nothing here decides whether to switch the release compiler. It answers
    "what changed, and is the change bigger than the noise".

.PARAMETER Baseline
    JSON result of the build you are comparing against, normally the current
    Ahk2Exe output.

.PARAMETER Candidate
    JSON result of the build under evaluation, normally an AHKCompiler output.

.PARAMETER OutDir
    Directory for compare-<baseline>-vs-<candidate>.md and .json.
    Defaults to the directory of the baseline file.

.PARAMETER FailOnRegression
    Exit with code 2 when any metric is significantly worse. Useful when the
    comparison is wired into a pipeline; off by default because an evaluation
    run is expected to produce some regressions.

.EXAMPLE
    .\Compare-CapsLockBuilds.ps1 -Baseline .\bench\ahk2exe.json `
        -Candidate .\bench\ahkcompiler-lean-x64.json

.EXAMPLE
    .\Compare-CapsLockBuilds.ps1 -Baseline .\bench\ahk2exe.json `
        -Candidate .\bench\ahkcompiler-lean-x64.json -FailOnRegression
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $Baseline,

    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string] $Candidate,

    [string] $OutDir,

    [switch] $FailOnRegression
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $OutDir) {
    $OutDir = Split-Path -Parent (Resolve-Path -LiteralPath $Baseline)
}

# --- Load --------------------------------------------------------------------

$base = Get-Content -LiteralPath $Baseline -Raw | ConvertFrom-Json
$cand = Get-Content -LiteralPath $Candidate -Raw | ConvertFrom-Json

Write-Host ''
Write-Host ('Comparing  {0}  (baseline)' -f $base.profile)
Write-Host ('      vs.  {0}  (candidate)' -f $cand.profile)
Write-Host ''

# --- Environment guard -------------------------------------------------------

$comparable = $true
$envNotes = New-Object System.Collections.ArrayList

$fields = @('machine', 'cpu_name', 'cpu_cores', 'power_plan', 'os_build', 'ahk_version')

$baseEnv = if ($base.PSObject.Properties['environment']) { $base.environment } else { $null }
$candEnv = if ($cand.PSObject.Properties['environment']) { $cand.environment } else { $null }

foreach ($field in $fields) {
    $a = if ($baseEnv) { $baseEnv.PSObject.Properties[$field] } else { $null }
    $b = if ($candEnv) { $candEnv.PSObject.Properties[$field] } else { $null }

    if (-not $a -and -not $b) { continue }

    $av = if ($a) { [string]$a.Value } else { '(missing)' }
    $bv = if ($b) { [string]$b.Value } else { '(missing)' }

    if ($av -ne $bv) {
        $comparable = $false
        [void]$envNotes.Add(('{0}: baseline "{1}" vs candidate "{2}"' -f $field, $av, $bv))
    }
}

if (-not $comparable) {
    Write-Warning 'The two runs do not share an environment. Every verdict below is reported as NOT COMPARABLE.'
    foreach ($note in $envNotes) {
        Write-Warning ('    ' + $note)
    }
    Write-Host ''
}

# --- Comparison helpers ------------------------------------------------------

function Get-PathValue {
    param($Object, [string] $Path)

    if ($null -eq $Object) { return $null }

    $current = $Object
    foreach ($part in $Path.Split('.')) {
        if ($null -eq $current) { return $null }

        if ($current -is [System.Collections.IDictionary]) {
            if (-not $current.Contains($part)) { return $null }
            $current = $current[$part]
            continue
        }

        $prop = $current.PSObject.Properties[$part]
        if ($null -eq $prop) { return $null }
        $current = $prop.Value
    }

    return $current
}

<#
    One metric comparison.

    lowerIsBetter : $true for size, time, memory, CPU, handles
    noiseAbs      : absolute floor, in the unit of the metric
    noiseRel      : fraction of the baseline value

    The band is max(noiseAbs, |baseline| * noiseRel).
#>
function Compare-Metric {
    param(
        [string] $Name,
        [string] $Path,
        [string] $Unit,
        [bool]   $LowerIsBetter,
        [double] $NoiseAbs,
        [double] $NoiseRel
    )

    $a = Get-PathValue -Object $base -Path $Path
    $b = Get-PathValue -Object $cand -Path $Path

    $row = [ordered]@{
        metric = $Name
        unit   = $Unit
        baseline = $null
        candidate = $null
        delta = $null
        change_pct = $null
        noise_band = $null
        verdict = 'not measured'
    }

    if ($null -eq $a -or $null -eq $b) {
        if ($null -ne $a) { $row.verdict = 'missing in candidate' }
        elseif ($null -ne $b) { $row.verdict = 'missing in baseline' }
        return [pscustomobject]$row
    }

    $av = [double]$a
    $bv = [double]$b
    $delta = $bv - $av
    $band = [math]::Max($NoiseAbs, [math]::Abs($av) * $NoiseRel)
    $pct = if ($av -ne 0) { ($delta / [math]::Abs($av)) * 100.0 } else { 0.0 }

    $row.baseline = [math]::Round($av, 3)
    $row.candidate = [math]::Round($bv, 3)
    $row.delta = [math]::Round($delta, 3)
    $row.change_pct = [math]::Round($pct, 1)
    $row.noise_band = [math]::Round($band, 3)

    if (-not $comparable) {
        $row.verdict = 'not comparable'
        return [pscustomobject]$row
    }

    if ([math]::Abs($delta) -le $band) {
        $row.verdict = 'same'
        return [pscustomobject]$row
    }

    $improved = if ($LowerIsBetter) { $delta -lt 0 } else { $delta -gt 0 }
    $row.verdict = if ($improved) { 'better' } else { 'worse' }

    return [pscustomobject]$row
}

# --- Metric table ------------------------------------------------------------
#
# noiseAbs values are deliberately generous. A 30 ms start-up difference on a
# 400 ms start-up is real but irrelevant; a 300 ms one is not.

$specs = @(
    @{ name = 'executable size';        path = 'aggregate.size_bytes';            unit = 'bytes'; lower = $true;  abs = 0;     rel = 0.0 }
    @{ name = 'start-up to idle';       path = 'aggregate.startup_to_idle_ms';    unit = 'ms';    lower = $true;  abs = 25.0;  rel = 0.05 }
    @{ name = 'idle working set';       path = 'aggregate.idle_working_set_kb';   unit = 'KB';    lower = $true;  abs = 512.0; rel = 0.03 }
    @{ name = 'idle private bytes';     path = 'aggregate.idle_private_kb';       unit = 'KB';    lower = $true;  abs = 512.0; rel = 0.03 }
    @{ name = 'idle CPU';               path = 'aggregate.idle_cpu_percent';      unit = '%';     lower = $true;  abs = 0.05;  rel = 0.10 }
    @{ name = 'idle handles';           path = 'aggregate.idle_handle_count';     unit = 'count'; lower = $true;  abs = 5.0;   rel = 0.05 }
    @{ name = 'idle GDI objects';       path = 'aggregate.idle_gdi_objects';      unit = 'count'; lower = $true;  abs = 3.0;   rel = 0.05 }
    @{ name = 'latency topmost p50';    path = 'latency.topmost_ms.median_p50';   unit = 'ms';    lower = $true;  abs = 1.5;   rel = 0.05 }
    @{ name = 'latency topmost p95';    path = 'latency.topmost_ms.median_p95';   unit = 'ms';    lower = $true;  abs = 3.0;   rel = 0.05 }
    @{ name = 'latency copy p50';       path = 'latency.copy_ms.median_p50';      unit = 'ms';    lower = $true;  abs = 1.5;   rel = 0.05 }
    @{ name = 'latency copy p95';       path = 'latency.copy_ms.median_p95';      unit = 'ms';    lower = $true;  abs = 3.0;   rel = 0.05 }
    @{ name = 'latency history p50';    path = 'latency.history_menu_ms.median_p50'; unit = 'ms'; lower = $true;  abs = 2.0;   rel = 0.05 }
    @{ name = 'latency history p95';    path = 'latency.history_menu_ms.median_p95'; unit = 'ms'; lower = $true;  abs = 4.0;   rel = 0.05 }
    @{ name = 'soak delta private';     path = 'soak.delta_private_kb';           unit = 'KB';    lower = $true;  abs = 1024.0; rel = 0.20 }
    @{ name = 'soak delta handles';     path = 'soak.delta_handles';              unit = 'count'; lower = $true;  abs = 25.0;  rel = 0.20 }
    @{ name = 'soak delta GDI';         path = 'soak.delta_gdi';                  unit = 'count'; lower = $true;  abs = 15.0;  rel = 0.20 }
    @{ name = 'soak delta USER';        path = 'soak.delta_user';                 unit = 'count'; lower = $true;  abs = 15.0;  rel = 0.20 }
)

# The file facts live under "file", not "aggregate".
$sizeSpec = $specs[0]

$rows = New-Object System.Collections.ArrayList

$sizeRow = Compare-Metric -Name $sizeSpec.name -Path 'file.size_bytes' -Unit $sizeSpec.unit `
    -LowerIsBetter $sizeSpec.lower -NoiseAbs $sizeSpec.abs -NoiseRel $sizeSpec.rel
[void]$rows.Add($sizeRow)

foreach ($spec in $specs) {
    if ($spec.name -eq 'executable size') { continue }

    [void]$rows.Add((Compare-Metric -Name $spec.name -Path $spec.path -Unit $spec.unit `
        -LowerIsBetter $spec.lower -NoiseAbs $spec.abs -NoiseRel $spec.rel))
}

# --- Verdicts that are not numbers -------------------------------------------

$issues = New-Object System.Collections.ArrayList

$baseAlive = Get-PathValue -Object $base -Path 'soak.alive'
$candAlive = Get-PathValue -Object $cand -Path 'soak.alive'

if ($null -ne $baseAlive -and $null -ne $candAlive) {
    if ($baseAlive -and -not $candAlive) {
        [void]$issues.Add('The candidate process did not survive the resident-feature soak.')
    } elseif (-not $baseAlive -and $candAlive) {
        [void]$issues.Add('The baseline process did not survive the soak; the candidate did.')
    }
}

function Test-ReachedIdle {
    param($Report)

    # reached_idle is recorded per repetition; one failed run invalidates the
    # start-up figure for the whole profile.
    $reps = if ($Report.PSObject.Properties['repetitions']) { $Report.repetitions } else { $null }
    if ($null -eq $reps) { return $true }

    foreach ($r in $reps) {
        $prop = $r.PSObject.Properties['reached_idle']
        if ($null -ne $prop -and -not $prop.Value) { return $false }
    }

    return $true
}

foreach ($entry in @(
    @{ n = 'baseline';  v = (Test-ReachedIdle -Report $base) },
    @{ n = 'candidate'; v = (Test-ReachedIdle -Report $cand) }
)) {
    if (-not $entry.v) {
        [void]$issues.Add(('The {0} process never reached an idle state in at least one repetition; its start-up figure is a timeout, not a measurement.' -f $entry.n))
    }
}

$baseStderr = Get-PathValue -Object $base -Path 'soak.stderr'
$candStderr = Get-PathValue -Object $cand -Path 'soak.stderr'

if ($candStderr -and ([string]$candStderr).Trim().Length -gt 0) {
    [void]$issues.Add('The candidate produced stderr output during the soak.')
}

$baseSkipped = Get-PathValue -Object $base -Path 'environment.skip_latency'
$candSkipped = Get-PathValue -Object $cand -Path 'environment.skip_latency'

if ($baseSkipped -or $candSkipped) {
    [void]$issues.Add('At least one run skipped the latency probes (non-interactive session), so no latency verdict is available.')
}

# --- Tally -------------------------------------------------------------------

$better = 0
$worse = 0
$same = 0
$unmeasured = 0

foreach ($row in $rows) {
    switch ($row.verdict) {
        'better' { $better++ }
        'worse' { $worse++ }
        'same' { $same++ }
        default { $unmeasured++ }
    }
}

$regressed = New-Object System.Collections.ArrayList
foreach ($row in $rows) {
    if ($row.verdict -eq 'worse') { [void]$regressed.Add($row.metric) }
}

# --- Console -----------------------------------------------------------------

Write-Host ('{0,-22} {1,12} {2,12} {3,11} {4,9}  {5}' -f 'metric', 'baseline', 'candidate', 'delta', 'change', 'verdict')
Write-Host ('{0,-22} {1,12} {2,12} {3,11} {4,9}  {5}' -f '------', '--------', '--------', '-----', '------', '-------')

foreach ($row in $rows) {
    $bv = if ($null -eq $row.baseline) { '-' } else { '{0:N3}' -f $row.baseline }
    $cv = if ($null -eq $row.candidate) { '-' } else { '{0:N3}' -f $row.candidate }
    $dv = if ($null -eq $row.delta) { '-' } else { '{0:N3}' -f $row.delta }
    $pv = if ($null -eq $row.change_pct) { '-' } else { '{0:N1}%' -f $row.change_pct }

    Write-Host ('{0,-22} {1,12} {2,12} {3,11} {4,9}  {5}' -f $row.metric, $bv, $cv, $dv, $pv, $row.verdict)
}

Write-Host ''
Write-Host ('summary: {0} better, {1} worse, {2} within the noise band, {3} not measured' -f $better, $worse, $same, $unmeasured)

if ($regressed.Count -gt 0) {
    Write-Host ('regressions: {0}' -f ($regressed -join ', '))
}

if ($issues.Count -gt 0) {
    Write-Host ''
    Write-Host 'issues:'
    foreach ($issue in $issues) {
        Write-Host ('  - ' + $issue)
    }
}

if (-not $comparable) {
    Write-Host ''
    Write-Host 'VERDICT: NOT COMPARABLE -- re-run both builds on the same machine and power plan.'
} elseif ($worse -gt 0 -and $better -gt 0) {
    Write-Host ''
    Write-Host 'VERDICT: MIXED -- weigh the regressions against the gains before switching.'
} elseif ($worse -gt 0) {
    Write-Host ''
    Write-Host 'VERDICT: REGRESSION -- the candidate is significantly worse on at least one metric.'
} elseif ($better -gt 0) {
    Write-Host ''
    Write-Host 'VERDICT: IMPROVEMENT -- no metric got significantly worse.'
} else {
    Write-Host ''
    Write-Host 'VERDICT: NO SIGNIFICANT DIFFERENCE -- every metric moved inside its noise band.'
}

# --- Output files ------------------------------------------------------------

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$slug = ('compare-{0}-vs-{1}' -f $base.profile, $cand.profile)

if (-not (Test-Path -LiteralPath $OutDir)) {
    [void](New-Item -ItemType Directory -Path $OutDir -Force)
}

$report = [ordered]@{
    generated      = (Get-Date).ToUniversalTime().ToString('o')
    baseline       = [ordered]@{ profile = $base.profile; file = (Resolve-Path -LiteralPath $Baseline).Path }
    candidate      = [ordered]@{ profile = $cand.profile; file = (Resolve-Path -LiteralPath $Candidate).Path }
    comparable     = $comparable
    environment_notes = $envNotes.ToArray()
    tally          = [ordered]@{ better = $better; worse = $worse; same = $same; not_measured = $unmeasured }
    metrics        = $rows.ToArray()
    issues         = $issues.ToArray()
}

$jsonPath = Join-Path $OutDir ($slug + '.json')
$report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$md = New-Object System.Collections.ArrayList

[void]$md.Add(('# {0} vs {1}' -f $base.profile, $cand.profile))
[void]$md.Add('')
[void]$md.Add(('Generated {0} (UTC).' -f $report.generated))
[void]$md.Add('')
[void]$md.Add('| | baseline | candidate |')
[void]$md.Add('| :-- | :-- | :-- |')
[void]$md.Add(('| profile | {0} | {1} |' -f $base.profile, $cand.profile))
[void]$md.Add(('| exe | {0} | {1} |' -f (Get-PathValue -Object $base -Path 'file.name'), (Get-PathValue -Object $cand -Path 'file.name')))
[void]$md.Add(('| sha256 | `{0}` | `{1}` |' -f (Get-PathValue -Object $base -Path 'file.sha256'), (Get-PathValue -Object $cand -Path 'file.sha256')))
[void]$md.Add(('| repetitions | {0} | {1} |' -f (Get-PathValue -Object $base -Path 'aggregate.repetitions'), (Get-PathValue -Object $cand -Path 'aggregate.repetitions')))
[void]$md.Add('')
[void]$md.Add('## Results')
[void]$md.Add('')
[void]$md.Add('| metric | baseline | candidate | delta | change | noise band | verdict |')
[void]$md.Add('| :-- | --: | --: | --: | --: | --: | :-- |')

foreach ($row in $rows) {
    $unit = if ($row.unit) { ' ' + $row.unit } else { '' }
    [void]$md.Add(('| {0} | {1}{2} | {3}{4} | {5} | {6}% | {7} | {8} |' -f `
        $row.metric, $row.baseline, $unit, $row.candidate, $unit, $row.delta, $row.change_pct, $row.noise_band, $row.verdict))
}

[void]$md.Add('')
[void]$md.Add(('Tally: **{0} better**, **{1} worse**, {2} within the noise band, {3} not measured.' -f $better, $worse, $same, $unmeasured))
[void]$md.Add('')

if ($issues.Count -gt 0) {
    [void]$md.Add('## Issues')
    [void]$md.Add('')
    foreach ($issue in $issues) {
        [void]$md.Add(('- ' + $issue))
    }
    [void]$md.Add('')
}

if (-not $comparable) {
    [void]$md.Add('## Environment')
    [void]$md.Add('')
    [void]$md.Add('The two runs do not share an environment, so no verdict above is trustworthy.')
    [void]$md.Add('')
    foreach ($note in $envNotes) {
        [void]$md.Add(('- ' + $note))
    }
    [void]$md.Add('')
}

$mdPath = Join-Path $OutDir ($slug + '.md')
Set-Content -LiteralPath $mdPath -Value ($md -join [Environment]::NewLine) -Encoding UTF8

Write-Host ''
Write-Host ('wrote {0}' -f $jsonPath)
Write-Host ('wrote {0}' -f $mdPath)
Write-Host ''

if ($FailOnRegression -and $worse -gt 0) {
    exit 2
}

exit 0
