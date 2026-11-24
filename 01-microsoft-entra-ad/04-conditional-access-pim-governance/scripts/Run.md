# Execution Guide — Lab 04 Conditional Access Policy-as-Code Export

## Prerequisites
* `Microsoft.Graph.Identity.SignIns` module installed.
* Conditional Access policy `CA01 - Block Legacy Authentication` configured in Microsoft Entra ID.

## Step 1: Run the Policy Export Script
Open **PowerShell** and execute:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
C:\IAM-Lab-04\scripts\Export-ConditionalAccessPolicies.ps1
```

## Step 2: Inspect the Exported JSON Artifact
```powershell
Get-Content "C:\IAM-Lab-04\policies\ca-block-legacy-auth.json"
```
