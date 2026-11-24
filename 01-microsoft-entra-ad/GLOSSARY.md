# Identity & Access Management (IAM) — Technical & Real-World Glossary

A practical reference guide covering every core protocol, policy engine, acronym, and security control implemented across Labs 01–05. Each entry separates **exact architectural theory** from **real-world enterprise deployment scenarios**.

---

## 1. Active Directory & Hybrid Identity Foundations (Labs 01 & 02)

### Acronym / Feature: Tier-0 Administrative Isolation (Enterprise Access Model)
* **Theory:** A privileged access segmentation architecture that isolates control-plane identities, Domain Controllers, and identity synchronization servers (`Tier 0`) from application servers (`Tier 1`) and standard employee workstations (`Tier 2`), blocking upward credential exposure and GPO inheritance.
* **Real-World Practice:** Used in enterprise environments to ensure that if a helpdesk technician's workstation or a standard user's laptop is compromised by malware or credential dumping (e.g., Mimikatz), the attacker cannot harvest Domain Admin or Entra Global Administrator credentials and take over the entire organization.

### Acronym / Feature: AGDLP (Account -> Global -> Domain Local -> Permission)
* **Theory:** Microsoft's recommended Role-Based Access Control (RBAC) group nesting model for Active Directory: user **Accounts** are added to role-based **Global Groups** (`GG_*`), which are nested inside resource-scoped **Domain Local Groups** (`DL_*`), which are granted explicit **Permissions** (ACLs) on target resources.
* **Real-World Practice:** Used when scaling permissions across hundreds of file shares, ERP systems, or internal apps. When a new Financial Analyst joins the company, IT adds them once to `GG_Dept_Finance`, and they automatically inherit access to every Finance folder and application without administrators ever editing individual folder ACLs.

### Acronym / Feature: OU (Organizational Unit) & GPO (Group Policy Object)
* **Theory:** An **Organizational Unit (OU)** is a subdividable container inside an Active Directory domain used to organize users, groups, and computers for administrative delegation and policy targeting. A **Group Policy Object (GPO)** is a collection of registry, security, and audit configurations linked to sites, domains, or OUs.
* **Real-World Practice:** Used to enforce baseline security configurations automatically—such as locking accounts after 5 failed password attempts against brute-force attacks, or enabling Windows Security Event IDs `4720` (account created) and `4625` (failed logon) so a SOC SIEM (like Microsoft Sentinel or Splunk) can detect credential stuffing in real time.

### Acronym / Feature: PHS (Password Hash Synchronization)
* **Theory:** A Microsoft Entra Connect authentication method that extracts the MD4 hash of a user's password from on-premises Active Directory, applies a per-user salt and 1,000 iterations of SHA-256 hashing, and synchronizes that derived hash over TLS 1.2 to Microsoft Entra ID—never transmitting plaintext or reversible passwords.
* **Real-World Practice:** Used by the vast majority of hybrid organizations because it allows employees to sign into Microsoft 365 and cloud SaaS apps with their corporate password even if their on-premises Domain Controllers go offline during a power outage or network failure, while also enabling Entra ID Protection's leaked-credential detection.

### Acronym / Feature: Seamless SSO (Single Sign-On)
* **Theory:** An authentication enhancement that uses a Kerberos computer account (`AZUREADSSOACC$`) registered in on-premises AD so domain-joined devices on the corporate network automatically obtain a Kerberos ticket for Entra ID without prompting users to re-type their password.
* **Real-World Practice:** Used when employees open Microsoft Teams, Outlook, or SharePoint on their office PCs: they are signed in transparently using their existing Windows desktop logon session, reducing password fatigue and helpdesk login tickets.

### Acronym / Feature: Source Anchor (`ms-DS-ConsistencyGuid`)
* **Theory:** An immutable attribute used by Microsoft Entra Connect to uniquely link an on-premises Active Directory object to its corresponding cloud identity in Microsoft Entra ID across synchronization cycles, exported as `OnPremisesImmutableId` (Base64-encoded).
* **Real-World Practice:** Used instead of `objectGUID` in real enterprises because if the company ever merges with another business or migrates users between two on-premises Active Directory forests, `objectGUID` changes (creating duplicate cloud accounts), whereas `ms-DS-ConsistencyGuid` can be carried over to preserve the exact cloud identity link.

