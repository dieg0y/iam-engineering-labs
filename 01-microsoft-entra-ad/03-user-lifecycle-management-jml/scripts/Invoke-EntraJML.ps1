Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Groups
Import-Module Microsoft.Graph.Identity.SignIns

$TenantDomain = "DiegoYonoffLab.onmicrosoft.com"
$TestUPN = "camila.jml@$TenantDomain"

Write-Host "=== Connecting to Microsoft Graph ===" -ForegroundColor Cyan
Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All", "Directory.ReadWrite.All" -NoWelcome

# Remove leftover test user from a previous run, if any
$Existing = Get-MgUser -Filter "userPrincipalName eq '$TestUPN'" -ErrorAction SilentlyContinue
if ($Existing) { Remove-MgUser -UserId $Existing.Id }

# 1. JOINER PHASE
Write-Host "`n[1/3] JOINER: Provisioning user with UsageLocation & forced password rotation..." -ForegroundColor Green
$PasswordProfile = @{
    Password = "JmlStart2026!#"
    ForceChangePasswordNextSignIn = $true
}

$User = New-MgUser `
    -DisplayName "Camila JML Test" `
    -UserPrincipalName $TestUPN `
    -MailNickname "camila.jml" `
    -UsageLocation "CO" `
    -Department "Finance" `
    -JobTitle "Financial Analyst" `
    -AccountEnabled:$true `
    -PasswordProfile $PasswordProfile

$DirectGroup = Get-MgGroup -Filter "displayName eq 'SG-Direct-VPN-Access'"
if ($DirectGroup) {
    New-MgGroupMember -GroupId $DirectGroup.Id -DirectoryObjectId $User.Id
}
Write-Host "[+] Created: $($User.UserPrincipalName) | UsageLocation: CO | Dept: Finance | Direct Group: SG-Direct-VPN-Access" -ForegroundColor Green
Start-Sleep -Seconds 5

# 2. MOVER PHASE
Write-Host "`n[2/3] MOVER: Updating Department (Finance -> Engineering) & JobTitle..." -ForegroundColor Yellow
Update-MgUser -UserId $User.Id -Department "Engineering" -JobTitle "Cloud IAM Engineer"
$Updated = Get-MgUser -UserId $User.Id -Property DisplayName, Department, JobTitle
Write-Host "[+] Updated: Dept = $($Updated.Department) | JobTitle = $($Updated.JobTitle)" -ForegroundColor Yellow
Start-Sleep -Seconds 5

# 3. LEAVER PHASE
Write-Host "`n[3/3] LEAVER: Disabling account, revoking refresh tokens & stripping direct groups..." -ForegroundColor Red
Update-MgUser -UserId $User.Id -AccountEnabled:$false
Revoke-MgUserSignInSession -UserId $User.Id | Out-Null

$Memberships = Get-MgUserMemberOf -UserId $User.Id
foreach ($Group in $Memberships) {
    if ($Group.AdditionalProperties["@odata.type"] -eq "#microsoft.graph.group" -and -not $Group.AdditionalProperties["groupTypes"]) {
        Remove-MgGroupMemberByRef -GroupId $Group.Id -DirectoryObjectId $User.Id
        Write-Host "[-] Removed from direct group: $($Group.AdditionalProperties['displayName'])" -ForegroundColor Red
    }
}
Write-Host "[+] Offboarding complete: AccountEnabled = False & Refresh Tokens invalidated." -ForegroundColor Red