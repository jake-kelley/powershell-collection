<#
.SYNOPSIS
    Parses Windows Security Event Logs into HTML reports for security auditing.

.DESCRIPTION
    This script performs comprehensive security log auditing by exporting Windows
    Security, Application, and System event logs and parsing them into formatted
    HTML reports. It focuses on event IDs relevant to NIST 800-53 auditing
    requirements including account management, logon events, privilege escalation,
    and system changes.
    
    The script gathers additional system information including Windows Update
    history, Symantec DAT versions, and computer information to provide context
    for the audit data.
    
    Event logs are exported to EVTX format and parsed to HTML with classification
    banners. If configured, the script can also copy audit files to a network
    backup location.

.PARAMETER None
    Configuration is done via variables in the "User-Specified Variables" section.

.EXAMPLE
    .\weekly-standalone-audit-v1.4.ps1
    Exports security logs and generates HTML audit report for local review.

.NOTES
    Requires Administrator privileges (will auto-elevate if needed).
    Default output location: C:\Admin\Audits\
    Set $AuditBackupRoot to a network path for remote backup functionality.
    Modify classification and banner color in the "SET CLASSIFICATION" section.
    Event IDs follow NIST 800-53 auditing requirements.

.AUTHOR
    Jake Kelley
    Version: 1.4
    Last Updated: 2021-08-04
#>

<#
    USER-VARIABLE CHANGES:
    ALL SYSTEMS                  SET EXPORT OR CLEAR IN BELOW SECTION
                                 SET APPROPRIATE CLASSIFICATION IN BELOW SECTION
                                 
    PEER-TO-PEER / DOMAINS       SET LINE 82 TO NETWORK SHARE LOCATION FOR AUDIT LOGS

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




##--------------------------------------------------------------------------
##    Windows Update Query Functions
##--------------------------------------------------------------------------

# Convert Wua History ResultCode to a Name # 0, and 5 are not used for history # See https://msdn.microsoft.com/en-us/library/windows/desktop/aa387095(v=vs.85).aspx
function Convert-WuaResultCodeToName {
    param( [Parameter(Mandatory=$true)][int] $ResultCode )
    $Result = $ResultCode
    switch($ResultCode) {
        2 {
            $Result = "Succeeded"
        }
        3 {
            $Result = "Succeeded With Errors"
        }
        4 {
            $Result = "Failed"
        }
    }
    return $Result
}

function Get-WuaHistory {
    # Get a WUA Session
    $session = (New-Object -ComObject 'Microsoft.Update.Session')
    # Query the latest 10 History starting with the first record
    $history = $session.QueryHistory("",0,10) | ForEach-Object {
        $Result = Convert-WuaResultCodeToName -ResultCode $_.ResultCode
        # Make the properties hidden in com properties visible.
        $_ | Add-Member -MemberType NoteProperty -Value $Result -Name Result
        $Product = $_.Categories | Where-Object {$_.Type -eq 'Product'} | Select-Object -First 1 -ExpandProperty Name
        $_ | Add-Member -MemberType NoteProperty -Value $_.UpdateIdentity.UpdateId -Name UpdateId
        $_ | Add-Member -MemberType NoteProperty -Value $_.UpdateIdentity.RevisionNumber -Name RevisionNumber
        $_ | Add-Member -MemberType NoteProperty -Value $Product -Name Product -PassThru
        Write-Output $_
    }
    # Remove null records and only return the fields we want
    $history |
    Where-Object {![String]::IsNullOrWhiteSpace($_.title)} |
    Select-Object Result, Date, Title, SupportUrl, Product, UpdateId, RevisionNumber
}




##--------------------------------------------------------------------------
##    User-Specified Variables
##--------------------------------------------------------------------------
# Sets Remote Audit Backup Directory. Leave as "NULL" for standalone machines. Don't forget the trailing "\"
# Example: \\dfsroot\share\folder\
$AuditBackupRoot = "NULL"

# Virus and Spyware DAT
$sdsDatsFile = "C:\ProgramData\Symantec\Symantec Endpoint Protection\CurrentVersion\Data\Definitions\SDSDefs\definfo.dat"

# Proactive Threat DAT
$ipsDatsFile = "C:\ProgramData\Symantec\Symantec Endpoint Protection\CurrentVersion\Data\Definitions\IPSDefs\definfo.dat"

