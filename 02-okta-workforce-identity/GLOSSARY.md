# Workforce Identity & Federation — Technical & Real-World Glossary

A practical reference guide covering every core protocol, policy engine, acronym, and security control implemented across Labs 01–04 of the Okta Workforce Identity module. Each entry separates **exact architectural theory** from **real-world enterprise deployment scenarios**.

---

## 1. Adaptive Authentication & Network Perimeter (Lab 01)

### Acronym / Feature: Okta Network Zones (Dynamic vs. IP-based)
* **Theory:** Logical network boundaries defined in Okta that classify sign-in source IPs. **IP Zones** enumerate explicit CIDR ranges (corporate egress gateways), while **Dynamic Zones** are population-based categories (e.g., "Tor anonymizer proxy", "Anonymous proxy") that Okta maintains and updates continuously. Zones can be used in policies as conditions (`User's IP is in / not in zone`) or, for anonymizer zones, as hard tenant-gateway blocks.
* **Real-World Practice:** Used as the network perimeter for Zero Trust policy: in this lab, `BLOCK_Anonymizers` drops Tor traffic before any policy evaluation, while `CORP_Trusted_IPs` differentiates office vs. remote sessions — the Okta counterpart of Entra Named Locations from Module 01.

### Acronym / Feature: FIDO2 / WebAuthn / Passkeys
* **Theory:** An authentication standard where the browser asks a hardware or platform authenticator (Windows Hello, a security key, a phone) to sign a challenge with a private key that is *bound to the origin's domain* at registration. The assertion includes the SHA-256 hash of the Relying Party ID (`rpIdHash`), so a signature generated for `integrator-6023165.okta.com` is cryptographically unusable on any other domain.
* **Real-World Practice:** Deployed to defeat Adversary-in-the-Middle (AiTM) phishing proxies (Evilginx-style kits): even if a user types their password into a pixel-perfect phishing page, the passkey prompt refuses to sign the challenge because the origin doesn't match — the session can never be minted.

### Acronym / Feature: Okta FastPass
* **Theory:** Okta's native platform authenticator: a phishing-resistant factor combining device trust, proof-of-possession key material, and optional biometric/PIN user verification, installed via the Okta Verify app on desktop and mobile.
* **Real-World Practice:** Used in enterprises as the "free" hardware-grade factor at scale — no security keys to purchase, and the `Require device passcode or biometric user verification` constraint turns every login into proof that the *person with the device* is present, not just the device.

### Acronym / Feature: Authenticator Enrollment Policy vs. Authentication Policy (App Sign-On)
* **Theory:** The **Enrollment Policy** controls *which authenticators a user is allowed/required to register* (e.g., FIDO2 Optional). The **Authentication Policy** (App Sign-On) controls *what factors a sign-in must present* (e.g., Possession factor + Phishing-resistant constraint). They are separate planes: enrollment is about catalog, authentication is about enforcement.
* **Real-World Practice:** A classic enterprise pitfall is setting FIDO2 enrollment to *Required* before anyone owns a key — locking out the whole workforce. In this lab, enrollment stayed `Optional` while enforcement lived in the Authentication Policy, letting Okta trigger **just-in-time enrollment** at the first strict sign-in instead.

### Acronym / Feature: Phishing-Resistant Constraint (Possession Factor Constraints)
* **Theory:** A checkbox-level constraint on an Okta authentication rule that restricts the possession factor to methods resistant to interception and replay (FIDO2/WebAuthn, FastPass) — excluding OTP codes, SMS, and push, which are phishable and SIM-swappable.
* **Real-World Practice:** In the lab's `Enforce-FIDO2-Phishing-Resistant-Engineering` rule, the constraint stack was **Phishing resistant** + **Require device passcode or biometric verification** + methods limited to **Passkey (FIDO2 WebAuthn)** only — so no weaker fallback factor can ever satisfy the policy.

### Acronym / Feature: SIM Swapping (and why SMS/Voice get deactivated)
* **Theory:** An attack where the fraudster social-engineers a telecom provider into porting a victim's phone number to a new SIM, silently receiving their SMS one-time passwords and voice call verifications.
* **Real-World Practice:** Enterprises eliminate the vector by deactivating SMS and Voice authenticators from the tenant catalog entirely — in this lab, the **Phone** authenticator was deactivated under **Security -> Authenticators**, so no policy can ever regress to a phishable factor.

