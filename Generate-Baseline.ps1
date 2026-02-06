<#
.SYNOPSIS
    Generates a hardware and software inventory baseline report.

.DESCRIPTION
    This script compiles comprehensive system information including hardware components
    (CPU, motherboard, RAM, storage) and installed software. The output is formatted
    as an HTML report with a classification banner suitable for documentation or
    compliance purposes.
    
    The report includes:
    - System information (hostname, domain, OS details, boot time)
    - Processor details
    - Motherboard information
    - Memory/RAM specifications
    - Disk drive information
    - Installed software inventory (filtered to exclude updates and language packs)

.PARAMETER None
    Output path and classification are configured via script variables.

.EXAMPLE
    .\Generate-Baseline.ps1
    Generates baseline report and opens it in the default browser.

.NOTES
    Output is saved to C:\ADMIN\baseline.html by default.
    Classification banner defaults to "UNCLASSIFIED" with green color.
    Software exclusions filter out Windows Updates, language packs, and redistributables.

.AUTHOR
    Jake Kelley
    Last Updated: 11/24/2020
#>

##--------------------------------------------------------------------------
##    Variables
##--------------------------------------------------------------------------

# Where to export the baseline.html
$htmlPath = "C:\ADMIN\baseline.html"

# Get Machine Hostname and set as variable
$hostname = Get-Content env:computername

# Date in format(YYYY_MM_DD)
$Date = "(" + (Get-Date -Format MM-dd-yyyy) + ")"

# Classification of the report - default unclassified for collateral systems
$classification = "UNCLASSIFIED"

# Color mapping for classification
$classColorMap = @{
    "UNCLASSIFIED" = "#22c55e"
    "SECRET" = "#ef4444"
    "TOP SECRET" = "#f97316"
    "TOP SECRET//SCI" = "#fbbf24"
}
$color = $classColorMap[$classification]
if (-not $color) { $color = "#22c55e" }

##--------------------------------------------------------------------------
##    System Information Query
##--------------------------------------------------------------------------

$compInfo = Get-ComputerInfo
$OS = "$($compInfo.WindowsProductName) $($compInfo.WindowsVersion)"
$BootTime = $compInfo.OSLastBootUpTime
$DomainRole = switch ($compInfo.CsDomainRole) {
    0 { "Standalone Workstation" }
    1 { "Member Workstation" }
    2 { "Standalone Server" }
    3 { "Member Server" }
    4 { "Backup Domain Controller" }
    5 { "Primary Domain Controller" }
    default { $compInfo.CsDomainRole }
}

##--------------------------------------------------------------------------
##    Hardware Baseline Query
##--------------------------------------------------------------------------

# CPU
$cpuData = Get-CimInstance -ClassName Win32_Processor | Select-Object Name

# Motherboard
$motherboardData = Get-CimInstance -ClassName Win32_Baseboard | Select-Object Manufacturer, Product, @{Name="SerialNumber";Expression={
    if ([string]::IsNullOrWhiteSpace($_.SerialNumber) -or 
        $_.SerialNumber -match "^(To be filled|Default|Not specified|BaseBoard|System|Asset|00000000)" -or
        $_.SerialNumber -eq "To be filled by O.E.M." -or
        $_.SerialNumber -eq "Default string") {
        "Not available"
    } else {
        $_.SerialNumber
    }
}}

# RAM
$ramData = Get-CimInstance -ClassName Win32_PhysicalMemory | Select-Object DeviceLocator, Manufacturer, @{Name="CapacityGB";Expression={[math]::Round($_.Capacity / 1GB, 2)}}, @{Name="SerialNumber";Expression={
    if ([string]::IsNullOrWhiteSpace($_.SerialNumber) -or 
        $_.SerialNumber -match "^(00000000|FFFFFFFF|Not Specified|Unknown|Serial|Asset)" -or
        $_.SerialNumber -eq "000000000000" -or
        $_.SerialNumber -eq "Not Specified" -or
        $_.SerialNumber -eq "Unknown") {
        "Not available"
    } else {
        $_.SerialNumber
    }
}}

# Storage
$storageData = Get-CimInstance -ClassName Win32_DiskDrive | Select-Object Manufacturer, Model, @{Name="SizeGB";Expression={[math]::Round($_.Size / 1GB, 2)}}, @{Name="SerialNumber";Expression={
    if ([string]::IsNullOrWhiteSpace($_.SerialNumber) -or 
        $_.SerialNumber -match "^(00000000|0000_0000_0000|Unknown|None|Not|Serial)" -or
        $_.SerialNumber -eq "000000000000" -or
        $_.SerialNumber -eq "Unknown" -or
        $_.SerialNumber -eq "None") {
        "Not available"
    } else {
        $_.SerialNumber
    }
}}

