<#
.SYNOPSIS
    Removes pre-installed Windows 10 bloatware applications.

.DESCRIPTION
    This script removes a predefined list of built-in Windows 10 applications
    that are commonly considered bloatware or unnecessary. It removes both the
    installed AppX packages for the current user and the provisioned packages
    that would be installed for new users.
    
    Applications removed include: 3D Builder, Bing apps, Solitaire, People,
    Xbox apps, Zune apps, Get Started, Feedback Hub, Office Hub, and more.

.PARAMETER None
    No parameters required. The list of apps is defined within the script.

.EXAMPLE
    .\Remove-Bloatware.ps1
    Removes all bloatware applications from the system.

.NOTES
    Run as Administrator for best results.
    Some applications may require a restart to be fully removed.
    Use caution when running on systems where some of these apps may be needed.
    The script will display which packages were found and removed.

.AUTHOR
    Jake Kelley
#>

# List of apps to search for and remove
$AppsList = 
'Microsoft.3DBuilder',
'Microsoft.BingFinance',
'Microsoft.BingNews',
'Microsoft.BingSports',
'Microsoft.MicrosoftSolitaireCollection',
'Microsoft.People',
'microsoft.windowscommunicationsapps',
'Microsoft.WindowsPhone',
'Microsoft.WindowsSoundRecorder',
'Microsoft.XboxApp',
'Microsoft.ZuneMusic',
'Microsoft.ZuneVideo',
'Microsoft.Getstarted',
'Microsoft.WindowsFeedbackHub',
'Microsoft.XboxIdentityProvider',
'Microsoft.MicrosoftOfficeHub'

ForEach ($App in $AppsList){
    # Search for Packages
    $PackageFullName = (Get-AppxPackage $App).PackageFullName
    $ProPackageFullName = (Get-AppxProvisionedPackage -Online | Where-Object {$_.Displayname -eq $App}).PackageName
    Write-host $PackageFullName
    Write-Host $ProPackageFullName
    
    # Remove Package
    if ($PackageFullName){
        Write-Host "Removing Package: $App" -BackgroundColor DarkGreen
        Remove-AppxPackage -Package $PackageFullName
    }
    else{
        Write-Host "Unable to find package: $App" -BackgroundColor Red
    }
    
    # Remove Pro Package
    if ($ProPackageFullName){
        Write-Host "Removing Provisioned Package: $ProPackageFullName" -BackgroundColor DarkGreen
        Remove-AppxProvisionedPackage -Online -Packagename $ProPackageFullName
    }
    else{
        Write-Host "Unable to find provisioned package: $App" -BackgroundColor Red
    }
}

# End of Script