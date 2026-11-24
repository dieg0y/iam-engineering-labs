$ExpectedToken = "scim-lab-secret-token-2026"
$UsersStore    = @{}
$GroupsStore   = @{}

$Listener = New-Object System.Net.HttpListener
$Listener.Prefixes.Add("http://127.0.0.1:8090/")
$Listener.Start()

Write-Host "[+] Servidor SCIM 2.0 escuchando en http://127.0.0.1:8090/scim/v2" -ForegroundColor Green

function Send-Json($Response, $StatusCode, $Obj) {
    $Response.StatusCode = $StatusCode
    $Response.ContentType = "application/scim+json; charset=utf-8"
    $Json = $Obj | ConvertTo-Json -Depth 10 -Compress
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Json)
    $Response.ContentLength64 = $Bytes.Length
    $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
    $Response.Close()
}

while ($Listener.IsListening) {
    $Ctx  = $Listener.GetContext()
    $Req  = $Ctx.Request
    $Res  = $Ctx.Response
    $Path = $Req.Url.AbsolutePath.TrimEnd('/')
    $Method = $Req.HttpMethod
    $RawQuery = [System.Uri]::UnescapeDataString($Req.Url.Query)

    $Auth = $Req.Headers["Authorization"]
    if ($Auth -ne "Bearer $ExpectedToken") {
        Send-Json $Res 401 @{ schemas = @("urn:ietf:params:scim:api:messages:2.0:Error"); status = "401"; detail = "Invalid Bearer Token" }
        continue
    }

    $BodyText = ""
    if ($Req.HasEntityBody) {
        $Reader = New-Object System.IO.StreamReader($Req.InputStream, $Req.ContentEncoding)
        $BodyText = $Reader.ReadToEnd()
    }

    Write-Host "`n[$Method] $Path $RawQuery" -ForegroundColor Yellow

    if ($Method -eq "GET" -and $Path -eq "/scim/v2/Users") {
        $Matched = @()
        if ($RawQuery -match 'userName eq "([^"]+)"') {
            $TargetUser = $Matches[1]
            $Matched = @($UsersStore.Values | Where-Object { $_.userName -eq $TargetUser })
        } else {
            $Matched = @($UsersStore.Values)
        }
        Send-Json $Res 200 @{
            schemas      = @("urn:ietf:params:scim:api:messages:2.0:ListResponse")
            totalResults = $Matched.Count
            startIndex   = 1
            itemsPerPage = $Matched.Count
            Resources    = $Matched
        }
    }
    elseif ($Method -eq "POST" -and $Path -eq "/scim/v2/Users") {
        $Payload = $BodyText | ConvertFrom-Json
        $NewId = "scim-usr-" + (Get-Random -Minimum 1000 -Maximum 9999)
        $Payload | Add-Member -NotePropertyName "id" -NotePropertyValue $NewId -Force
        $UsersStore[$NewId] = $Payload

        $PrettyJson = $Payload | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText("$HOME\Desktop\scim-create-user-post.json", ($PrettyJson + "`n"), (New-Object System.Text.UTF8Encoding $false))
        Write-Host "[+] Usuario SCIM creado ($($Payload.userName) -> $NewId). Guardado en Desktop\scim-create-user-post.json" -ForegroundColor Green

        Send-Json $Res 201 $Payload
    }
    elseif ($Method -eq "PATCH" -and $Path -match "^/scim/v2/Users/([^/]+)$") {
        $UsrId = $Matches[1]
        $PatchObj = $BodyText | ConvertFrom-Json
        $PrettyPatch = $PatchObj | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText("$HOME\Desktop\scim-deactivate-user-patch.json", ($PrettyPatch + "`n"), (New-Object System.Text.UTF8Encoding $false))
        Write-Host "[!] PATCH recibido para $UsrId. Guardado en Desktop\scim-deactivate-user-patch.json" -ForegroundColor Magenta

        if ($UsersStore.ContainsKey($UsrId)) {
            foreach ($op in $PatchObj.Operations) {
                if ($op.path -eq "active") { $UsersStore[$UsrId].active = $op.value }
            }
            Send-Json $Res 200 $UsersStore[$UsrId]
        } else {
            Send-Json $Res 200 @{ schemas = @("urn:ietf:params:scim:schemas:core:2.0:User"); id = $UsrId; active = $false }
        }
    }
    elseif ($Method -eq "PUT" -and $Path -match "^/scim/v2/Users/([^/]+)$") {
        $UsrId = $Matches[1]
        $Payload = $BodyText | ConvertFrom-Json
        $Payload | Add-Member -NotePropertyName "id" -NotePropertyValue $UsrId -Force
        $UsersStore[$UsrId] = $Payload
        Send-Json $Res 200 $Payload
    }
    elseif ($Path -match "^/scim/v2/Groups") {
        if ($Method -eq "GET") {
            Send-Json $Res 200 @{ schemas = @("urn:ietf:params:scim:api:messages:2.0:ListResponse"); totalResults = 0; Resources = @() }
        } elseif ($Method -eq "POST") {
            $Grp = $BodyText | ConvertFrom-Json
            $GrpId = "scim-grp-" + (Get-Random -Minimum 100 -Maximum 999)
            $Grp | Add-Member -NotePropertyName "id" -NotePropertyValue $GrpId -Force
            $GroupsStore[$GrpId] = $Grp
            Write-Host "[+] Grupo SCIM sincronizado: $($Grp.displayName) ($GrpId)" -ForegroundColor Cyan
            Send-Json $Res 201 $Grp
        } else {
            Send-Json $Res 200 @{ schemas = @("urn:ietf:params:scim:schemas:core:2.0:Group"); id = "scim-grp-ok" }
        }
    }
    else {
        Send-Json $Res 404 @{ schemas = @("urn:ietf:params:scim:api:messages:2.0:Error"); status = "404"; detail = "Endpoint not found" }
    }
}