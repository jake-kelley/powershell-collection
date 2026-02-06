<#
.SYNOPSIS
    Bulk create local Windows users from a CSV file.

.DESCRIPTION
    This script imports user information from a CSV file and creates local Windows user accounts.
    The script automatically elevates to Administrator privileges if not already running elevated.
    
    The CSV file must contain the following columns:
    - UserName: The login name for the user
    - FullName: The display name for the user
    - Description: A description for the user account
    - Password: The initial password for the user

.PARAMETER userFile
    Path to the CSV file containing user information.

.EXAMPLE
    .\Create-LocalUsersFromCSV.ps1 -userFile "C:\users.csv"
    Creates local users from the specified CSV file.

.EXAMPLE
    .\Create-LocalUsersFromCSV.ps1 -userFile ".\users.csv"
    Creates local users from a CSV file in the current directory.

.NOTES
    Requires Administrator privileges (will auto-elevate if needed).
    The CSV file must have headers: UserName, FullName, Description, Password.

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

# CSV file parameter
Param(
    [string]$userFile
)

if(-not($userFile)) {
    Throw "You must provide a file path for -userFile"
}
else {
    # Import CSV to $AllUsers
    $AllUsers = Import-CSV "$userFile"

    foreach ($User in $AllUsers)
          {
          write-host Creating user account $user.Username
          $objOU = [adsi]"WinNT://."
            # Create user account
          $objUser = $objOU.Create("User", $User.Username)
            # Set password
          $objuser.setPassword($User.Password)
            # Set FullName
          $objUser.put("FullName",$User.FullName)
            # Set Description
          $objUser.put("Description",$User.Description)
            # User must change password on next log on
          #$objuser.PasswordExpired = 0
          }
}
