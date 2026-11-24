Import-Module Microsoft.Graph.Identity.SignIns

Write-Host "=== Connecting to Microsoft Graph (Policy.Read.All) ===" -ForegroundColor Cyan
Connect-MgGraph -Scopes "Policy.Read.All" -NoWelcome

$OutputDir = "C:\IAM-Lab-04\policies"
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$Policy = Get-MgIdentityConditionalAccessPolicy -Filter "displayName eq 'CA01 - Block Legacy Authentication'"
if (-not $Policy) {
    Write-Error "Conditional Access policy 'CA01 - Block Legacy Authentication' not found in this tenant."
    exit 1
}

$CleanJson = [ordered]@{
    displayName   = $Policy.DisplayName
    state         = $Policy.State
    conditions    = $Policy.Conditions
    grantControls = $Policy.GrantControls
} | ConvertTo-Json -Depth 10

$OutFile = Join-Path $OutputDir "ca-block-legacy-auth.json"
$CleanJson | Set-Content -Path $OutFile -Encoding UTF8
Write-Host "[+] Exported declarative policy artifact to: $OutFile" -ForegroundColor Green
