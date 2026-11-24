# Execution Guide — Lab 03 Microsoft Graph JML Automation

## Prerequisites
* Windows PowerShell 5.1+ or PowerShell 7+ on an administrative workstation with modern browser access.
* Global Administrator or User Administrator + Groups Administrator privileges in `DiegoYonoffLab.onmicrosoft.com`.
* Direct security group `SG-Direct-VPN-Access` and dynamic groups (`Dyn-Dept-Finance`, `Dyn-Dept-Engineering`) pre-created in Entra ID.

## Step 1: Prepare TLS 1.2 & Install Required Microsoft Graph Modules
Open **PowerShell as Administrator** and run:
```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted

Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Groups, Microsoft.Graph.Identity.SignIns -Scope CurrentUser -Force -AllowClobber
```

## Step 2: Verify Installed Graph Modules
```powershell
Get-Module -ListAvailable Microsoft.Graph.* | Select-Object Name, Version
```

## Step 3: Execute the Joiner-Mover-Leaver Lifecycle Script
Open a fresh PowerShell session and run:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
C:\IAM-Lab-03\Invoke-EntraJML.ps1
```
*(Note: If running from a headless or legacy VM browser, authenticate using `Connect-MgGraph -UseDeviceCode -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Directory.ReadWrite.All"`).*
