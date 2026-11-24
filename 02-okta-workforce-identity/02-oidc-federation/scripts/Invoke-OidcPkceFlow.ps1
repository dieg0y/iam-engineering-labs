$Issuer   = "https://integrator-6023165.okta.com/oauth2/EnterprisePortalAuthServer"
$ClientId = "0oa1a98u39gytCccL698"
$Redirect = "http://localhost:8080/login/callback"

# 1. Generar code_verifier y code_challenge (S256)
$Bytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($Bytes)
$CodeVerifier = [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+','-').Replace('/','_')

$Sha256 = [System.Security.Cryptography.SHA256]::Create()
$HashBytes = $Sha256.ComputeHash([System.Text.Encoding]::ASCII.GetBytes($CodeVerifier))
$CodeChallenge = [Convert]::ToBase64String($HashBytes).TrimEnd('=').Replace('+','-').Replace('/','_')

$State = [guid]::NewGuid().ToString("N")
$Nonce = [guid]::NewGuid().ToString("N")

$AuthUrl = "$Issuer/v1/authorize?client_id=$ClientId&response_type=code&scope=openid%20profile%20email%20reports:read&redirect_uri=$([uri]::EscapeDataString($Redirect))&state=$State&nonce=$Nonce&code_challenge_method=S256&code_challenge=$CodeChallenge"

# 2. Iniciar listener local para capturar el callback al instante
$Listener = New-Object System.Net.HttpListener
$Listener.Prefixes.Add("http://localhost:8080/login/callback/")
$Listener.Start()

Set-Clipboard -Value $AuthUrl
Write-Host "`n[+] URL copiada al portapapeles. Pegala en una ventana de incognito:" -ForegroundColor Green
Write-Host $AuthUrl -ForegroundColor Yellow
Write-Host "`n[*] Esperando redireccion de Okta en localhost:8080..." -ForegroundColor Cyan

$Context = $Listener.GetContext()
$AuthCode = $Context.Request.QueryString["code"]

$Html = [System.Text.Encoding]::UTF8.GetBytes("<h2>Autorizacion completada. Ya puedes volver a PowerShell.</h2>")
$Context.Response.ContentLength64 = $Html.Length
$Context.Response.OutputStream.Write($Html, 0, $Html.Length)
$Context.Response.Close()
$Listener.Stop()

# 3. Canjear el code inmediatamente por los tokens JWT
try {
    $TokenResponse = Invoke-RestMethod -Method Post -Uri "$Issuer/v1/token" -ContentType "application/x-www-form-urlencoded" -Body @{
        grant_type    = "authorization_code"
        client_id     = $ClientId
        redirect_uri  = $Redirect
        code          = $AuthCode
        code_verifier = $CodeVerifier
    }
} catch {
    $Reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    Write-Host "Detalle exacto de Okta: $($Reader.ReadToEnd())" -ForegroundColor Red
    throw
}

function Decode-JwtPayload($jwt) {
    $part = $jwt.Split('.')[1].Replace('-','+').Replace('_','/')
    while ($part.Length % 4 -ne 0) { $part += '=' }
    [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($part)) | ConvertFrom-Json
}

$IdPayload     = Decode-JwtPayload $TokenResponse.id_token
$AccessPayload = Decode-JwtPayload $TokenResponse.access_token

Write-Host "`n=== DECODED ID TOKEN ===" -ForegroundColor Green
$IdPayload | ConvertTo-Json -Depth 5

Write-Host "`n=== DECODED ACCESS TOKEN ===" -ForegroundColor Cyan
$AccessPayload | ConvertTo-Json -Depth 5