# Execution Guide — Lab 04 SCIM 2.0 Provisioning Rig

## Prerequisites
* Windows with OpenSSH client available in PowerShell (`ssh.exe`) and outbound access to `localhost.run`.
* Okta tenant with app creation rights (Admin Console).
* Two PowerShell windows: one for the SCIM server, one for the HTTPS tunnel.

## Step 1: Start the SCIM 2.0 Server (Window 1)
Open **PowerShell** and execute:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
C:\IAM-Lab-04-Okta\scripts\SCIMServer.ps1
```
The server binds explicitly to IPv4 `http://127.0.0.1:8090/` and serves `/scim/v2/Users`, `/scim/v2/Groups`, `?filter=` queries, `POST`/`PUT`/`PATCH`, Bearer token enforcement (`401` on mismatch), and auto-saves every received payload as JSON artifacts.

## Step 2: Publish the HTTPS Tunnel (Window 2)
Open a **second** PowerShell window and run:
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
C:\IAM-Lab-04-Okta\scripts\Start-ScimHttpsTunnel.ps1
```
`Start-ScimHttpsTunnel.ps1` runs `ssh -o ServerAliveInterval=15 -o StrictHostKeyChecking=no -R 80:127.0.0.1:8090 nokey@localhost.run`, printing a public HTTPS base URL (e.g. `https://b064b8c3c41e5b.app.lhr.life`). Your SCIM base URL for Okta is that host plus `/scim/v2`.

## Step 3: Wire Okta to the Rig
1. **Applications -> Browse App Catalog** -> add **SCIM 2.0 Test App (OAuth Bearer Token)** — label `Corp-SaaS-SCIM-Provisioning`.
2. **Provisioning -> Configure API Integration**: enable, set the **SCIM 2.0 Base URL** to `https://<tunnel-host>/scim/v2`, set the **OAuth Bearer Token** to `scim-lab-secret-token-2026`, and click **Test API Credentials**.
3. **Provisioning -> To App**: enable **Create Users**, **Update User Attributes**, and **Deactivate Users**.

## Step 4: Exercise the JML Cycle
* **Joiner:** create a directory user (e.g. `camila.reyes@corp-iam.lab`, `department = Engineering`, `title = Cloud Security Engineer`) and assign them to the app — watch the console log `GET /scim/v2/Users?filter=...` followed by `POST /scim/v2/Users`.
* **Mover/Push Groups:** push `GG_Dept_Engineering` under **Push Groups** and watch `/scim/v2/Groups` sync in the console.
* **Leaver:** remove the assignment (or deactivate the user) and watch the `PATCH` set `active: false`, then confirm `application.provision.user.deactivate` in **Reports -> System Log**.

## Verification Pointers
* Compare captured artifacts with [`../payloads/scim-create-user-post.json`](../payloads/scim-create-user-post.json) and [`../payloads/scim-deactivate-user-patch.json`](../payloads/scim-deactivate-user-patch.json).
* A wrong Bearer token must yield a SCIM `401` error response from the lab server.
