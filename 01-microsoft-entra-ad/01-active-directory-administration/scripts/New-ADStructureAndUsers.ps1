Import-Module ActiveDirectory

function New-RandomComplexPassword {
    param([int]$Length = 16)
    $Upper = "ABCDEFGHJKLMNPQRSTUVWXYZ".ToCharArray()
    $Lower = "abcdefghijkmnpqrstuvwxyz".ToCharArray()
    $Digits = "23456789".ToCharArray()
    $Symbols = "!@#$%&*?".ToCharArray()
    $All = $Upper + $Lower + $Digits + $Symbols
    $Password = @(
        ($Upper | Get-Random),
        ($Lower | Get-Random),
        ($Digits | Get-Random),
        ($Symbols | Get-Random)
    ) + (1..($Length - 4) | ForEach-Object { $All | Get-Random })
    -join ($Password | Sort-Object { Get-Random })
}

$DomainDN = "DC=corp,DC=iamlab,DC=local"
$UpnSuffix = "DiegoYonoffLab.onmicrosoft.com"

$OUs = @("Corp_Users", "Corp_Groups", "Tier0_Admins", "Disabled_Accounts")
foreach ($OU in $OUs) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$OU'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $OU -Path $DomainDN -ProtectedFromAccidentalDeletion $true
    }
}

$Departments = @("Engineering", "Finance", "IT", "HR")
foreach ($Dept in $Departments) {
    $GG = "GG_Dept_$Dept"
    $DL = "DL_AppAccess_$Dept"
    if (-not (Get-ADGroup -Filter "Name -eq '$GG'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $GG -GroupScope Global -GroupCategory Security -Path "OU=Corp_Groups,$DomainDN"
    }
    if (-not (Get-ADGroup -Filter "Name -eq '$DL'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $DL -GroupScope DomainLocal -GroupCategory Security -Path "OU=Corp_Groups,$DomainDN"
    }
    Add-ADGroupMember -Identity $DL -Members $GG -ErrorAction SilentlyContinue
}

$Users = Import-Csv "C:\IAM-Lab\users-sample.csv"
foreach ($User in $Users) {
    $FullName = "$($User.FirstName) $($User.LastName)"
    $UPN = "$($User.SamAccountName)@$UpnSuffix"
    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($User.SamAccountName)'" -ErrorAction SilentlyContinue)) {
        $SecurePwd = ConvertTo-SecureString (New-RandomComplexPassword -Length 16) -AsPlainText -Force
        New-ADUser -Name $FullName -GivenName $User.FirstName -Surname $User.LastName `
            -SamAccountName $User.SamAccountName -UserPrincipalName $UPN `
            -Department $User.Department -Title $User.JobTitle `
            -Path "OU=Corp_Users,$DomainDN" -AccountPassword $SecurePwd `
            -Enabled $true -ChangePasswordAtLogon $true
        Add-ADGroupMember -Identity "GG_Dept_$($User.Department)" -Members $User.SamAccountName
    }
}