### Acronym / Feature: Break-Glass Accounts (Okta Edition)
* **Theory:** Dedicated emergency accounts excluded from restrictive authentication policies and holding the highest role (**Super Administrator**), protected by long high-entropy credentials and compensating monitoring. In Okta, the exclusion is implemented via group membership (`SG-BreakGlass-Exclude`) matched at **Priority 1** in the App Sign-On policy so the relaxed rule always wins evaluation order.
* **Real-World Practice:** The accepted trade-off when rolling out phishing-resistant rules tenant-wide: if a strict policy or a failed authenticator rollout blocks every admin, break-glass is the parachute — mirrored here from the Entra module's `breakglass1`/`breakglass2` pattern.

### Acronym / Feature: Rule Priority & First-Match Evaluation
* **Theory:** Okta authentication policy rules are evaluated in strict priority order; the **first rule whose conditions match** the sign-in context is the one applied — later rules never "add" to an earlier match.
* **Real-World Practice:** This is why ordering is a security control: with the break-glass rule at Priority 1 and the FIDO2 enforcement at Priority 2, an engineer in both groups still gets the relaxed emergency treatment; with the order reversed, the strict rule would match first and the emergency account could be locked out.

### Acronym / Feature: System Log (Okta Event Telemetry)
* **Theory:** The tenant-wide audit stream (`Reports -> System Log`) of authentication and administrative events — e.g., `user.session.start`, `user.authentication.auth_via_mfa`, `application.provision.user.deactivate` — each carrying actor, IP, factor, and client context.
* **Real-World Practice:** Used in this lab as the verification plane for every control: after enforcing passkey-only sign-in, the System Log event was expanded to confirm the factor actually used was WebAuthn and the source IP resolved inside the trusted zone — evidence, not assumption.

---

## 2. OIDC / OAuth 2.0 Federation (Lab 02)

### Acronym / Feature: OAuth 2.0 vs. OpenID Connect (OIDC)
* **Theory:** OAuth 2.0 is an **authorization** framework — issuing scoped access tokens so a client can act on a user's behalf. OpenID Connect is the **authentication** identity layer on top of it, adding the `id_token` (a signed JWT about who signed in), the `openid` scope, and the `/userinfo` endpoint.
* **Real-World Practice:** In enterprise apps the distinction matters on the wire: the SPA receives an `id_token` whose `aud` is *the client* (proof of who logged in), and an `access_token` whose `aud` is *the API* (proof of what the API may do) — one flow, two different audiences.

### Acronym / Feature: Authorization Code Flow + PKCE (S256)
* **Theory:** The browser is redirected to `/authorize`, authenticates, and receives a one-time `code` at the registered redirect URI; the client then redeems the code at `/token`. **PKCE** (Proof Key for Code Exchange) adds a per-request secret: the client generates a `code_verifier`, sends `SHA256(verifier)` as the `code_challenge`, and must present the original verifier at redemption — so an intercepted code is worthless.
* **Real-World Practice:** Mandatory for SPAs and mobile apps (public clients that cannot keep a secret); in this lab, S256 PKCE was enforced on `Corp-Enterprise-Portal-SPA`, eliminating static client secrets entirely and surviving the classic "authorization code interception" attack.

### Acronym / Feature: Public vs. Confidential Clients
* **Theory:** OAuth client classifications. A **confidential client** runs on a server and can hold a client secret; a **public client** (SPA, mobile, CLI) runs where the user can inspect memory, so any embedded secret is by definition exposed.
* **Real-World Practice:** The SPA registered in this lab has a **Client ID only** — the General tab shows no client secret — which is exactly why PKCE exists: proof of possession replaces the missing secret.