# Network and Host Exploit DAT
$bashDatsFile = "C:\ProgramData\Symantec\Symantec Endpoint Protection\CurrentVersion\Data\Definitions\BASHDefs\definfo.dat"




##--------------------------------------------------------------------------
##    Script-Generated Variables
##--------------------------------------------------------------------------
# Get Machine Hostname and set as variable
$hostname = Get-Content env:computername

# Date in format(YYYY_MM_DD)
$Date = "(" + (Get-Date -Format MM-dd-yyyy_HHmm) + ")"

# Set Local Audit directory root to C:\Audits\HOSTNAME(YEAR_Audits)\
$AuditRoot = "C:\Admin\Audits\" + $Hostname + "(" + (Get-Date).Year + "_Audits)\"

# Set Local EVTX directory root
$EVTXRoot = $AuditRoot + "evtx_files\"

# Set Local HTML directory root
$HTMLRoot = $AuditRoot + "html_files\"

# EVTX Filename in format HOSTNAME(YYYY-MM-DD).evtx
$EVTXFilename = $EVTXRoot + $Hostname + $Date + ".evtx"

# EVTX Wildcard variable (used in the copy commandlet at end of file)
$EVTXWildcard = $EVTXRoot + "*.evtx"

# HTML Filename in format HOSTNAME(YYYY-MM-DD).html
$HTMLFilename = $HTMLRoot + $Hostname + $Date+ ".html"

# HTML Wildcard variable (used in the copy commandlet at end of file)
$HTMLWildcard = $HTMLRoot + "*.html"

# Set Local EVTX directory root and filenames for Application and System Logs
$EVTXRootAppLog = $AuditRoot + "app_evtx_files\"
$EVTXRootSystem = $AuditRoot + "sys_evtx_files\"
$EVTXFilenameAppLog = $EVTXRootAppLog + $Hostname + $Date + ".evtx"
$EVTXFilenameSystem = $EVTXRootSystem + $Hostname + $Date + ".evtx"

# Sets Remote Audit Backup Directories for this machine as \\path\to\server\Hostname(YEAR_Audits)\
if($AuditBackupRoot -ne "NULL") {

$AuditBackupHostnameRoot = $AuditBackupRoot + $Hostname + "\(" + (Get-Date).Year + "_Audits)\"
$AuditBackupHostnameEVTXRoot = $AuditBackupHostnameRoot + "evtx_files\"
$AuditBackupHostnameHTMLRoot = $AuditBackupHostnameRoot + "html_files\"

}




##--------------------------------------------------------------------------
##    Define Relevant Windows Event IDs
##--------------------------------------------------------------------------

#   ID		MEANING
#   ----    ----------------------------------------------------------------
#   1100	Windows is shutting down
#   1102	Audit log was cleared. This can relate to a potential attack
#   4608	Windows is starting up
#   4616	System time was changed
#   4624	Successful account log on
#   4625	Failed account log on
#   4634	An account logged off
#   4647	User initiated logoff
#   4656	A handle to an object was requested
#   4657	A registry value was changed
#   4658	A handle to an object was closed
#   4663	An attempt was made to access an object
#   4719	System audit policy was changed.
#   4720	A user account was created
#   4722	A user account was enabled
#   4725	A user account was disabled
#   4726	A user account was deleted
#   4728	A user was added to a privileged global group
#   4732	A user was added to a privileged local group
#   4735	A privileged local group was modified
#   4737	A privileged global group was modified
#   4738	A user account was changed
#   4740	A user account was locked out
#   4755	A privileged universal group was modified
#   4756	A user was added to a privileged universal group
#   4767	A user account was unlocked
#   4800    The workstation was locked
#   4801    The workstation was unlocked
# removed  4697	An attempt was made to install a service
# removed  4698	Events related to Windows scheduled tasks being created, modified, deleted, enabled or disabled
# removed  4699	Events related to Windows scheduled tasks being created, modified, deleted, enabled or disabled
# removed  4700	Events related to Windows scheduled tasks being created, modified, deleted, enabled or disabled
# removed  4701	Events related to Windows scheduled tasks being created, modified, deleted, enabled or disabled
# removed  4702	Events related to Windows scheduled tasks being created, modified, deleted, enabled or disabled
# removed  4772	A Kerberos authentication ticket request failed
# removed  4777	The domain controller failed to validate the credentials of an account.
# removed  4946	A rule was added to the Windows Firewall exception list
# removed  4947	A rule was modified in the Windows Firewall exception list
# removed  4950	A setting was changed in Windows Firewall
# removed  4954	Group Policy settings for Windows Firewall has changed
# removed  5025	The Windows Firewall service has been stopped
# removed  5157	Windows Filtering Platform blocked a connection
# removed  5447	A Windows Filtering Platform filter was changed


