#requires -Version 5.1

param(
    [int]$Days = 1
)

# Check for PC crashes, blue screens, freezes, and restarts
# Usage: .\check-crashes.ps1 -Days 7
# Automatically elevates to Administrator

# Self-elevation with execution policy bypass
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Administrator privileges required. Elevating..." -ForegroundColor Yellow
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" -Days $Days"
    Start-Process PowerShell -Verb RunAs -ArgumentList $arguments
    exit
}

$StartTime = (Get-Date).AddDays(-$Days)
$ReportTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$Results = @()
$SeenRecordIds = @{}

Write-Host "`n=== Checking for System Crashes (Past $Days day(s)) ===" -ForegroundColor Cyan
Write-Host "Looking back to: $StartTime`n" -ForegroundColor Gray

function Get-CrashEvents {
    param(
        [hashtable]$Filter,
        [string]$Label,
        [int]$MaxEvents = 0
    )

    Write-Host "$Label" -ForegroundColor Yellow
    $events = @()
    try {
        $params = @{
            FilterHashtable = $Filter
            ErrorAction     = 'Stop'
        }
        if ($MaxEvents -gt 0) { $params['MaxEvents'] = $MaxEvents }
        $events = @(Get-WinEvent @params)
    } catch {
        # Get-WinEvent throws when no events match; this is expected
    }
    Write-Host "  Found: $($events.Count) events" -ForegroundColor $(if ($events.Count -gt 0) { 'Red' } else { 'Green' })
    return ,$events
}

function Add-UniqueResult {
    param($Event, $TypeName)
    if (-not $script:SeenRecordIds.ContainsKey($Event.RecordId)) {
        $script:SeenRecordIds[$Event.RecordId] = $true
        $script:Results += [PSCustomObject]@{
            Time    = $Event.TimeCreated
            Type    = $TypeName
            EventID = $Event.Id
            Source  = $Event.ProviderName
            Message = $Event.Message
        }
    }
}

# 1. Blue Screen of Death (BSOD) - BugCheck events
$BugChecks = Get-CrashEvents -Filter @{
    LogName = 'System'; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'
    Id = 1001; StartTime = $StartTime
} -Label "[1/14] Checking for Blue Screen errors (BugCheck)..."
foreach ($e in $BugChecks) { Add-UniqueResult $e "BLUE SCREEN (BugCheck)" }

# 2. Kernel-Power Critical Events (Unexpected shutdown/restart)
$KernelPower = Get-CrashEvents -Filter @{
    LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'
    Id = 41; StartTime = $StartTime
} -Label "[2/14] Checking for unexpected shutdowns (Kernel-Power 41)..."
foreach ($e in $KernelPower) { Add-UniqueResult $e "UNEXPECTED SHUTDOWN/RESTART" }

# 3. Kernel-Power Watchdog Timeout (System freeze)
$Watchdog = Get-CrashEvents -Filter @{
    LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'
    Id = 109; StartTime = $StartTime
} -Label "[3/14] Checking for system freezes (Watchdog timeout 109)..."
foreach ($e in $Watchdog) { Add-UniqueResult $e "SYSTEM FREEZE (Watchdog Timeout)" }

# 4. Dirty shutdown events
$DirtyShutdown = Get-CrashEvents -Filter @{
    LogName = 'System'; ProviderName = 'EventLog'
    Id = 6008; StartTime = $StartTime
} -Label "[4/14] Checking for dirty shutdown events (EventLog 6008)..."
foreach ($e in $DirtyShutdown) { Add-UniqueResult $e "DIRTY SHUTDOWN (Improper shutdown)" }

# 5. WHEA Hardware Errors
$WheaErrors = Get-CrashEvents -Filter @{
    LogName = 'System'; ProviderName = 'Microsoft-Windows-WHEA-Logger'
    StartTime = $StartTime
} -Label "[5/14] Checking for hardware errors (WHEA)..."
foreach ($e in $WheaErrors) { Add-UniqueResult $e "HARDWARE ERROR (WHEA)" }