### Acronym / Feature: Custom Authorization Server (Audience Isolation)
* **Theory:** Okta's Org Authorization Server issues tokens whose audience is the org itself. A **Custom Authorization Server** (here `Enterprise-Portal-AuthServer`) mints tokens with its own issuer URL and a configured **audience** (`api://enterprise-portal`), its own scopes, claims, and access policies — a separate trust domain per API tier.
* **Real-World Practice:** Enterprises use one custom server per API product line so that a portal token is cryptographically useless against the payments API; the `aud` claim check at the resource server becomes a one-line hard boundary.

### Acronym / Feature: Scopes & Custom Scopes (`reports:read`)
* **Theory:** OAuth scopes are the permissions a client requests (`openid profile email` plus resource-specific ones like `reports:read`). In Okta, custom scopes live on the Custom Authorization Server, appear in the `.well-known` metadata, and land in the token's `scp` claim when granted by an Access Policy rule.
* **Real-World Practice:** The backend API gates endpoints on `scp` values — if the decoded access token lacks `reports:read`, the `/api/reports` route returns 403 before any business logic runs.

### Acronym / Feature: Custom Claims (`department`, `groups`) & Token-Type Targeting
* **Theory:** Okta claim definitions map directory data into tokens via the Okta Expression Language (`user.department`) or group filters (`Matches regex: .*`). The critical configuration is the **token type**: a claim left on the default `ID Token` never appears in the access token consumed by the API.
* **Real-World Practice:** This lab's subtlest bug: `department` showed up in `id_token` but the backend found nothing in `access_token` — the fix was editing the claim to target **Access Token** with inclusion `Always`, after which the captured token carries `"department": "Engineering"` and the `groups` array.

