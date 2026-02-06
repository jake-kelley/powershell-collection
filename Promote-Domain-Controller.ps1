<# 
    Promote-Domain-Controller.ps1
    Written By: Jake Kelley
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