# 6. Display driver crashes / TDR (black screen)
$DisplayCrashes = Get-CrashEvents -Filter @{
    LogName = 'System'; ProviderName = 'Display'
    Id = 4101; StartTime = $StartTime
} -Label "[6/14] Checking for display driver crashes / black screen (TDR 4101)..."
foreach ($e in $DisplayCrashes) { Add-UniqueResult $e "DISPLAY DRIVER CRASH (Black Screen/TDR)" }

# 7. Application crashes and hangs
$AppCrashes = Get-CrashEvents -Filter @{
    LogName = 'Application'; Id = 1000, 1002; StartTime = $StartTime
} -Label "[7/14] Checking for application crashes (Event ID 1000/1002)..."
foreach ($e in $AppCrashes) {
    $t = if ($e.Id -eq 1000) { "APPLICATION CRASH" } else { "APPLICATION HANG" }
    Add-UniqueResult $e $t
}

# 8. Critical system errors (Level=1), excluding already captured
$CriticalErrors = Get-CrashEvents -Filter @{
    LogName = 'System'; Level = 1; StartTime = $StartTime
} -Label "[8/14] Checking for other critical system errors..." -MaxEvents 50
foreach ($e in $CriticalErrors) { Add-UniqueResult $e "CRITICAL ERROR" }

# 9. Disk/Storage Errors
$DiskErrors = Get-CrashEvents -Filter @{
    LogName = 'System'; ProviderName = 'disk','atapi','ataport'
    Id = 7,11,15,51,55; StartTime = $StartTime
} -Label "[9/14] Checking for disk/storage errors..."
foreach ($e in $DiskErrors) { Add-UniqueResult $e "DISK ERROR" }

# 10. Memory/DIMM Errors
$MemoryErrors = Get-CrashEvents -Filter @{
    LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Memory'
    Id = 19,20; StartTime = $StartTime
} -Label "[10/14] Checking for memory errors..."
foreach ($e in $MemoryErrors) { Add-UniqueResult $e "MEMORY ERROR" }

# 11. Service Control Manager Failures
$ServiceFailures = Get-CrashEvents -Filter @{
    LogName = 'System'; ProviderName = 'Service Control Manager'
    Id = 7031,7032,7034; StartTime = $StartTime
} -Label "[11/14] Checking for critical service failures..."
foreach ($e in $ServiceFailures) { Add-UniqueResult $e "SERVICE FAILURE" }

# 12. System File Corruption (CBS)
$CbsErrors = Get-CrashEvents -Filter @{
    LogName = 'Application'; ProviderName = 'CBS','Microsoft-Windows-CAPI2'
    Level = 1,2; StartTime = $StartTime
} -Label "[12/14] Checking for system file corruption..."
foreach ($e in $CbsErrors) { Add-UniqueResult $e "FILE CORRUPTION" }

# 13. Driver Load Failures
$DriverFailures = Get-CrashEvents -Filter @{
    LogName = 'System'; Id = 219,1060; StartTime = $StartTime
} -Label "[13/14] Checking for driver failures..."
foreach ($e in $DriverFailures) { Add-UniqueResult $e "DRIVER FAILURE" }

# 14. NTFS File System Errors
$NtfsErrors = Get-CrashEvents -Filter @{
    LogName = 'System'; ProviderName = 'Ntfs'
    Id = 55,137; StartTime = $StartTime
} -Label "[14/14] Checking for file system errors..."
foreach ($e in $NtfsErrors) { Add-UniqueResult $e "FILE SYSTEM ERROR" }

# 15. Check for minidump files
Write-Host "`nChecking for recent minidump files..." -ForegroundColor Yellow
$MiniDumpPath = "$env:SystemRoot\Minidump"
$FullDumpPath = "$env:SystemRoot\MEMORY.DMP"
$DumpFilesFound = @()

if (Test-Path $MiniDumpPath) {
    $DumpFilesFound += @(Get-ChildItem $MiniDumpPath -Filter '*.dmp' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $StartTime })
}
if (Test-Path $FullDumpPath) {
    $FullDump = Get-Item $FullDumpPath -ErrorAction SilentlyContinue
    if ($FullDump -and $FullDump.LastWriteTime -ge $StartTime) {
        $DumpFilesFound += $FullDump
    }
}