##--------------------------------------------------------------------------
##    Software Baseline Query
##--------------------------------------------------------------------------
# Software Exclusions to leave out of the report
$sw1 = "*Update for Microsoft*"
$sw2 = "*Update for Skype*"
$sw3 = "*MUI*"
$sw4 = "*Office 32-bit Components*"
$sw5 = "*Visual C++*"
$sw6 = "*English*"
$sw7 = "*Français*"
$sw8 = "*español*"
$sw9 = "*Office Proofing*"

# Software information query variables - two location queries to gather all the software installed
$softwareData = @()
$softwareData += Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | 
    Where-Object { $_.DisplayName -and 
        $_.DisplayName -notlike $sw1 -and
        $_.DisplayName -notlike $sw2 -and
        $_.DisplayName -notlike $sw3 -and
        $_.DisplayName -notlike $sw4 -and
        $_.DisplayName -notlike $sw5 -and
        $_.DisplayName -notlike $sw6 -and
        $_.DisplayName -notlike $sw7 -and
        $_.DisplayName -notlike $sw8 -and
        $_.DisplayName -notlike $sw9 } |
    Select-Object DisplayName, DisplayVersion, Publisher

$softwareData += Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\* | 
    Where-Object { $_.DisplayName -and 
        $_.DisplayName -notlike $sw1 -and
        $_.DisplayName -notlike $sw2 -and
        $_.DisplayName -notlike $sw3 -and
        $_.DisplayName -notlike $sw4 -and
        $_.DisplayName -notlike $sw5 -and
        $_.DisplayName -notlike $sw6 -and
        $_.DisplayName -notlike $sw7 -and
        $_.DisplayName -notlike $sw8 -and
        $_.DisplayName -notlike $sw9 } |
    Select-Object DisplayName, DisplayVersion, Publisher

$softwareData = $softwareData | Sort-Object DisplayName -Unique

##--------------------------------------------------------------------------
##    Generate Modern HTML Report
##--------------------------------------------------------------------------

function HtmlEncode($s) { return [System.Net.WebUtility]::HtmlEncode($s) }

# Build CPU section
$cpuHtml = ""
foreach ($cpu in $cpuData) {
    $cpuHtml += "<div class='info-row'><span class='info-label'>Processor</span><span class='info-value'>$(HtmlEncode $cpu.Name)</span></div>"
}

# Build Motherboard section
$moboHtml = ""
foreach ($mobo in $motherboardData) {
    $moboHtml += "<div class='info-row'><span class='info-label'>Manufacturer</span><span class='info-value'>$(HtmlEncode $mobo.Manufacturer)</span></div>"
    $moboHtml += "<div class='info-row'><span class='info-label'>Product</span><span class='info-value'>$(HtmlEncode $mobo.Product)</span></div>"
    $moboHtml += "<div class='info-row'><span class='info-label'>Serial Number</span><span class='info-value'>$(HtmlEncode $mobo.SerialNumber)</span></div>"
}

# Build RAM table rows
$ramHtml = ""
foreach ($ram in $ramData) {
    $ramHtml += "<tr><td>$(HtmlEncode $ram.DeviceLocator)</td><td>$(HtmlEncode $ram.Manufacturer)</td><td>$($ram.CapacityGB)</td><td>$(HtmlEncode $ram.SerialNumber)</td></tr>"
}

# Build Storage table rows
$storageHtml = ""
foreach ($disk in $storageData) {
    $storageHtml += "<tr><td>$(HtmlEncode $disk.Manufacturer)</td><td>$(HtmlEncode $disk.Model)</td><td>$($disk.SizeGB)</td><td>$(HtmlEncode $disk.SerialNumber)</td></tr>"
}

# Build Software table rows (limited to first 100 for performance)
$softwareHtml = ""
$softwareCount = 0
$softwareArray = @()
foreach ($sw in $softwareData | Select-Object -First 100) {
    $softwareHtml += "<tr><td>$(HtmlEncode $sw.DisplayName)</td><td>$(HtmlEncode $sw.DisplayVersion)</td><td>$(HtmlEncode $sw.Publisher)</td></tr>"
    $softwareCount++
}

