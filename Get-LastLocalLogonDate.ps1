<#
.SYNOPSIS
    Retrieves and exports the last logon dates for all local user accounts.

.DESCRIPTION
    This script queries all local user accounts on the system and retrieves their
    last logon timestamps. The results are formatted as a table and exported to
    a text file for auditing or documentation purposes.
    
    The script automatically elevates to Administrator privileges if needed.

.PARAMETER None
    No parameters required. Output path is hardcoded in the script.

.EXAMPLE
    .\Get-LastLocalLogonDate.ps1
    Exports last logon dates to C:\Admin\LastLocalLogonDate.txt

.NOTES
    Requires Administrator privileges (will auto-elevate if needed).
    Output is saved to C:\Admin\LastLocalLogonDate.txt
    Only queries local accounts, not domain accounts.

.AUTHOR
    Jake Kelley
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

$adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
$adsi.Children | where {$_.SchemaClassName -eq 'user'} | ft name,lastlogin | Out-File C:\Admin\LastLocalLogonDate.txt
