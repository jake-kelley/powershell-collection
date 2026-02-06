<#
    Remove set list of Windows 10 built-in bloatware
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