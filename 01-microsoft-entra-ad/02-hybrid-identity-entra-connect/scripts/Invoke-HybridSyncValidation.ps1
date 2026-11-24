Import-Module ActiveDirectory
Import-Module ADSync

$SearchBase = "OU=Corp_Users,DC=corp,DC=iamlab,DC=local"
$ExpectedDomain = "DiegoYonoffLab.onmicrosoft.com"

Write-Host "=== Auditing On-Premises UPN Suffixes Before Entra Connect Delta Sync ===" -ForegroundColor Cyan
$Users = Get-ADUser -Filter * -SearchBase $SearchBase -Properties UserPrincipalName, Department
$Mismatches = @()

foreach ($User in $Users) {
    if ($User.UserPrincipalName -notlike "*@$ExpectedDomain") {
        Write-Warning "[!] UPN Mismatch: $($User.SamAccountName) -> $($User.UserPrincipalName)"
        $Mismatches += $User
    } else {
        Write-Host "[OK] $($User.UserPrincipalName) ($($User.Department))" -ForegroundColor Green
    }
}

if ($Mismatches.Count -eq 0) {
    Write-Host "`nAll synced-scope users match $ExpectedDomain. Triggering Delta Sync..." -ForegroundColor Cyan
    Start-ADSyncSyncCycle -PolicyType Delta
} else {
    Write-Error "Aborting sync: $($Mismatches.Count) user(s) have unverified UPN suffixes."
}