# Specify the relevant security events that we want to audit. It is formatted for an XPath query.
$EventIDs1 = "EventID=1102 or EventID=4624 or EventID=4625 or EventID=4647 or EventID=4704 or EventID=4705 or EventID=4720 or EventID=4722 or EventID=4723 or EventID=4724 or EventID=4725 or EventID=4726 or EventID=4738 or EventID=4739 or EventID=4740 or EventID=4663 or EventID=4777 or EventID=6416"
$EventIDs2 = "EventID=1100 or EventID=4608 or EventID=4616 or EventID=4656 or EventID=4657 or EventID=4658 or EventID=4719 or EventID=4728 or EventID=4732 or EventID=4735 or EventID=4737 or EventID=4755" 
$EventIDs3 = "EventID=4756 or EventID=4767 or EventID=4800 or EventID=4801"




##--------------------------------------------------------------------------
##    XML Querying
##--------------------------------------------------------------------------

# XML Filter for Get-WinEvent that includes only the relevant Events for auditing and removes most SYSTEM events.
$XMLFilter = @"
<QueryList>
	<Query Id="0" Path="file://$EVTXFilename">
		<Select>*[System[($EventIDs1)]]</Select>
        <Select>*[System[($EventIDs2)]]</Select>
        <Select>*[System[($EventIDs3)]]</Select>
		<Suppress>*[EventData[Data[@Name="TargetUserName"] = 'SYSTEM']] or *[EventData[Data[@Name="TargetUserName"] = 'LOCAL SERVICE']] or *[EventData[Data[@Name="TargetUserName"] = 'NETWORK SERVICE']] or *[EventData[Data[@Name="TargetUserName"] = 'ANONYMOUS LOGON']] or *[EventData[Data[@Name="TargetUserSid"] = 'S-1-5-18']]</Suppress>
        <Suppress>*[System[(EventID=4672)]] and (*[EventData[Data[@Name="SubjectUserName"] = 'SYSTEM']] or *[EventData[Data[@Name="SubjectUserName"] = 'LOCAL SERVICE']] or *[EventData[Data[@Name="SubjectUserName"] = 'NETWORK SERVICE']] or *[EventData[Data[@Name="SubjectUserSid"] = 'S-1-5-18']])</Suppress>
        <Suppress>*[System[(EventID=4624)]] and (*[EventData[Data[@Name='LogonType'] and (Data='3'or Data='4' or Data='5' or Data='6' or Data='8' or Data='9')]])</Suppress>
        <Suppress>*[System[(EventID=4663)]] and (*[EventData[Data[@Name='ObjectType'] and (Data='Key' or Data='SAM' or Data='SERVICE OBJECT')]])</Suppress>
        <Suppress>*[System[(EventID=4624)]] and (*[EventData[Data[@Name="TargetUserSid"] = 'S-1-5-18']])</Suppress>
        <Suppress>*[System[(EventID=4624)]] and (*[EventData[Data[@Name="VirtualAccount"] = '%%1842']])</Suppress>
        <Suppress>*[System[(EventID=4634)]] and (*[EventData[Data[@Name="TargetUserSid"] = 'S-1-5-18']])</Suppress>
        <Suppress>*[System[(EventID=4647)]] and (*[EventData[Data[@Name="TargetUserSid"] = 'S-1-5-18']])</Suppress>
        <Suppress>*[System[(EventID=4663)]] and (*[EventData[Data[@Name="ObjectName"] = '\Device\CdRom0\']])</Suppress>
        <Suppress>*[System[(EventID=6416)]] and (*[EventData[Data[@Name="ClassName"] = 'Mouse']] or *[EventData[Data[@Name="ClassName"] = 'Keyboard']])</Suppress>
        <Suppress>*[System[(EventID=6416)]] and (*[EventData[Data[@Name="DeviceDescription"] = 'OneNote']])</Suppress>
        <Suppress>*[System[(EventID=6416)]] and (*[EventData[Data[@Name="DeviceDescription"] = 'Send to OneNote 16']])</Suppress>
        <Suppress>*[System[(EventID=6416)]] and (*[EventData[Data[@Name="DeviceDescription"] = 'Fax']])</Suppress>
        <Suppress>*[System[(EventID=6416)]] and (*[EventData[Data[@Name="DeviceDescription"] = 'Microsoft Print to PDF']])</Suppress>
        <Suppress>*[System[(EventID=6416)]] and (*[EventData[Data[@Name="DeviceDescription"] = 'Microsoft XPS Document Writer']])</Suppress>
	</Query>
</QueryList>
"@

# The @_.UserID field in the Windows Security Log is not populated with the relevant user ID. That information must be parsed from the XML Structure of the respective security event.
# The UserID for relevant Event IDs is found in a few different XML Nodes/Attributes depending on the Event ID. The regex format is used to parse the event log using the correct XPath query for the respective XML Node Structure.

# Define events that return the UserID using the Xpath query *[UserData[LogFileCleared["SubjectUserName"]]]
$EventIDsClass1 = "1102"

# Define events that return the UserID using the Xpath query *[EventData[Data[@Name = "TargetUserName"]]]
$EventIDsClass2 = "4624|4625|4634|4647|4704|4705|4720|4722|4723|4724|4725|4726|4728|4732|4756|4738|4767|4735|4737|4755|4772|4777|4616|4657|4697|4698|4699|4700|4701|4702|4946|4947|4950|4954|5025|5157|5447|4656|4663|4658|4740|4776|4800|4801"

# Define events that return the UserID using the Xpath query *[EventData[Data[@Name = "SubjectUserName"]]]
$EventIDsClass3 = "4672|4739"

# XML Query for UserID
$userQuery = {  
        [XML]$XML = $_.ToXML(); SWITCH -regex ($_.ID){
		    # Because default namespaces are specific 1102 Events (log cleared), it's easiest to extract the user name using the full xml path.
		    $EventIDsClass1 {
    		    $XML.Event.UserData.LogFileCleared.SubjectUserName 
            }
		    $EventIDsClass2 {
                $XML.SelectSingleNode("//*[@Name='TargetUserName']") | select -expandproperty '#text'
            }
		    $EventIDsClass3 {
                $XML.SelectSingleNode("//*[@Name='SubjectUserName']") | select -expandproperty '#text'
            }
		}
}




##--------------------------------------------------------------------------
##    Clear/Backup Security Log and Parse to HTML FILE
##--------------------------------------------------------------------------

# Check that Audit directory exists, if not create it
if(!(Test-Path -path $AuditRoot)) {
    New-Item $EVTXRoot -type directory
    New-Item $HTMLRoot -type directory
}
# Check if Application and System EVTXRoot exist, if not create them
if(!(Test-Path -path $EVTXRootAppLog)) {
		New-Item $EVTXRootAppLog -type directory
}
if(!(Test-Path -path $EVTXRootSystem)) {
		New-Item $EVTXRootSystem -type directory
}
<# --- EXPORT OR CLEAR --- #>
# Uses Windows events Command Line Utility to clear the security log and back up to an evtx file. epl exports, cl clears and backs up
#wevtutil cl Security /bu:$EVTXFilename
#wevtutil cl Application /bu:$EVTXFilenameAppLog
#wevtutil cl System /bu:$EVTXFilenameSystem
wevtutil epl Security $EVTXFilename
wevtutil epl Application $EVTXFilenameAppLog
wevtutil epl System $EVTXFilenameSystem
<# --- EXPORT OR CLEAR --- #>

# Gather the relevant auditable events.
$Events = Get-WinEvent -FilterXml $XMLFilter




##--------------------------------------------------------------------------
##    CSS/HTML STYLES AND VARIABLES     
##--------------------------------------------------------------------------

<# --- SET CLASSIFICATION --- #>
# HTML Banner Variables - Uncomment desired variables
$classification = "UNCLASSIFIED"
#$classification = "SECRET"
#$classification = "TOP SECRET"
#$classification = "TOP SECRET//SCI"
$color = "green" #unclassified
#$color = "red" #secret
#$color = "DarkOrange" #top secret
#$color = "gold" #top secret//sci
<# --- SET CLASSIFICATION --- #>

# Get DAT Version Variables
$sdsDats = if(Test-Path $sdsDatsFile) { (get-content "$sdsDatsFile") | Select-String -Pattern '[0-9]{8}' -AllMatches | % { $_.Matches } | % { $_.Value } }
$ipsDats = if(Test-Path $ipsDatsFile) { (get-content "$ipsDatsFile") | Select-String -Pattern '[0-9]{8}' -AllMatches | % { $_.Matches } | % { $_.Value } }
$bashDats = if(Test-Path $bashDatsFile) { (get-content "$bashDatsFile") | Select-String -Pattern '[0-9]{8}' -AllMatches | % { $_.Matches } | % { $_.Value } }

# HTML Banner - Classification & Hostname & Date & Classification
$header = @"
<header style="position: sticky; top: 0; padding: 5px; background: $color; text-align:center; font-size: 20px; font-family: Courier, monospace; font-weight: bold; ">
    $classification - $hostname - $Date - $classification
</header>
"@

# HTML Heading - System Information
$h1 = @" 
<h3 style="text-align:left;font-family:Courier;color:#000000;">System Information</h3>
"@

# HTML Heading - Update History
$h2 = @" 
<h3 style="text-align:left;font-family:Courier;color:#000000;padding-top:2%">Update History (Last 10)</h3>
"@

# HTML Heading - Symantec DAT Versions
$h3 = @" 
<h3 style="text-align:left;font-family:Courier;color:#000000;padding-top:2%">Symantec DAT Versions</h3>
"@
 
# HTML Table Data - Symantec DAT Versions
$datTable = @"
<table><thead><tr><th>Virus and Spyware DAT</th><th>Proactive Threat DAT</th><th>Network and Host Exploit DAT</th></tr></thead><tbody><tr><td>$sdsDats</td><td>$bashDats</td><td>$ipsDats</td></tr></tbody></table>
"@

# HTML Heading - Audit Logs
$h4 = @" 
<h3 style="text-align:left;font-family:Courier;color:#000000;padding-top:2%">Audit Logs</h3>
"@ 

# HTML Table/Body Formatting
$body = @"
<style>
TABLE {
    border-width: 2px;
    border-style: solid;
    border-color: black;
    border-collapse: collapse;
    width: 100%;
}
tr:nth-child(odd) {
    background-color: #DCDCDC;
}
TH {
    background-color: SteelBlue;
    text-align: left;
    border-width: 1px;
    padding: 3px;
    border-style: solid;
    border-color: black;
    font-family: Courier;
}
TD {
    text-align: left;
    border-width: 1px;
    padding: 8px;
    border-style: solid;
    border-color: black;
}
</style>
"@

# HTML Footer - Classification & Hostname & Date & Classification
$footer = @"
<footer style="position: sticky; bottom: 0; padding: 5px; background: $color; text-align:center; font-size: 20px; font-family: Courier, monospace; font-weight: bold;">
    $classification - $hostname - $Date - $classification
</footer>
"@




##--------------------------------------------------------------------------
##    Create HTML Report
##--------------------------------------------------------------------------

$sysinfo = get-computerinfo | 
ConvertTo-Html -Property CsName, CsDomain, CsDomainRole, OSLastBootUpTime, WindowsProductName, WindowsVersion -Body $body

$updateHistory = Get-WUAHistory | 
ConvertTo-Html -Property Result, Date, Title -Body $body

$Events | 
ConvertTo-Html -Property TimeCreated, Id, @{Label="User ID";Expression=$userQuery}, TaskDisplayName, Message -head $header -precontent ($h1 + $sysinfo + $h2 + $updateHistory + $h3 + $datTable + $h4 ) -body $body -PostContent $footer | 
Out-File $HTMLFilename




##--------------------------------------------------------------------------
##    Backup EVTX and HTML Files to remote target
##--------------------------------------------------------------------------

# Copies all evtx and html files to Audit directory, if the backup target was specified
if($AuditBackupRoot -ne "NULL") {
    # Checks that Audit directory exists on the backup target, if not create it
    if(!(Test-Path -path $AuditBackupHostnameRoot)) {
        New-Item $AuditBackupHostnameEVTXRoot -type directory
        New-Item $AuditBackupHostnameHTMLRoot -type directory
    }
    robocopy $EVTXRoot $AuditBackupHostnameEVTXRoot *.evtx /XO /XN
    robocopy $HTMLRoot $AuditBackupHostnameHTMLRoot *.html /XO /XN
}

&$HTMLFilename

# End of Script
