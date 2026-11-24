# Execution Guide — Lab 03 SAML 2.0 SP-Initiated Federation Simulation

## Prerequisites
* Okta tenant with the `Corp-SaaS-Portal-SAML` application (ACS `http://localhost:8443/saml/acs`, Audience URI `https://sp.corp-iam.lab/saml/metadata`, RSA-SHA256 signed response + assertion).
* The Okta **signing certificate** downloaded from the app's **Sign On** tab (e.g., saved as `okta.cert` on the Desktop).
* A user assigned to the SAML app (`GG_Dept_Engineering` membership).

## Step 1: Point the Simulator at Your Tenant
Edit the first lines of [`Invoke-SamlSpSimulation.ps1`](Invoke-SamlSpSimulation.ps1) only if your values differ:
```powershell
$IdpSsoUrl = "https://integrator-6023165.okta.com/app/integrator-6023165_corpsaasportalsaml_1/exk1a9b3cswRfuMFp698/sso/saml"
$CertPath  = "$HOME\Desktop\okta.cert"
$AcsUrl    = "http://localhost:8443/saml/acs"
$EntityId  = "https://sp.corp-iam.lab/saml/metadata"
```

## Step 2: Run the Service Provider Simulator
Open **PowerShell** and execute:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
C:\IAM-Lab-03-Okta\scripts\Invoke-SamlSpSimulation.ps1
```
The simulator:
1. Builds a `<samlp:AuthnRequest>` with a fresh unique `ID` and `IssueInstant`.
2. Deflate-compresses it, Base64 + URL-encodes it (HTTP-Redirect binding) and produces the SP-initiated login URL.
3. Starts an `HttpListener` on the ACS endpoint and waits for Okta's `HTTP POST` `SAMLResponse`.
4. Decodes the response, verifies the **X.509 XML signature** with the downloaded certificate, and validates `InResponseTo`, `Audience`, and the `NotBefore`/`NotOnOrAfter` window.
5. Extracts the `NameID`, prints every Attribute Statement, and exports the formatted assertion XML.

Paste the generated URL into an **incognito** window, authenticate, and observe the validation results in the console.

## Step 3: Inspect the Captured Assertion
Compare the exported XML against [`../payloads/saml-assertion-sanitized.xml`](../payloads/saml-assertion-sanitized.xml) and confirm:
* `InResponseTo` matches the AuthnRequest `ID` generated in Step 2.
* `Destination` and the `AudienceRestriction` equal the ACS and Entity ID configured above.
* The signature block uses `rsa-sha256` with `xml-exc-c14n` canonicalization.
