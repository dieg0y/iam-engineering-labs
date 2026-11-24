# 1. Configura tu Sign on URL del Paso 2 y la ruta del certificado descargado:
$IdpSsoUrl = "https://integrator-6023165.okta.com/app/integrator-6023165_corpsaasportalsaml_1/exk1a9b3cswRfuMFp698/sso/saml"
$CertPath  = "$HOME\Desktop\okta.cert"   
$AcsUrl    = "http://localhost:8443/saml/acs"
$EntityId  = "https://sp.corp-iam.lab/saml/metadata"

# 2. Construir el AuthnRequest SAML 2.0 (SP-Initiated)
$RequestId = "_" + [guid]::NewGuid().ToString("N")
$IssueInstant = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$AuthnRequestXml = @"
<samlp:AuthnRequest xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
                    xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
                    ID="$RequestId"
                    Version="2.0"
                    IssueInstant="$IssueInstant"
                    Destination="$IdpSsoUrl"
                    ProtocolBinding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
                    AssertionConsumerServiceURL="$AcsUrl">
    <saml:Issuer>$EntityId</saml:Issuer>
    <samlp:NameIDPolicy Format="urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress" AllowCreate="true"/>
</samlp:AuthnRequest>
"@

# 3. Comprimir (Raw Deflate) + Base64 + URL-Encode para HTTP-Redirect Binding
$RawBytes = [System.Text.Encoding]::UTF8.GetBytes($AuthnRequestXml)
$Ms = New-Object System.IO.MemoryStream
$Deflate = New-Object System.IO.Compression.DeflateStream($Ms, [System.IO.Compression.CompressionMode]::Compress, $true)
$Deflate.Write($RawBytes, 0, $RawBytes.Length)
$Deflate.Close()
$EncodedRequest = [uri]::EscapeDataString([Convert]::ToBase64String($Ms.ToArray()))

$SpInitiatedUrl = "$IdpSsoUrl`?SAMLRequest=$EncodedRequest"

# 4. Iniciar listener ACS local en puerto 8443
$Listener = New-Object System.Net.HttpListener
$Listener.Prefixes.Add("http://localhost:8443/saml/acs/")
$Listener.Start()

Set-Clipboard -Value $SpInitiatedUrl
Write-Host "`n[+] AuthnRequest ID generado: $RequestId" -ForegroundColor Cyan
Write-Host "[+] URL SP-Initiated copiada al portapapeles. Pegala en ventana de incognito:" -ForegroundColor Green
Write-Host $SpInitiatedUrl -ForegroundColor Yellow
Write-Host "`n[*] Esperando HTTP POST SAMLResponse en $AcsUrl..." -ForegroundColor Cyan

$Context = $Listener.GetContext()
$Reader = New-Object System.IO.StreamReader($Context.Request.InputStream, $Context.Request.ContentEncoding)
$FormBody = $Reader.ReadToEnd()

$HtmlOk = [System.Text.Encoding]::UTF8.GetBytes("<h2>SAMLResponse recibido y validado por el SP. Vuelve a PowerShell.</h2>")
$Context.Response.ContentLength64 = $HtmlOk.Length
$Context.Response.OutputStream.Write($HtmlOk, 0, $HtmlOk.Length)
$Context.Response.Close()
$Listener.Stop()

# 5. Extraer y decodificar SAMLResponse
Add-Type -AssemblyName System.Web
$ParsedForm = [System.Web.HttpUtility]::ParseQueryString($FormBody)
$SamlResponseB64 = $ParsedForm["SAMLResponse"]
$SamlXmlString = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($SamlResponseB64))

[xml]$XmlDoc = $SamlXmlString
$XmlDoc.PreserveWhitespace = $true

# 6. Validar Firma XML X.509, Audience e InResponseTo
Add-Type -AssemblyName System.Security
$Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath)
$SignedXml = New-Object System.Security.Cryptography.Xml.SignedXml($XmlDoc)
$SigNode = $XmlDoc.GetElementsByTagName("Signature", "http://www.w3.org/2000/09/xmldsig#")[0]
$SignedXml.LoadXml($SigNode)
$IsSigValid = $SignedXml.CheckSignature($Cert, $true)

$RespInResponseTo = $XmlDoc.DocumentElement.GetAttribute("InResponseTo")
$AudienceValue    = $XmlDoc.GetElementsByTagName("Audience", "urn:oasis:names:tc:SAML:2.0:assertion")[0].InnerText
$NameIdValue      = $XmlDoc.GetElementsByTagName("NameID", "urn:oasis:names:tc:SAML:2.0:assertion")[0].InnerText

Write-Host "`n=== VALIDACION DEL SERVICE PROVIDER (SP) ===" -ForegroundColor Green
Write-Host "X.509 Signature Valid : $IsSigValid"
Write-Host "InResponseTo Match    : $($RespInResponseTo -eq $RequestId) ($RespInResponseTo)"
Write-Host "Audience Match        : $($AudienceValue -eq $EntityId) ($AudienceValue)"
Write-Host "Authenticated Subject : $NameIdValue"

Write-Host "`n=== ATTRIBUTE STATEMENTS RECIBIDOS ===" -ForegroundColor Cyan
foreach ($attr in $XmlDoc.GetElementsByTagName("Attribute", "urn:oasis:names:tc:SAML:2.0:assertion")) {
    $vals = ($attr.AttributeValue | ForEach-Object { $_.InnerText }) -join ", "
    Write-Host ("{0,-15} : {1}" -f $attr.GetAttribute("Name"), $vals)
}

# Guardar XML formateado (UTF-8 sin BOM) en el Escritorio
$Sw = New-Object System.IO.StringWriter
$Xw = New-Object System.Xml.XmlTextWriter($Sw)
$Xw.Formatting = [System.Xml.Formatting]::Indented
$XmlDoc.Save($Xw)
[System.IO.File]::WriteAllText("$HOME\Desktop\saml-assertion-sanitized.xml", ($Sw.ToString() + "`n"), (New-Object System.Text.UTF8Encoding $false))
Write-Host "`n[+] Asercion XML guardada en Escritorio: saml-assertion-sanitized.xml" -ForegroundColor Green