### Acronym / Feature: JWT Anatomy (`iss`, `sub`, `aud`, `exp`, `iat`, `jti`, `nonce`, `scp`, `amr`)
* **Theory:** A signed JWT carries registered claims: **iss** (issuer), **sub** (subject), **aud** (audience), **exp**/**iat** (expiry/issued-at), **jti** (unique token ID for replay detection), **nonce** (request-binding value in ID Tokens), plus OAuth's **scp** (granted scopes) and **amr** (authentication method references, e.g., `pop` = proof-of-possession).
* **Real-World Practice:** The captured artifact (`decoded-id-access-token.json`) shows both tokens' claims side by side — the ID Token `aud` equals the client ID with the matching `nonce`, and the access token `aud` equals `api://enterprise-portal` with `scp`, `department`, `groups`, and `exp - iat = 300` seconds.

### Acronym / Feature: Token Lifetime Engineering (300-Second Access Tokens)
* **Theory:** The Authorization Server's Access Policy rule sets the access token lifetime; a 5-minute token means a stolen bearer token has a 5-minute blast radius before natural expiry.
* **Real-World Practice:** Configured in the rule's THEN block (`Access token lifetime: 5 Minutes`) and *verified* in the decoded token (`exp - iat = 300`) — a policy knob confirmed on the wire rather than trusted from the console.

### Acronym / Feature: `redirect_uri` Character-Exact Matching
* **Theory:** The OAuth spec requires the redirect URI sent to `/authorize` to match a pre-registered URI exactly — scheme, host, port, path, and trailing slashes included. Okta validates character-by-character and answers mismatches with `400`.
* **Real-World Practice:** This lab's longest debugging session: a script using `http://localhost:8080/callback` against a registered `http://localhost:8080/login/callback` produced a 400 that masqueraded as an assignment/policy problem until the registered URI was inspected directly.

---

## 3. SAML 2.0 Enterprise Federation (Lab 03)

### Acronym / Feature: SP-Initiated vs. IdP-Initiated SSO
* **Theory:** In **SP-initiated** flow, the user hits the Service Provider first, which generates an `<samlp:AuthnRequest>` and redirects to the IdP; in **IdP-initiated** flow, the user starts at the IdP's app dashboard and an unsolicited assertion is POSTed to the SP.
* **Real-World Practice:** SP-initiated is the dominant enterprise pattern (bookmarks/links point at the app, not the IdP) and is safer: every assertion is correlated to a request. Unsolicited IdP-initiated assertions are what the `InResponseTo` check exists to reject.

### Acronym / Feature: `AuthnRequest` & HTTP-Redirect Binding (Deflate + Base64)
* **Theory:** The SP's authentication request is an XML document with a unique `ID` and `IssueInstant`. The **HTTP-Redirect binding** transports it inside the URL: XML → **Raw Deflate compression** → **Base64** → **URL-encoding** on the `SAMLRequest` query parameter.
* **Real-World Practice:** The lab's PowerShell SP simulator performs this encoding chain natively (including the deflate step most tutorials skip), which is why the generated login URL was accepted by the real Okta IdP.

### Acronym / Feature: ACS, Recipient, and Destination
* **Theory:** The **Assertion Consumer Service** URL is the SP endpoint that receives the `SAMLResponse` POST. The assertion's `SubjectConfirmationData.Recipient` and the response's `Destination` must equal the ACS exactly — they bind the message to the intended receiver.
* **Real-World Practice:** In the lab app config, the checkbox **Use this for Recipient URL and Destination URL** pinned all three to `http://localhost:8443/saml/acs`, eliminating the classic mismatch trio that produces "assertion did not satisfy immediate signing requirements" style failures.

### Acronym / Feature: Entity ID / Audience Restriction
* **Theory:** The SP's **Entity ID** (here `https://sp.corp-iam.lab/saml/metadata`) is its logical identifier — a URI that does not need to resolve. The assertion's `<saml2:AudienceRestriction>` must contain it exactly, otherwise the SP must reject the assertion: it was minted for someone else.
* **Real-World Practice:** Audience validation is what stops an assertion issued for `sp.corp-iam.lab` being replayed against a second SaaS app in the same tenant — each integration has its own audience string.

### Acronym / Feature: `NameID` & Formats
* **Theory:** The `<saml2:NameID>` element identifies the authenticated subject; its `Format` attribute declares the identifier type — `urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress`, persistent IDs, or entity IDs. The SP's policy maps the NameID to its local user table.
* **Real-World Practice:** EmailAddress format is the pragmatic enterprise default (JIT provisioning matches the login by email); stricter shops use persistent opaque IDs so an email change doesn't fork the identity — a trade-off this lab keeps visible in the captured assertion.

### Acronym / Feature: X.509 Signing, RSA-SHA256 & `xml-exc-c14n` (XSW Defense)
* **Theory:** The IdP signs the assertion (and optionally the response) with its private key; the SP verifies with the IdP's public **X.509 certificate** from metadata. The signature references the assertion with **exclusive canonicalization** (`xml-exc-c14n`) and `RSA-SHA256`; the digest reference is bound to one element, so a wrapper that relocates the original node cannot produce a matching digest.
* **Real-World Practice:** **XML Signature Wrapping (XSW)** is the classic SAML attack — this lab's simulator verified the signature with the downloaded Okta certificate and validated the reference, i.e., the exact controls that stop a wrapped-assertion forgery.

### Acronym / Feature: `InResponseTo` (Request Correlation)
* **Theory:** The response's `InResponseTo` attribute echoes the `ID` of the `AuthnRequest` that initiated the flow, binding the assertion to a specific session initiation. SPs track outstanding request IDs and reject responses that don't correspond to one.
* **Real-World Practice:** The captured assertion's `InResponseTo="_e4a400e9d22049c2811b9c6c744794c3"` matches the simulator-generated `AuthnRequest` ID — the control that defeats unsolicited assertion injection.

### Acronym / Feature: `NotBefore` / `NotOnOrAfter` (Clock Skew)
* **Theory:** The `<saml2:Conditions>` window bounds the assertion's validity, typically a five-minute interval. SPs allow a small skew tolerance for clock differences between IdP and SP.
* **Real-World Practice:** The classic production SAML outage: a container or VM whose clock drifts minutes out of NTP sync starts rejecting perfectly valid assertions with "assertion expired" — fixed at the host, not in the federation config.

---

## 4. SCIM 2.0 Lifecycle Provisioning (Lab 04)

### Acronym / Feature: SCIM 2.0 (RFC 7643 / RFC 7644)
* **Theory:** The **System for Cross-domain Identity Management**: a REST schema for users and groups (RFC 7643) and operations (RFC 7644). Okta acts as the SCIM *client*, pushing directory state to target applications (the SCIM *server*) — `POST /Users` to create, `GET /Users?filter=` to query, `PATCH` for partial updates, `/Groups` for group sync.
* **Real-World Practice:** Replaces the manual "welcome ticket + spreadsheet" SaaS onboarding: in this lab, assigning an Okta user to the app created the downstream account in seconds, and unassigning deactivated it immediately — no helpdesk in the loop.

### Acronym / Feature: Schemas & the Enterprise User Extension
* **Theory:** SCIM payloads declare their schemas in the `schemas` array. The core `User` schema carries `userName`, `name`, `emails`; the extension `urn:ietf:params:scim:schemas:extension:enterprise:2.0:User` carries enterprise fields like `department` and `employeeNumber`.
* **Real-World Practice:** The captured `POST` payload shows both schemas — the identity attributes plus the `department: "Engineering"` extension — exactly what the target app needs for role mapping on arrival.

### Acronym / Feature: Idempotent Provisioning (Filter-then-Create)
* **Theory:** Before creating, Okta issues `GET /scim/v2/Users?filter=userName eq "..."`; only when the filter returns `totalResults: 0` does it `POST /Users`. Repeated imports and retry storms therefore cannot create duplicates.
* **Real-World Practice:** This is the difference between "import" and "blast": when a sync job retriggers mid-failure, the query-first pattern converges to one account instead of N — visible in the lab console log before every create.

### Acronym / Feature: `PATCH` Deactivation (`active: false`) vs. Deletion
* **Theory:** RFC 7644 `PatchOp` performs partial updates. Okta deactivates offboarded users with `{"op": "replace", "value": {"active": false}}` — a reversible soft-disable that keeps the historical record — instead of `DELETE`, which would erase audit history and break references.
* **Real-World Practice:** The leaver flow in this lab: unassigning the user produced the `PATCH` on the wire (captured as `scim-deactivate-user-patch.json`) and a `application.provision.user.deactivate` System Log event — the account is disabled everywhere while its history survives for auditors.

### Acronym / Feature: Push Groups
* **Theory:** Okta group synchronization: a directory group (here `GG_Dept_Engineering`) is "pushed" to the target app via `/scim/v2/Groups`, after which Okta maintains the group's membership downstream — membership changes propagate automatically.
* **Real-World Practice:** The enterprise JML multiplier: when a new engineer joins `GG_Dept_Engineering` in the directory, their downstream app role appears without anyone touching the SaaS console; when they leave, it disappears.

### Acronym / Feature: `externalId` & Import (Account Linking)
* **Theory:** The SCIM `externalId` attribute stores the IdP's identifier for the user, linking the downstream record back to its directory owner. Okta's **Import** task matches pre-existing target records by `userName`/email and stamps the linkage.
* **Real-World Practice:** Used when an enterprise adopts Okta for an app whose local accounts already exist: import-and-link avoids the `409 Conflict` of pushing a user the target already holds — one of the real issues resolved in this lab.

### Acronym / Feature: Bearer Token Authentication (SCIM Connectors)
* **Theory:** Okta's SCIM integration authenticates to the target server with an OAuth 2.0 Bearer token placed in the `Authorization` header — scoped, rotatable, and revocable, unlike basic auth credentials.
* **Real-World Practice:** The lab server enforces it strictly: any request without `Bearer scim-lab-secret-token-2026` receives a standards-shaped SCIM `401` error document — the same failure mode a rotated-but-not-updated enterprise token produces.

### Acronym / Feature: Reverse SSH Tunnel / `localhost.run` (HTTPS for Cloud Provisioning)
* **Theory:** Okta's provisioning engine only calls public HTTPS endpoints. A reverse SSH tunnel (`ssh -R 80:127.0.0.1:8090 nokey@localhost.run`) publishes a local HTTP listener under a public TLS-terminated hostname, giving the cloud IdP a routable HTTPS target for a lab-grade server.
* **Real-World Practice:** The lab's real-world lesson in connector fragility: tunnels drop mid-sync (a `Push Groups` failure here), URLs rotate on reconnect, and keep-alives (`ServerAliveInterval`) become part of your provisioning infrastructure's reliability budget.
