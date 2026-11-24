# Lab 02: OIDC Federation with PKCE & Custom Authorization Claims

## 1. Objective & Business Use Case
Implement federated Single Sign-On for a modern web application using **OpenID Connect (OIDC) Authorization Code Flow with PKCE (`S256`)**, eliminating static client secrets on public clients and injecting directory attributes (`department`, `groups`) into JWT Access Tokens via a Custom Authorization Server. The business outcome: a phishing-resistant SPA login (chained to the FIDO2 policy of Lab 01) plus audience-scoped bearer tokens that a backend API can authorize without a second round-trip to the identity store.

## 2. Architecture Diagram
```mermaid
sequenceDiagram
    participant App as Web / SPA Client
    participant Okta as Okta Custom Auth Server
    participant API as Protected Resource API

    Note over App: Generates code_verifier +<br/>code_challenge = BASE64URL(SHA256(verifier))
    App->>Okta: GET /authorize (response_type=code, code_challenge, S256, nonce)
    Okta->>Okta: Authenticates User + Evaluates Access Policy
    Okta-->>App: 302 Redirect with authorization_code
    App->>Okta: POST /token (code, code_verifier, client_id)
    Okta->>Okta: Verifies SHA256(code_verifier) == code_challenge
    Okta-->>App: Returns id_token + access_token (RS256)
    App->>API: GET /api/reports (Authorization: Bearer access_token)
    API->>Okta: Fetches /.well-known/jwks.json (Cached)
    API-->>App: 200 OK (Authorized via department & scp claims)
```

## 3. Implemented Configuration
* **OIDC Application (`Corp-Enterprise-Portal-SPA`):** Registered as a **Single-Page Application** with the **Authorization Code** grant and **PKCE (S256)** enforced as additional verification — no client secret exists to leak or rotate. Sign-in redirect URI `http://localhost:8080/login/callback`, access limited to the `GG_Dept_Engineering` group.
* **Custom Authorization Server (`Enterprise-Portal-AuthServer`, issuer `https://integrator-6023165.okta.com/oauth2/EnterprisePortalAuthServer`):**
  * **Audience (`aud`):** `api://enterprise-portal` to isolate tokens from other internal APIs and the Org issuer.
  * **Custom Scope:** `reports:read` mapped to the Authorization Server Access Policy.
  * **Custom Claims:** `department` (`user.department` via Okta Expression Language) and `groups` (`Matches regex: .*`) injected into the **Access Token** payload with `Always` inclusion.
  * **Access Policy `Portal-API-Access-Policy` (rule `Allow-Engineering-Reports-Scope`):** Authorization Code grant only, *User is assigned the app*, requested scopes `openid profile email reports:read`, and **Access token lifetime = 5 minutes** (`exp - iat = 300s`).
* **Directory prerequisite:** the test identity `cmendoza` carries `department = Engineering` in its Universal Directory profile so the expression-language claim resolves populated.

## 4. Automation & Protocol Inspection
The complete flow — PKCE parameter generation, `/authorize` launch, automatic callback capture, immediate code redemption, and local JWT base64url decoding — is automated in [`scripts/Invoke-OidcPkceFlow.ps1`](scripts/Invoke-OidcPkceFlow.ps1) (execution guide in [`scripts/Run.md`](scripts/Run.md)). The captured result is preserved in [`payloads/decoded-id-access-token.json`](payloads/decoded-id-access-token.json) and highlights critical protocol boundaries:
* **Token Separation:** `id_token` carries `aud = client_id` (`0oa1a98u39gytCccL698`) and the `nonce` for client-side authentication verification, whereas `access_token` carries `aud = api://enterprise-portal`, `scp`, `department`, and `groups` for backend authorization.
* **Short-Lived Access Token:** `exp - iat = 300 seconds` (5 minutes) limits exposure if a bearer token is intercepted.
* **Proof-of-Possession Context:** `amr = [pop]` and `auth_time` in the ID Token evidence the phishing-resistant factor chain inherited from Lab 01.