if ($DumpFilesFound.Count -gt 0) {
    Write-Host "  Found $($DumpFilesFound.Count) dump file(s)" -ForegroundColor Red
} else {
    Write-Host "  No recent dump files found" -ForegroundColor Green
}

# Collect system info for the AI section
$OS = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue)
$CPU = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1)
$GPU = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
$RAM = if ($OS) { [math]::Round($OS.TotalVisibleMemorySize / 1MB, 1) } else { "Unknown" }
$SysInfo = @{
    OS        = if ($OS) { "$($OS.Caption) Build $($OS.BuildNumber)" } else { "Unknown" }
    CPU       = if ($CPU) { $CPU.Name } else { "Unknown" }
    GPU       = ($GPU | ForEach-Object { $_.Name }) -join '; '
    RAM_GB    = $RAM
    Uptime    = if ($OS) { ((Get-Date) - $OS.LastBootUpTime).ToString("d' days 'h'h 'm'm'") } else { "Unknown" }
}

# Sort results
$Results = @($Results | Sort-Object Time -Descending)

# Build category counts
$Categories = @(
    @{ Label = "Blue Screens (BSOD)";   Filter = '*BLUE SCREEN*';   Severity = 'critical' },
    @{ Label = "Unexpected Shutdowns";   Filter = '*SHUTDOWN*';      Severity = 'critical' },
    @{ Label = "System Freezes";         Filter = '*FREEZE*';        Severity = 'critical' },
    @{ Label = "Hardware Errors";        Filter = '*HARDWARE*';      Severity = 'critical' },
    @{ Label = "Display Driver Crashes"; Filter = '*DISPLAY*';       Severity = 'warning'  },
    @{ Label = "Critical Errors";        Filter = 'CRITICAL ERROR';  Severity = 'critical' },
    @{ Label = "Application Crashes";    Filter = '*APPLICATION*';   Severity = 'warning'  },
    @{ Label = "Disk/Storage Errors";    Filter = '*DISK ERROR*';    Severity = 'critical' },
    @{ Label = "Memory Errors";          Filter = '*MEMORY ERROR*';  Severity = 'critical' },
    @{ Label = "Service Failures";       Filter = '*SERVICE FAILURE*'; Severity = 'warning' },
    @{ Label = "File Corruption";        Filter = '*FILE CORRUPTION*'; Severity = 'critical' },
    @{ Label = "Driver Failures";        Filter = '*DRIVER FAILURE*'; Severity = 'warning' },
    @{ Label = "File System Errors";     Filter = '*FILE SYSTEM ERROR*'; Severity = 'critical' }
)

# ── Build AI-friendly plain text block ──
$AiLines = @()
$AiLines += "WINDOWS CRASH REPORT"
$AiLines += "Report generated: $ReportTime"
$AiLines += "Period: past $Days day(s) (since $($StartTime.ToString('yyyy-MM-dd HH:mm:ss')))"
$AiLines += ""
$AiLines += "SYSTEM INFO"
$AiLines += "  OS:     $($SysInfo.OS)"
$AiLines += "  CPU:    $($SysInfo.CPU)"
$AiLines += "  GPU:    $($SysInfo.GPU)"
$AiLines += "  RAM:    $($SysInfo.RAM_GB) GB"
$AiLines += "  Uptime: $($SysInfo.Uptime)"
$AiLines += ""
$AiLines += "SUMMARY"
foreach ($cat in $Categories) {
    $count = @($Results | Where-Object { $_.Type -like $cat.Filter }).Count
    $AiLines += "  $($cat.Label): $count"
}
$AiLines += "  Minidump files: $($DumpFilesFound.Count)"
$AiLines += "  Total events: $($Results.Count)"
$AiLines += ""

if ($DumpFilesFound.Count -gt 0) {
    $AiLines += "MINIDUMP FILES"
    foreach ($dump in $DumpFilesFound) {
        $sizeMB = [math]::Round($dump.Length / 1MB, 2)
        $AiLines += "  $($dump.Name) - $($dump.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) ($sizeMB MB)"
    }
    $AiLines += ""
}

