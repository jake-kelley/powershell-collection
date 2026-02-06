<#
.SYNOPSIS
    Promotes a Windows Server to a Domain Controller and creates a new forest.

.DESCRIPTION
    This script automates the process of promoting a Windows Server to a Domain
    Controller. It first installs the Active Directory Domain Services (ADDS) role,
    then configures a new forest root domain with the specified domain name.
    
    The script prompts for the domain name and a safe mode administrator password
    during execution. DNS services are automatically installed and configured.

.PARAMETER None
    All parameters are collected interactively via Read-Host prompts.

.EXAMPLE
    .\Promote-Domain-Controller.ps1
    Installs ADDS role and promotes server to Domain Controller for a new forest.

.NOTES
    Requires Administrator privileges (will auto-elevate if needed).
    This will restart the server automatically after promotion.
    Ensure the server has a static IP address configured before running.
    Suitable for creating the first Domain Controller in a new forest.

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

$domain = Read-Host "Please enter domain name, ex. contoso.com"
$password = Read-Host "Please enter a safe mode password" -AsSecureString

# Ensures ADDS is installed
Install-WindowsFeature -Name Ad-Domain-Services -IncludeManagementTools

# Configures new forest root domain
Install-ADDSForest -DomainName $domain -SafeModeAdministratorPassword $password -InstallDNS -Force