### Acronym / Feature: Soft-Match vs. Hard-Match
* **Theory:** Synchronization linking mechanisms in Entra Connect: **Soft-Match** links an incoming on-premises user to an existing cloud-only account by matching `userPrincipalName` or `proxyAddresses` (SMTP), whereas **Hard-Match** links them authoritatively via the Base64 `OnPremisesImmutableId` attribute.
* **Real-World Practice:** Used when an organization initially created cloud-only Microsoft 365 accounts for employees and later deploys on-premises Active Directory; engineers stamp the Base64 `objectGUID` onto the cloud accounts (`Hard-Match`) so users keep their existing mailboxes and OneDrive files without duplication.

---

## 2. Automated Lifecycle Management (Lab 03)

### Acronym / Feature: JML (Joiner-Mover-Leaver) Lifecycle Automation
* **Theory:** The end-to-end Identity Governance framework governing how digital identities and entitlements are provisioned upon onboarding (**Joiner**), modified during internal role or department changes (**Mover**), and immediately revoked upon termination (**Leaver**).
* **Real-World Practice:** Used via HR-driven provisioning or Microsoft Graph scripts so that when HR marks an employee as terminated at 5:00 PM, their account is disabled, active sessions are terminated, and group memberships are stripped within seconds—eliminating "orphan accounts" left behind by manual offboarding.

### Acronym / Feature: Dynamic Security Groups & Group-Based Licensing
* **Theory:** Entra ID groups whose membership is continuously calculated by evaluating boolean attribute rules (e.g., `(user.department -eq "Engineering") and (user.accountEnabled -eq true)`). Group-Based Licensing binds SaaS/Microsoft 365 license SKUs directly to those groups.
* **Real-World Practice:** Used in growing companies to eliminate manual license tickets: when an analyst transfers from *Finance* to *Engineering*, updating their `Department` attribute automatically removes them from Finance apps, adds them to Engineering repositories, and assigns their developer tool licenses.

### Acronym / Feature: Refresh Token Revocation (`Revoke-MgUserSignInSession`)
* **Theory:** An API operation (`POST /users/{id}/revokeSignInSessions`) that updates a user's `refreshTokensValidFromDateTime` timestamp in Entra ID, immediately invalidating all existing OAuth2 refresh tokens and persistent browser session cookies across every device.
* **Real-World Practice:** Used alongside `AccountEnabled = $false` during employee termination or suspected account compromise. Without refresh token revocation, an attacker or departing employee with an active browser session could continue reading corporate emails for up to 1 hour (or longer with persistent sessions) until the current access token expires.

---

## 3. Zero Trust Conditional Access & Privileged Governance (Lab 04)

### Acronym / Feature: Conditional Access (Zero Trust Policy Engine)
* **Theory:** Microsoft Entra ID's real-time Zero Trust policy evaluation engine that analyzes identity signals (user/role, device compliance, IP/country location, client app protocol, and real-time risk score) at authentication time and enforces access controls (`Block`, `Require MFA`, `Require Phishing-Resistant MFA`, `Require Password Change`).
* **Real-World Practice:** Used as the central perimeter of modern cloud security—replacing traditional VPN-only trust by verifying *who* is signing in, *from where*, and *on what device* before issuing an access token to any corporate application.

### Acronym / Feature: Named Locations (Geo-Fencing & Trusted IPs)
* **Theory:** Logical network boundaries defined in Entra Conditional Access by public IPv4/IPv6 CIDR ranges or ISO country codes (resolved via IP geolocation or GPS) used as inclusion or exclusion conditions in access policies.
* **Real-World Practice:** Used when an organization operates exclusively in specific countries—for example, restricting corporate sign-ins so **only users connecting from Colombia** (and approved corporate offices) can authenticate, immediately blocking credential-stuffing attacks originating from foreign infrastructure.