if ($Results.Count -gt 0) {
    $AiLines += "EVENTS (newest first)"
    $AiLines += ("-" * 70)
    foreach ($r in $Results) {
        $AiLines += "[$($r.Time.ToString('yyyy-MM-dd HH:mm:ss'))] $($r.Type)"
        $AiLines += "  Event ID: $($r.EventID) | Source: $($r.Source)"
        # Truncate very long messages for the AI block
        $msg = ($r.Message -replace '\r?\n', ' ').Trim()
        if ($msg.Length -gt 500) { $msg = $msg.Substring(0, 500) + "..." }
        $AiLines += "  Message: $msg"
        $AiLines += ""
    }
}

$AiLines += "Please analyze these crash events. Identify the most likely root cause(s), whether this appears to be a hardware or software issue, and suggest specific troubleshooting steps I should take."

$AiText = $AiLines -join "`n"

# ── HTML escape helper ──
function HtmlEncode($s) { return [System.Net.WebUtility]::HtmlEncode($s) }

# ── Build HTML ──
$SeverityColor = if ($Results.Count -eq 0) { '#22c55e' } elseif (@($Results | Where-Object { $_.Type -notlike '*APPLICATION*' }).Count -gt 0) { '#ef4444' } else { '#f59e0b' }
$TotalNonApp = @($Results | Where-Object { $_.Type -notlike '*APPLICATION*' }).Count

$HtmlRows = ""
foreach ($r in $Results) {
    $rowClass = if ($r.Type -like '*BLUE SCREEN*' -or $r.Type -like '*SHUTDOWN*' -or $r.Type -like '*FREEZE*' -or $r.Type -like '*HARDWARE*' -or $r.Type -eq 'CRITICAL ERROR') { 'critical' } elseif ($r.Type -like '*DISPLAY*') { 'warning' } else { 'info' }
    $escapedMsg = HtmlEncode $r.Message
    $HtmlRows += @"
    <tr class="$rowClass">
      <td>$($r.Time.ToString('yyyy-MM-dd HH:mm:ss'))</td>
      <td><span class="badge badge-$rowClass">$(HtmlEncode $r.Type)</span></td>
      <td>$($r.EventID)</td>
      <td>$(HtmlEncode $r.Source)</td>
    </tr>
    <tr class="detail-row $rowClass">
      <td colspan="4" class="message-cell">$escapedMsg</td>
    </tr>
"@
}

$DumpRows = ""
foreach ($dump in $DumpFilesFound) {
    $sizeMB = [math]::Round($dump.Length / 1MB, 2)
    $DumpRows += "<tr><td>$(HtmlEncode $dump.Name)</td><td>$($dump.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))</td><td>$sizeMB MB</td></tr>"
}

$SummaryCards = ""
foreach ($cat in $Categories) {
    $count = @($Results | Where-Object { $_.Type -like $cat.Filter }).Count
    $cardClass = if ($count -eq 0) { 'card-ok' } elseif ($cat.Severity -eq 'critical') { 'card-critical' } else { 'card-warning' }
    $SummaryCards += "<div class='summary-card $cardClass'><div class='card-count'>$count</div><div class='card-label'>$(HtmlEncode $cat.Label)</div></div>"
}