# Store remaining applications in JavaScript array
$jsSoftwareArray = ""
if ($softwareData.Count -gt 100) {
    $remainingApps = $softwareData | Select-Object -Skip 100
    $jsItems = @()
    foreach ($sw in $remainingApps) {
        $jsItems += "[`"$(HtmlEncode $sw.DisplayName)`",`"$(HtmlEncode $sw.DisplayVersion)`",`"$(HtmlEncode $sw.Publisher)`"]"
    }
    $jsSoftwareArray = $jsItems -join ","
    $remaining = $softwareData.Count - 100
    $softwareHtml += "<tr id='showMoreRow'><td colspan='3'><button class='show-more-btn' onclick='showMoreApps()'>Show $remaining more applications</button></td></tr>"
}

$CpuCount = @($cpuData).Count
$TotalRAM = ($ramData | Measure-Object -Property CapacityGB -Sum).Sum
$DiskCount = @($storageData).Count
$SoftwareCount = @($softwareData).Count

$Html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>System Baseline - $hostname</title>
<style>
  :root { --bg: #0f172a; --surface: #1e293b; --surface2: #334155; --text: #e2e8f0; --text-dim: #94a3b8; --border: #475569;
           --green: #22c55e; --blue: #3b82f6; --amber: #f59e0b; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: var(--bg); color: var(--text); font-family: 'Segoe UI', system-ui, -apple-system, sans-serif; line-height: 1.5; padding: 2rem; }
  .container { max-width: 1200px; margin: 0 auto; }
  
  .classification-banner { 
    background: $color; 
    color: #fff; 
    text-align: center; 
    padding: 8px; 
    font-weight: bold; 
    font-family: 'Courier New', monospace;
    font-size: 1.1rem;
    margin: -2rem -2rem 2rem -2rem;
  }
  
  h1 { font-size: 1.75rem; font-weight: 700; margin-bottom: 0.25rem; }
  .subtitle { color: var(--text-dim); margin-bottom: 2rem; font-size: 0.9rem; }
  
  .summary-grid { 
    display: grid; 
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); 
    gap: 1rem; 
    margin-bottom: 2rem; 
  }
  .summary-card { 
    background: var(--surface); 
    border: 1px solid var(--border); 
    border-radius: 8px; 
    padding: 1.25rem; 
    text-align: center;
    transition: transform 0.15s, border-color 0.15s;
  }
  .summary-card:hover { 
    transform: translateY(-2px); 
    border-color: var(--blue);
  }
  .card-count { 
    font-size: 2rem; 
    font-weight: 700; 
    color: var(--blue);
    margin-bottom: 0.25rem;
  }
  .card-label { 
    font-size: 0.85rem; 
    color: var(--text-dim); 
  }
  
  section { margin-bottom: 2rem; }
  h2 { 
    font-size: 1.2rem; 
    font-weight: 600; 
    margin-bottom: 1rem; 
    padding-bottom: 0.5rem; 
    border-bottom: 1px solid var(--border);
    color: var(--text);
  }
  
  .info-section {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 1.25rem;
  }
  .info-row {
    display: flex;
    justify-content: space-between;
    padding: 0.5rem 0;
    border-bottom: 1px solid var(--surface2);
  }
  .info-row:last-child {
    border-bottom: none;
  }
  .info-label {
    color: var(--text-dim);
    font-size: 0.9rem;
  }
  .info-value {
    color: var(--text);
    font-weight: 500;
    font-size: 0.9rem;
    text-align: right;
  }
  
  .table-wrap { 
    background: var(--surface); 
    border: 1px solid var(--border); 
    border-radius: 8px; 
    overflow: hidden; 
  }
  table { 
    width: 100%; 
    border-collapse: collapse; 
    font-size: 0.85rem; 
  }
  th { 
    background: var(--surface2); 
    color: var(--text-dim); 
    text-align: left; 
    padding: 0.75rem; 
    font-weight: 600; 
    position: sticky; 
    top: 0; 
  }
  td { 
    padding: 0.6rem 0.75rem; 
    border-bottom: 1px solid var(--surface2); 
    vertical-align: top; 
  }
  tr:hover td { 
    background: #ffffff06; 
  }
  tr:last-child td {
    border-bottom: none;
  }
  .show-more-btn {
    background: var(--surface2);
    color: var(--text);
    border: 1px solid var(--border);
    padding: 0.5rem 1rem;
    border-radius: 6px;
    cursor: pointer;
    font-size: 0.85rem;
    width: 100%;
    transition: background 0.15s, border-color 0.15s;
  }
  .show-more-btn:hover {
    background: var(--blue);
    border-color: var(--blue);
  }
  
  footer { 
    text-align: center; 
    color: var(--text-dim); 
    font-size: 0.75rem; 
    padding-top: 2rem; 
    border-top: 1px solid var(--border); 
    margin-top: 2rem; 
  }
  
  @media print {
    body { background: white; color: black; }
    .classification-banner { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
  }
</style>
</head>
<body>
<div class="classification-banner">$classification - $hostname - $Date - $classification</div>

<div class="container">
  <h1>System Baseline Report</h1>
  <div class="subtitle">Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') &mdash; $hostname</div>

  <div class="summary-grid">
    <div class="summary-card">
      <div class="card-count">$CpuCount</div>
      <div class="card-label">CPU(s)</div>
    </div>
    <div class="summary-card">
      <div class="card-count">$TotalRAM</div>
      <div class="card-label">Total RAM (GB)</div>
    </div>
    <div class="summary-card">
      <div class="card-count">$DiskCount</div>
      <div class="card-label">Disk Drive(s)</div>
    </div>
    <div class="summary-card">
      <div class="card-count">$SoftwareCount</div>
      <div class="card-label">Installed Applications</div>
    </div>
  </div>

  <section>
    <h2>System Information</h2>
    <div class="info-section">
      <div class="info-row"><span class="info-label">Computer Name</span><span class="info-value">$(HtmlEncode $compInfo.CsName)</span></div>
      <div class="info-row"><span class="info-label">Domain</span><span class="info-value">$(HtmlEncode $compInfo.CsDomain)</span></div>
      <div class="info-row"><span class="info-label">Domain Role</span><span class="info-value">$DomainRole</span></div>
      <div class="info-row"><span class="info-label">Operating System</span><span class="info-value">$(HtmlEncode $OS)</span></div>
      <div class="info-row"><span class="info-label">Last Boot Time</span><span class="info-value">$BootTime</span></div>
    </div>
  </section>

  <section>
    <h2>Processor</h2>
    <div class="info-section">
      $cpuHtml
    </div>
  </section>

  <section>
    <h2>Motherboard</h2>
    <div class="info-section">
      $moboHtml
    </div>
  </section>

  <section>
    <h2>Memory ($($ramData.Count) Module$(if ($ramData.Count -eq 1) { '' } else { 's' }))</h2>
    <div class="table-wrap">
      <table>
        <thead>
          <tr><th>Device Locator</th><th>Manufacturer</th><th>Capacity (GB)</th><th>Serial Number</th></tr>
        </thead>
        <tbody>
          $ramHtml
        </tbody>
      </table>
    </div>
  </section>

  <section>
    <h2>Storage Devices</h2>
    <div class="table-wrap">
      <table>
        <thead>
          <tr><th>Manufacturer</th><th>Model</th><th>Size (GB)</th><th>Serial Number</th></tr>
        </thead>
        <tbody>
          $storageHtml
        </tbody>
      </table>
    </div>
  </section>

  <section>
    <h2>Installed Software ($SoftwareCount Applications)</h2>
    <div class="table-wrap">
      <table>
        <thead>
          <tr><th>Application Name</th><th>Version</th><th>Publisher</th></tr>
        </thead>
        <tbody>
          $softwareHtml
        </tbody>
      </table>
    </div>
  </section>

  <footer>Generate-Baseline.ps1 &mdash; System Baseline Report</footer>
</div>

<script>
const moreApps = [$jsSoftwareArray];
function showMoreApps() {
    const tbody = document.querySelector('#showMoreRow').parentNode;
    const btnRow = document.getElementById('showMoreRow');
    moreApps.forEach(function(app) {
        const row = document.createElement('tr');
        row.innerHTML = '<td>' + app[0] + '</td><td>' + app[1] + '</td><td>' + app[2] + '</td>';
        tbody.insertBefore(row, btnRow);
    });
    btnRow.remove();
}
</script>

</body>
</html>
"@

# Write HTML to file
$Html | Out-File -FilePath $htmlPath -Encoding utf8
Write-Host "`nBaseline report saved to: $htmlPath" -ForegroundColor Green
Write-Host "Opening in default browser..." -ForegroundColor Cyan

# Open generated HTML for review
&$htmlPath
