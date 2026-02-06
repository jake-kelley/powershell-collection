<#
.SYNOPSIS
    Installs offline Microsoft Windows updates (.msu files) in the correct order.

.DESCRIPTION
    This script automates the installation of standalone Windows updates (MSU files).
    It detects and installs Servicing Stack Updates (SSU) first, followed by
    Cumulative Updates, ensuring proper installation order.
    
    The script generates pre-patch and post-patch hotfix lists and compares them
    to show which updates were successfully installed.

.PARAMETER None
    Configuration is done via the $UpdatePath variable in the script.

.EXAMPLE
    .\Install-MSU.ps1
    Installs all MSU files from C:\patches following proper SSU-first order.

.NOTES
    Requires Administrator privileges (will auto-elevate if needed).
    Update files must be placed in C:\patches (configurable via $UpdatePath).
    SSU files must have "ssu" prefix in filename.
    Cumulative updates must have "cumulative" prefix in filename.
    Installation logs saved to C:\patches\wusa-log.evt

.AUTHOR
    Jake Kelley
    Date: 24 AUG 2021
    Revision: 1.0
#>

##--------------------------------------------------------------------------
##    ELEVATE SCRIPT PRIVILEGES TO ADMINISTRATOR
##--------------------------------------------------------------------------
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
  # Relaunch as an elevated process:
  Start-Process powershell.exe "-File",('"{0}"' -f $MyInvocation.MyCommand.Path) -Verb RunAs
  exit
}

# Directory of MSU patches
$UpdatePath = "C:\patches"

# Old hotfix list
Write-Host "Generating update list pre-patch..." -BackgroundColor Green -ForegroundColor Black
Get-HotFix | sort -descending > "$UpdatePath\old_hotfix_list.txt"

# Get all updates
$UpdatesSSU = Get-ChildItem -Path $UpdatePath -Recurse | Where-Object {$_.Name -like "ssu*msu*"}
$UpdatesCumulative = Get-ChildItem -Path $UpdatePath -Recurse | Where-Object {$_.Name -like "cumulative*msu*"}

Write-Host "Installing SSU Updates..." -BackgroundColor Green -ForegroundColor Black
# Iterate through each SSU update
ForEach ($update in $UpdatesSSU) {
    # Get the full file path to the update
    $UpdateFilePath = $update.FullName
    # Logging
    write-host "Installing update $($update.BaseName)"
    # Install update - use start-process -wait so it doesnt launch the next installation until its done
    Start-Process -wait wusa -ArgumentList "/update $UpdateFilePath","/quiet","/norestart"
}

Write-Host "Installing Cumulative Updates..." -BackgroundColor Green -ForegroundColor Black
# Iterate through each cumulative update
ForEach ($update in $UpdatesCumulative) {
    # Get the full file path to the update
    $UpdateFilePath = $update.FullName
    # Logging
    write-host "Installing update $($update.BaseName)"
    # Install update - use start-process -wait so it doesnt launch the next installation until its done
    Start-Process -wait wusa -ArgumentList "/update $UpdateFilePath","/quiet","/norestart", "/log:$UpdatePath\wusa-log.evt"
}

# New hotfix list
Write-Host "Generating update list post-patch..." -BackgroundColor Green -ForegroundColor Black
Get-HotFix | sort -descending > "$UpdatePath\new_hotfix_list.txt"

# Compare Old to New and output to screen
Write-Host "Installed updates:" -BackgroundColor Green -ForegroundColor Black
diff (cat $UpdatePath\old_hotfix_list.txt) (cat $UpdatePath\new_hotfix_list.txt)

Write-Host "Closing in 5 seconds..." -BackgroundColor Red
Sleep -Seconds 5