### Acronym / Feature: Legacy Authentication Blocking (`CA01`)
* **Theory:** A Conditional Access control targeting `Exchange ActiveSync` and `Other clients` (legacy protocols such as SMTP, IMAP, POP3, and older Office clients) that do not support modern OAuth2/OIDC interactive prompts and therefore cannot enforce Multi-Factor Authentication (MFA).
* **Real-World Practice:** Used as the #1 foundational security control in any Entra ID tenant because automated password-spray attacks overwhelmingly target legacy IMAP/SMTP endpoints precisely because those protocols cannot enforce MFA.

### Acronym / Feature: Phishing-Resistant MFA (FIDO2 / WebAuthn / Passkeys)
* **Theory:** Authentication methods cryptographically bound to the origin domain via public-key cryptography (such as FIDO2 hardware security keys, Windows Hello for Business, or device-bound Passkeys), preventing Adversary-in-the-Middle (AiTM) reverse-proxy phishing kits from replaying stolen session cookies.
* **Real-World Practice:** Mandatory for **Global Administrators** and security engineers (`CA02`), because standard SMS or push-notification MFA can be bypassed by sophisticated AiTM phishing pages, whereas FIDO2 keys refuse to sign challenges on lookalike phishing domains.

### Acronym / Feature: Break-Glass Accounts (Emergency Access Accounts)
* **Theory:** Two dedicated, cloud-only (`*.onmicrosoft.com`) accounts assigned permanent `Global Administrator` privileges, protected by long high-entropy credentials, excluded from all Conditional Access policies (an accepted trade-off: they skip MFA and geo checks in exchange for guaranteed emergency access), and monitored via high-severity SIEM alerts.
* **Real-World Practice:** Used as an emergency parachute when a misconfigured Conditional Access policy accidentally blocks all administrators, or if an on-premises Federation/AD server crashes—ensuring engineers can always regain tenant control without calling Microsoft Support.

### Acronym / Feature: PIM (Privileged Identity Management) & JIT (Just-In-Time) Elevation
* **Theory:** A privileged access governance service that converts permanent (**Active**) administrative role assignments into time-bound (**Eligible**) assignments requiring explicit activation, MFA verification, business justification, and maximum duration caps (e.g., `2 hours`).
* **Real-World Practice:** Used to enforce **Zero Standing Privilege (ZSP)**: an IT engineer works day-to-day as a standard unprivileged user, and only elevates into `User Administrator` or `Global Administrator` for 2 hours when performing a specific change—shrinking the window of exposure if their daily account is phished.

---

## 4. Identity Governance, Risk Protection & App Delegation (Lab 05)

### Acronym / Feature: User Risk Policy
* **Theory:** A risk-based Conditional Access policy powered by Entra ID Protection's offline threat intelligence that detects compromised identity indicators—such as credentials leaked on dark-web paste sites or atypical threat telemetry—and enforces automated remediation (`Require MFA` + `Require secure password change`).
* **Real-World Practice:** Used when an employee reuses their corporate password on an external website that suffers a data breach; as soon as Microsoft's threat intelligence detects the leaked credential pair, Entra automatically flags the user as **High User Risk** and forces them to complete MFA and rotate their password before accessing corporate resources.

### Acronym / Feature: Sign-In Risk Policy
* **Theory:** A real-time risk evaluation policy that analyzes telemetry of a specific authentication session—including impossible travel, anonymous IP/Tor exit nodes, unfamiliar sign-in properties, and malware-linked IP addresses—and challenges `Medium` or `High` risk sessions with fresh MFA.
* **Real-World Practice:** Used when an employee normally logs in from Barranquilla, Colombia, and 15 minutes later an authentication attempt arrives from an anonymous proxy in Eastern Europe; Entra challenges the suspicious session with step-up MFA (or blocks it) without disrupting the legitimate employee's normal workflow.

