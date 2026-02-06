<#
.SYNOPSIS
    Initializes, partitions, and formats a new disk drive.

.DESCRIPTION
    This script automates the setup of a new disk by prompting for the disk number,
    desired drive letter, and volume label. It then clears the disk, initializes it,
    creates a new partition using the maximum available space, and formats it as NTFS.

.PARAMETER None
    All parameters are collected interactively via Read-Host prompts.

.EXAMPLE
    .\Partition-New-Disk.ps1
    Interactively prompts for disk selection and formatting options.

.NOTES
    Run as Administrator (disk operations require elevated privileges).
    This script will CLEAR ALL DATA on the selected disk.
    Uses the maximum available space for the new partition.
    Formats the partition as NTFS.

.AUTHOR
    Jake Kelley
#>

# List disks to console
Get-Disk

# Prompt for disk selection
$diskSelection = Read-Host "Which disk would you like to modify: "

# Prompt for DriveLetter
$driveLetter = Read-Host "Enter capital drive letter, ex. 'B': "

# Prompt for NewFileSystemLabel
$newFileSystemLabel = Read-Host "Enter label for drive: "

# Clear selected disk
Write-Host "Clearing Disk..." -BackgroundColor DarkGreen
Get-Disk $diskSelection | Clear-Disk -RemoveData

# Initialize selected disk
Write-Host "Initializing Disk..." -BackgroundColor DarkGreen
Initialize-Disk -Number $diskSelection

# Create partition and format as NTFS
Write-Host "Partitioning and Formatting..." -BackgroundColor DarkGreen
New-Partition -DiskNumber $diskSelection -UseMaximumSize -DriveLetter $driveLetter| Format-Volume -FileSystem NTFS -NewFileSystemLabel $newFileSystemLabel

Write-Host "Done!" -BackgroundColor Green
# End of Script