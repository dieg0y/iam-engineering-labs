# Execution Guide — Lab 02 Hybrid Sync Validation Script

## Prerequisites
* **Microsoft Entra Connect** installed and configured on `DC01` with **Password Hash Synchronization (PHS)**, **Seamless SSO**, `ms-DS-ConsistencyGuid` as Source Anchor, and OU filtering scoped to `OU=Corp_Users` and `OU=Corp_Groups`.
* Active Directory and `ADSync` PowerShell modules available on `DC01`.

## Step 1: Launch Entra Connect Wizard Without WAM Prompt Errors (If Reconfiguring)
```powershell
& "C:\Program Files\Microsoft Azure Active Directory Connect\AzureADConnect.exe" /InteractiveAuth
```

## Step 2: Audit On-Premises UPN Suffixes & Trigger Delta Sync
Open **PowerShell as Administrator** on `DC01` and run:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
C:\IAM-Lab\Invoke-HybridSyncValidation.ps1
```

## Step 3: Inspect Sync Connector Status Manually
```powershell
Get-ADSyncScheduler
Get-ADSyncConnectorRunStatus
```