### Acronym / Feature: Entitlement Management (Access Packages)
* **Theory:** An Identity Governance framework that bundles multiple resources (security groups, Microsoft 365 groups, Teams, SharePoint sites, and enterprise apps) into a self-service **Access Package** governed by request policies, business justification, multi-stage sponsor approvals, and automatic expiration dates.
* **Real-World Practice:** Used for temporary project or audit access—for example, granting an internal auditor access to `Finance-Audit-Workspace` for **30 days** after manager approval, after which Entra ID automatically revokes the access without anyone needing to remember to file a removal ticket.

### Acronym / Feature: Access Reviews
* **Theory:** Periodic governance attestation campaigns where resource owners, managers, or designated reviewers certify whether users still require ongoing membership in privileged roles or sensitive groups, with optional `Auto apply results to resource` enforcement.
* **Real-World Practice:** Used for SOC 2, ISO 27001, and financial compliance audits to prove that emergency Break-Glass accounts, external B2B guests, and sensitive project groups are reviewed quarterly and that any uncertified or ignored users are automatically stripped of access.

### Acronym / Feature: Administrative Units (AUs)
* **Theory:** Logical sub-containers inside a Microsoft Entra ID tenant used to restrict the scope of administrative RBAC roles (such as `User Administrator` or `Helpdesk Administrator`) so delegated administrators can only manage users, groups, or devices placed inside that specific unit.
* **Real-World Practice:** Used in multinational or multi-campus organizations so a regional IT support specialist in LATAM (`AU-LATAM-Operations`) can reset passwords for LATAM employees, but receives `Authorization_RequestDenied` if they attempt to reset the password of an executive or an engineer in North America.

### Acronym / Feature: App Registration vs. Enterprise Application (Service Principal)
* **Theory:** An **App Registration** is the global application blueprint (`Application Object`) defining the app's Client ID, Redirect URIs, API scopes, and custom App Roles in its home tenant; an **Enterprise Application** is the local tenant instantiation (`Service Principal`) where user/group assignments, Conditional Access policies, and OAuth permissions are enforced.
* **Real-World Practice:** Used whenever integrating custom internal APIs or third-party SaaS apps via OIDC/SAML—developers configure OAuth URIs and custom roles (`Reports.Read.All`) in **App Registrations**, while IAM security engineers assign which employees can actually sign into the app inside **Enterprise Applications**.

### Acronym / Feature: OAuth Consent Governance & Admin Consent Workflow
* **Theory:** Tenant-wide authorization controls that disable unrestricted end-user consent (`Do not allow user consent`) to third-party OAuth/OpenID Connect applications and route permission requests to a centralized **Admin Consent Workflow** queue for security review.
* **Real-World Practice:** Used to stop **Illicit Consent Grant (OAuth Phishing)** attacks—where attackers trick employees into clicking "Accept" on a malicious third-party app requesting `Mail.Read` or `Files.Read.All` permissions, which would otherwise let the attacker exfiltrate corporate data without needing the user's password or MFA.

### Acronym / Feature: B2B External Collaboration Governance
* **Theory:** Cross-tenant identity federation settings in Entra ID that control who can invite external guest users (`Only users assigned to specific admin roles`), which external domains are allowed/blocked, and how guest lifecycle reviews are enforced.
* **Real-World Practice:** Used when collaborating with external auditors, vendors, or partners (`External SOC Auditor`) so external collaborators authenticate using their own corporate identity under Conditional Access policies rather than receiving unmanaged local accounts.

### Acronym / Feature: SSPR (Self-Service Password Reset) & Entra Smart Lockout
* **Theory:** **SSPR** empowers verified users to reset or unlock their own passwords via registered MFA methods with writeback to on-premises AD; **Smart Lockout** uses behavioral heuristics to distinguish familiar legitimate devices from unfamiliar attackers, locking out brute-force sources while allowing genuine users to sign in normally.
* **Real-World Practice:** Used together with custom **Banned Password Lists** (blocking company-specific terms like `Barranquilla` or `IamLab2026`) to eliminate weak predictable passwords and prevent denial-of-service account lockouts caused by external password-spray bots.
