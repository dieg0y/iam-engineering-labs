# Execution Guide — Lab 02 OIDC Authorization Code + PKCE Flow

## Prerequisites
* Okta tenant with the `Corp-Enterprise-Portal-SPA` application registered (Authorization Code grant, PKCE enforced, redirect `http://localhost:8080/login/callback`).
* Custom Authorization Server with audience `api://enterprise-portal`, scope `reports:read`, claims `department` / `groups` on the **Access Token**, and an Access Policy rule with a **5-minute** access token lifetime.
* Test user `cmendoza@corp-iam.lab` assigned to `GG_Dept_Engineering`, profile attribute `department = Engineering`, and a **FIDO2 passkey enrolled** (Lab 01).
* Windows PowerShell 5.1+ (no additional modules required — the script uses `System.Security.Cryptography` and `HttpListener` natively).

## Step 1: Configure the Flow Parameters
Edit the first lines of [`Invoke-OidcPkceFlow.ps1`](Invoke-OidcPkceFlow.ps1) only if your tenant/app differ from the lab defaults:
```powershell
$Issuer   = "https://integrator-6023165.okta.com/oauth2/EnterprisePortalAuthServer"
$ClientId = "0oa1a98u39gytCccL698"
$Redirect = "http://localhost:8080/login/callback"
```

## Step 2: Run the Automated PKCE Flow
Open **PowerShell** and execute:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
C:\IAM-Lab-02-Okta\scripts\Invoke-OidcPkceFlow.ps1
```
The script:
1. Generates the 32-byte random `code_verifier` and its SHA-256 `code_challenge` (Base64URL).
2. Builds the `/authorize` URL (`response_type=code`, `code_challenge_method=S256`, `state`, `nonce`) and copies it to the clipboard.
3. Starts an `HttpListener` on `http://localhost:8080/login/callback/` to capture the authorization code the instant Okta redirects.
4. Redeems the code at `/v1/token` (immediate exchange — no manual copy that could expire) and decodes both JWT payloads.

Paste the generated URL into an **incognito** window and authenticate with the FIDO2 passkey; the listener captures the code and the console prints the decoded tokens.

## Step 3: Verify the Decoded Claims
Confirm in the console output (or in [`../payloads/decoded-id-access-token.json`](../payloads/decoded-id-access-token.json)):
* **ID Token:** `"aud": "0oa1a98u39gytCccL698"` (the client) and `"nonce"` matching the request; `"amr": ["pop"]` evidencing the possession factor.
* **Access Token:** `"aud": "api://enterprise-portal"`, `"scp"` containing `reports:read`, `"department": "Engineering"`, `"groups"` containing `GG_Dept_Engineering`.
* **Lifetime:** `"exp" - "iat" = 300` seconds (5 minutes).