## 5. Troubleshooting (Real Issues Resolved)
| Issue Encountered | Root Cause | Diagnostic & Resolution |
| :--- | :--- | :--- |
| `400 Bad Request` on `/v1/authorize` (`redirect_uri` mismatch) | The PowerShell flow used `http://localhost:8080/callback` while the SPA application had registered Okta's SPA default `http://localhost:8080/login/callback`. Okta validates the redirect **character-by-character** against the whitelist. | Ruled out user assignment and Access Policy first (both correct), then inspected the app **General** tab and aligned `$Redirect` in the script to the exact registered URI. |
| `403 Access Forbidden (user_not_assigned)` after a successful login | The browser landed on `integrator-6023165-admin.okta.com` (the **Admin Console**) — `cmendoza` is a standard user with no admin role, so Okta refused console access. | Closed all incognito sessions to clear the cookie, and re-launched the flow against the plain tenant URL (`integrator-6023165.okta.com`, no `-admin`), confirming in the System Log that the sign-in itself had succeeded. |
| `400 Bad Request` on `/token` (`PKCE code_verifier is required`) | Client sent `code_challenge` during `/authorize` but omitted `code_verifier` in the token exchange POST body. | Added `code_verifier` to the `application/x-www-form-urlencoded` payload. |
| `invalid_request` against a wrong issuer on `/authorize` | Typo'd `$Issuer` in the PowerShell parameters (custom authorization server issuer must be exact). | Corrected `$Issuer` to `https://integrator-6023165.okta.com/oauth2/EnterprisePortalAuthServer`. |
| Authorization code expired before manual token exchange | Manual copy-paste of the `code` parameter took longer than the code's short validity window (~60s). | Automated the callback: an `HttpListener` on `localhost:8080/login/callback` captures the code and redeems it immediately ([`Invoke-OidcPkceFlow.ps1`](scripts/Invoke-OidcPkceFlow.ps1)). |
| Custom `department` claim appeared in `id_token` but was missing from `access_token` | Claim configuration defaulted to the `ID Token` type inside the Custom Authorization Server. | Edited the claim definition to target **Access Token** with inclusion set to `Always`. |

## 6. Security Controls Applied
* **PKCE (`S256`):** Prevents authorization code interception attacks on public clients without storing a client secret — the verifier proves the token requester is the same party that initiated the flow.
* **Strict Audience Validation:** Backend APIs reject tokens whose `aud` claim does not match `api://enterprise-portal`, so a token minted for the portal can never authorize against another internal API.
* **Replay Protection:** `nonce` (ID Token) and `jti` (access token) prevent token replay across sessions.
* **Least-Privilege App Access:** Application assignment limited to `GG_Dept_Engineering`, enforced again at the Authorization Server's Access Policy (`User is assigned the app`).

---

## 7. Hands-On Implementation & Visual Evidence Walkthrough

### Phase 1: Register the OIDC SPA Application with Mandatory PKCE
From **Applications -> Applications -> Create App Integration**, I selected **OIDC - OpenID Connect** with **Single-Page Application** as the application type:

![Creating the OIDC Single-Page App Integration in Okta](evidence/01-oidc-create-app-integration-spa.png)

General settings: app integration name `Corp-Enterprise-Portal-SPA`, **Authorization Code** grant with PKCE enforced for the public client, sign-in redirect URI `http://localhost:8080/login/callback` and sign-out URI `http://localhost:8080`:

![SPA general settings with Authorization Code grant and redirect URIs](evidence/02-oidc-spa-general-settings-redirect-uris.png)

Access was limited to the Engineering workforce group so only `GG_Dept_Engineering` members (such as `cmendoza`) can ever obtain tokens from this app:

![Limiting application access to the GG_Dept_Engineering group](evidence/03-oidc-spa-assignment-gg-dept-engineering.png)

After saving, the **General** tab exposed the public `Client ID` (`0oa1a98u39gytCccL698`) with no client secret — the SPA's credential-less posture:

![Application General tab showing Client ID with PKCE required and no client secret](evidence/04-oidc-spa-clientid-pkce-required.png)

### Phase 2: Custom Authorization Server, Scope, Claims & 5-Minute Access Policy
Under **Security -> API**, I created the Custom Authorization Server with **Audience `api://enterprise-portal`** (issuer `.../oauth2/EnterprisePortalAuthServer`), isolating portal tokens from the Org issuer and any other internal API:

![Custom Authorization Server settings with api://enterprise-portal audience](evidence/05-oidc-custom-auth-server-audience.png)

Then the custom scope `reports:read` (*Read enterprise reports*) included in public metadata:

![Creating the reports:read custom scope](evidence/06-oidc-custom-scope-reports-read.png)

Two custom claims were mapped into the **Access Token** with `Always` inclusion — `department` via the Okta Expression Language (`user.department`) and `groups` via a `Matches regex: .*` group filter. This is the classic pitfall: a claim left on the default `ID Token` type never reaches the backend API:

![Custom claims department and groups targeted at the Access Token](evidence/07-oidc-custom-claims-access-token.png)

The Access Policy `Portal-API-Access-Policy` (assigned to the SPA client) with rule `Allow-Engineering-Reports-Scope` — **Authorization Code** grant only, *User is assigned the app*, requested scopes `openid profile email reports:read`:

![Access Policy rule allowing the Engineering scopes for the SPA client](evidence/08-oidc-authserver-policy-rule-scopes.png)

The rule's THEN block sets the **Access token lifetime to 5 minutes**, which is exactly the `exp - iat = 300` seconds observable in the captured JWT:

![Access Policy rule with 5-minute access token lifetime](evidence/09-oidc-authserver-policy-rule-token-lifetime.png)

### Phase 3: Executing the Real PKCE Flow from PowerShell
*(Prerequisite: `cmendoza`'s profile carries `department = Engineering` under **Directory -> People -> Profile**, so the expression claim resolves.)*

I executed the PKCE parameter generator: a cryptographically random 32-byte `code_verifier`, its SHA-256 `code_challenge` (Base64URL), plus `state` (CSRF) and `nonce` (replay) values, with the `/authorize` URL copied to the clipboard for an incognito window:

![PowerShell generating the PKCE code_verifier, code_challenge, state and nonce](evidence/10-oidc-powershell-pkce-parameters-generated.png)

The first `/authorize` attempt failed with `400 Bad Request` — the `redirect_uri` did not match the registered whitelist:

![400 Bad Request error on /authorize due to redirect_uri mismatch](evidence/11-oidc-error-400-redirect-uri-mismatch.png)

Debugging it methodically, I first ruled out **user assignment** (the app's People tab confirmed `cmendoza` via `GG_Dept_Engineering`):

![Verifying cmendoza assignment under the application's People tab](evidence/12-oidc-app-assignment-cmendoza-verified.png)

Then the **Authorization Server Access Policy** (active, correct grant types and scopes):

![Verifying the Authorization Server Access Policy is active](evidence/13-oidc-authserver-access-policy-verified.png)

The System Log revealed what actually happened: the user *had* authenticated successfully, but the browser then attempted to open the **Admin Console** (`-admin` subdomain), which a standard user cannot access (`403 user_not_assigned`):

![System Log showing successful auth followed by denied Admin Console access](evidence/14-oidc-system-log-admin-access-denied.png)

Following the admin link had surfaced that 403 page directly in the browser:

![403 Access Forbidden when the standard user hit the Admin Console URL](evidence/15-oidc-admin-console-403-user-not-assigned.png)

After eliminating assignment and policy, the real culprit surfaced in the app's **General** tab — the registered redirect URI was Okta's SPA default `http://localhost:8080/login/callback`, not the `/callback` path the script was sending:

![Discovering the registered redirect URI differs from the script parameter](evidence/16-oidc-redirect-uri-mismatch-found.png)

The script's `$Redirect` was still pointing at the wrong path:

![PowerShell showing the mismatched redirect parameter](evidence/17-oidc-powershell-wrong-redirect-uri.png)

The fix was a single-line alignment of `$Redirect` to the exact registered URI:

![PowerShell corrected to the exact registered redirect URI](evidence/18-oidc-powershell-redirect-uri-corrected.png)

The next run produced a different — and self-inflicted — failure: a typo'd `$Issuer` (the custom authorization server's issuer must match character-for-character):

![Invalid issuer error from the mistyped authorization server URL](evidence/19-oidc-error-invalid-issuer.png)

I corrected the issuer parameter to `https://integrator-6023165.okta.com/oauth2/EnterprisePortalAuthServer`:

![Correcting the Issuer parameter in PowerShell](evidence/20-oidc-powershell-issuer-uri-corrected.png)

Re-running the script regenerated a clean `/authorize` URL (fresh `code_challenge`, `state`, `nonce`):

![Regenerated authorize URL with fresh PKCE parameters](evidence/21-oidc-powershell-authorize-url-regenerated.png)

The incognito browser then landed on the tenant's real sign-in page with the test identity:

![Okta sign-in page reached in the incognito browser](evidence/22-oidc-okta-signin-page-cmendoza.png)

Okta then presented the security method selection — and the only compliant option for the policy is the **passkey** (the phishing-resistant factor inherited from Lab 01):

![Selecting the passkey security method for the verification challenge](evidence/23-oidc-passkey-method-selection.png)

The browser redirected to the local callback with `code=...&state=...` (localhost refusing the connection is expected — the code lives in the URL):

![Authorization code captured in the localhost callback URL](evidence/24-oidc-authorization-code-captured-callback.png)

### Phase 4: Token Redemption & JWT Claim Verification
Because a hand-copied code risks expiring mid-exchange, the final run used [`Invoke-OidcPkceFlow.ps1`](scripts/Invoke-OidcPkceFlow.ps1): an `HttpListener` captures the callback automatically and redeems the code *immediately*, then decodes both JWT payloads locally. The decoded **Access Token** printed in the console confirms `aud = api://enterprise-portal`, `scp` containing `reports:read`, `department = Engineering`, `groups` containing `GG_Dept_Engineering`, `sub = cmendoza@corp-iam.lab`, and `exp - iat = 300` seconds — exactly the claims a backend API would authorize against:

![Decoded Access Token payload in the PowerShell console: audience, scopes, department and groups](evidence/25-oidc-decoded-access-token-console.png)

The decoded token pair (ID Token with its client `aud` and matching `nonce`, Access Token with the API audience and custom claims) was then persisted as the JSON evidence artifact ([`payloads/decoded-id-access-token.json`](payloads/decoded-id-access-token.json)):

![Saving the decoded token pair as the JSON evidence artifact](evidence/26-oidc-token-artifact-saved-desktop.png)
