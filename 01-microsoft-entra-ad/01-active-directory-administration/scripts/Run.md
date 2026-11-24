# Execution Guide — Lab 01 Automation Scripts

## Prerequisites
* Windows Server 2022 promoted to Domain Controller (`DC01`) for forest `corp.iamlab.local`.
* Routable UPN suffix (`DiegoYonoffLab.onmicrosoft.com`) registered in **Active Directory Domains and Trusts**.
* `users-sample.csv` placed in `C:\IAM-Lab\users-sample.csv`.

## Step 1: Allow PowerShell Script Execution (Current Session Only)
Open **PowerShell as Administrator** on `DC01` and run:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

## Step 2: Configure Domain Account Lockout Policy (Brute-Force Defense)
```powershell
Set-ADDefaultDomainPasswordPolicy -Identity "corp.iamlab.local" `
    -LockoutThreshold 5 `
    -LockoutDuration (New-TimeSpan -Minutes 15) `
    -LockoutObservationWindow (New-TimeSpan -Minutes 15)
```

## Step 3: Run the Idempotent AD Provisioning Script
```powershell
C:\IAM-Lab\New-ADStructureAndUsers.ps1
```

## Step 4: Verify Created OUs, AGDLP Groups & Users
```powershell
Get-ADOrganizationalUnit -Filter * -SearchBase "DC=corp,DC=iamlab,DC=local" -SearchScope OneLevel | Select-Object Name
Get-ADUser -Filter * -SearchBase "OU=Corp_Users,DC=corp,DC=iamlab,DC=local" | Select-Object Name, UserPrincipalName, Enabled
Get-ADGroupMember -Identity "DL_AppAccess_Engineering" | Select-Object Name, ObjectClass
```