$Html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Crash Report - $ReportTime</title>
<style>
  :root { --bg: #0f172a; --surface: #1e293b; --surface2: #334155; --text: #e2e8f0; --text-dim: #94a3b8; --border: #475569;
           --red: #ef4444; --red-bg: #451a1a; --amber: #f59e0b; --amber-bg: #452a1a; --green: #22c55e; --green-bg: #1a3a2a; --blue: #3b82f6; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: var(--bg); color: var(--text); font-family: 'Segoe UI', system-ui, -apple-system, sans-serif; line-height: 1.5; padding: 2rem; }
  .container { max-width: 1200px; margin: 0 auto; }
  h1 { font-size: 1.75rem; font-weight: 700; margin-bottom: 0.25rem; }
  .subtitle { color: var(--text-dim); margin-bottom: 2rem; font-size: 0.9rem; }
  .header-bar { display: flex; align-items: center; gap: 1rem; margin-bottom: 0.5rem; }
  .status-dot { width: 14px; height: 14px; border-radius: 50%; display: inline-block; }
  .status-dot.red { background: var(--red); box-shadow: 0 0 8px var(--red); }
  .status-dot.green { background: var(--green); box-shadow: 0 0 8px var(--green); }
  .status-dot.amber { background: var(--amber); box-shadow: 0 0 8px var(--amber); }

  .sys-info { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; padding: 1rem 1.25rem; margin-bottom: 1.5rem; display: flex; flex-wrap: wrap; gap: 1.5rem; font-size: 0.85rem; }
  .sys-info div { color: var(--text-dim); }
  .sys-info span { color: var(--text); font-weight: 500; }

  .summary-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 0.75rem; margin-bottom: 2rem; }
  .summary-card { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; padding: 1rem; text-align: center; transition: transform 0.15s; }
  .summary-card:hover { transform: translateY(-2px); }
  .card-count { font-size: 2rem; font-weight: 700; }
  .card-label { font-size: 0.8rem; color: var(--text-dim); margin-top: 0.25rem; }
  .card-ok .card-count { color: var(--green); }
  .card-ok { border-color: #22c55e33; }
  .card-critical .card-count { color: var(--red); }
  .card-critical { border-color: #ef444466; background: var(--red-bg); }
  .card-warning .card-count { color: var(--amber); }
  .card-warning { border-color: #f59e0b55; background: var(--amber-bg); }

  section { margin-bottom: 2rem; }
  h2 { font-size: 1.2rem; font-weight: 600; margin-bottom: 0.75rem; padding-bottom: 0.5rem; border-bottom: 1px solid var(--border); }

  table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
  th { background: var(--surface2); color: var(--text-dim); text-align: left; padding: 0.6rem 0.75rem; font-weight: 600; position: sticky; top: 0; }
  td { padding: 0.5rem 0.75rem; border-bottom: 1px solid #1e293b; vertical-align: top; }
  tr:hover td { background: #ffffff06; }

  .badge { padding: 2px 8px; border-radius: 4px; font-size: 0.75rem; font-weight: 600; white-space: nowrap; }
  .badge-critical { background: var(--red-bg); color: var(--red); border: 1px solid #ef444444; }
  .badge-warning { background: var(--amber-bg); color: var(--amber); border: 1px solid #f59e0b44; }
  .badge-info { background: #1e3a5f; color: var(--blue); border: 1px solid #3b82f644; }

  .detail-row td { padding: 0 0.75rem 0.6rem 0.75rem; border-bottom: 1px solid var(--border); }
  .message-cell { font-family: 'Cascadia Code', 'Consolas', monospace; font-size: 0.78rem; color: var(--text-dim); white-space: pre-wrap; word-break: break-word; max-height: 150px; overflow-y: auto; display: block; }

  .critical td:first-child { border-left: 3px solid var(--red); }
  .warning td:first-child { border-left: 3px solid var(--amber); }
  .info td:first-child { border-left: 3px solid var(--blue); }

  .event-table-wrap { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; overflow: hidden; }

  .dump-table { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; overflow: hidden; }

  .ai-section { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; padding: 1.25rem; position: relative; }
  .ai-section h3 { font-size: 1rem; margin-bottom: 0.5rem; }
  .ai-section p { font-size: 0.85rem; color: var(--text-dim); margin-bottom: 0.75rem; }
  .ai-text { background: var(--bg); border: 1px solid var(--border); border-radius: 6px; padding: 1rem; font-family: 'Cascadia Code', 'Consolas', monospace; font-size: 0.78rem; color: var(--text-dim); white-space: pre-wrap; word-break: break-word; max-height: 400px; overflow-y: auto; cursor: text; user-select: all; }
  .copy-btn { position: absolute; top: 1.25rem; right: 1.25rem; background: var(--blue); color: #fff; border: none; padding: 0.4rem 1rem; border-radius: 6px; cursor: pointer; font-size: 0.85rem; font-weight: 500; transition: background 0.15s; }
  .copy-btn:hover { background: #2563eb; }
  .copy-btn.copied { background: var(--green); }

  .no-events { text-align: center; padding: 3rem; color: var(--green); font-size: 1.1rem; }
  footer { text-align: center; color: var(--text-dim); font-size: 0.75rem; padding-top: 2rem; border-top: 1px solid var(--border); margin-top: 2rem; }
</style>
</head>
<body>
<div class="container">
  <div class="header-bar">
    <span class="status-dot $(if ($Results.Count -eq 0) { 'green' } elseif ($TotalNonApp -gt 0) { 'red' } else { 'amber' })"></span>
    <h1>Windows Crash Report</h1>
  </div>
  <div class="subtitle">Generated $ReportTime &mdash; Looking back $Days day(s) to $($StartTime.ToString('yyyy-MM-dd HH:mm:ss')) &mdash; $($Results.Count) event(s) found</div>

  <div class="sys-info">
    <div>OS: <span>$(HtmlEncode $SysInfo.OS)</span></div>
    <div>CPU: <span>$(HtmlEncode $SysInfo.CPU)</span></div>
    <div>GPU: <span>$(HtmlEncode $SysInfo.GPU)</span></div>
    <div>RAM: <span>$($SysInfo.RAM_GB) GB</span></div>
    <div>Uptime: <span>$($SysInfo.Uptime)</span></div>
  </div>

  <section>
    <h2>Summary</h2>
    <div class="summary-grid">
      $SummaryCards
      <div class="summary-card $(if ($DumpFilesFound.Count -gt 0) { 'card-critical' } else { 'card-ok' })">
        <div class="card-count">$($DumpFilesFound.Count)</div>
        <div class="card-label">Minidump Files</div>
      </div>
    </div>
  </section>

$(if ($Results.Count -eq 0 -and $DumpFilesFound.Count -eq 0) {
  '<section><div class="no-events">No crashes, blue screens, freezes, or critical errors found in this period.</div></section>'
} else { @"
  $(if ($DumpFilesFound.Count -gt 0) { @"
  <section>
    <h2>Minidump Files</h2>
    <div class="dump-table">
      <table><thead><tr><th>File</th><th>Date</th><th>Size</th></tr></thead><tbody>$DumpRows</tbody></table>
    </div>
  </section>
"@ })

  $(if ($Results.Count -gt 0) { @"
  <section>
    <h2>Events ($($Results.Count))</h2>
    <div class="event-table-wrap">
      <table>
        <thead><tr><th style="width:160px">Time</th><th style="width:280px">Type</th><th style="width:80px">Event ID</th><th>Source</th></tr></thead>
        <tbody>$HtmlRows</tbody>
      </table>
    </div>
  </section>
"@ })
"@ })

  <section>
    <h2>AI Diagnostics Helper</h2>
    <div class="ai-section">
      <h3>Copy &amp; paste the text below into ChatGPT, Claude, or another AI assistant</h3>
      <p>This is a pre-formatted summary of all crash data, system info, and event messages optimized for AI analysis.</p>
      <button class="copy-btn" onclick="copyAiText(this)">Copy to Clipboard</button>
      <div class="ai-text" id="aiText">$(HtmlEncode $AiText)</div>
    </div>
  </section>

  <footer>check-crashes.ps1 &mdash; Report covers $($StartTime.ToString('MMM dd yyyy HH:mm')) to $($(Get-Date).ToString('MMM dd yyyy HH:mm'))</footer>
</div>

<script>
function copyAiText(btn) {
  const text = document.getElementById('aiText').innerText;
  navigator.clipboard.writeText(text).then(function() {
    btn.textContent = 'Copied!';
    btn.classList.add('copied');
    setTimeout(function() { btn.textContent = 'Copy to Clipboard'; btn.classList.remove('copied'); }, 2000);
  });
}
</script>
</body>
</html>
"@

# Write HTML to file and open in Edge
$HtmlPath = Join-Path $env:TEMP "crash-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
$Html | Out-File -FilePath $HtmlPath -Encoding utf8
Write-Host "`nReport saved to: $HtmlPath" -ForegroundColor Green
Write-Host "Opening in Edge..." -ForegroundColor Cyan
Start-Process "msedge.exe" $HtmlPath

Write-Host "`nDone.`n" -ForegroundColor Green
