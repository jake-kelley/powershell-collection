# PowerShell Collection

A collection of PowerShell scripts for Windows system administration, automation, and maintenance tasks.

## 📋 Scripts

| Script | Description |
|--------|-------------|
| `check-crashes.ps1` | Check system for crashes and bluescreens |
| `check-crashes-v1.ps1` | Check system for crashes (alternate version) |
| `Create-LocalUsersFromCSV/` | Create local users from input CSV file |
| `Disable-InactiveAccounts/` | Disable domain and local accounts based on days inactive |
| `Generate-Baseline.ps1` | Generate hardware/software inventory baseline of system |
| `Get-LastLocalLogonDate.ps1` | List last logon of local users |
| `Install-MSU.ps1` | Chain install .msu files provided |
| `Partition-New-Disk.ps1` | Auto-partition a new disk drive |
| `Promote-Domain-Controller.ps1` | Promote server to domain controller |
| `Remove-Bloatware.ps1` | Remove Windows 10 bloatware |
| `Upgrade-20H2.ps1` | Upgrade Windows 10 to version 20H2 |
| `weekly-standalone-audit-v1.4.ps1` | Windows Event Log XML parsing to HTML output auditing |

## 📁 Repository Structure

```
powershell-collection/
├── Create-LocalUsersFromCSV/
│   ├── Create-LocalUsersFromCSV.ps1
│   └── users.csv
├── Disable-InactiveAccounts/
│   ├── Disable-InactiveAccountsDOM.ps1
│   └── Disable-InactiveAccountsMUSA.ps1
└── *.ps1
```

## ⚠️ Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Administrative privileges for most scripts
- Appropriate permissions for domain-related operations

## 📄 License

This repository is for personal and professional use. Use at your own risk.
