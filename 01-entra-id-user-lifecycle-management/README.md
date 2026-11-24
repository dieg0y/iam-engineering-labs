# Microsoft Entra ID User Lifecycle Management Lab

> Hands-on project demonstrating the complete Joiner-Mover-Leaver (JML) lifecycle in Microsoft Entra ID.

This lab covers user onboarding, group-based access management, password administration, sign-in auditing, offboarding, Access Reviews, Conditional Access, and Break Glass account management through practical exercises in the Microsoft Entra Admin Center.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
- [Lab Modules](#lab-modules)
- [Best Practices and Security](#best-practices-and-security)
- [Lab Cleanup](#lab-cleanup)
- [Disclaimer](#disclaimer)

---

## Project Overview

This project demonstrates how organizations manage user identities throughout the employee lifecycle using Microsoft Entra ID.

By completing this lab, you will gain hands-on experience with identity administration, access management, security monitoring, governance controls, and user lifecycle processes commonly performed by IT Support, Microsoft 365 Administrators, and Identity Administrators.

---

## Prerequisites

1. Create a Microsoft Azure account:
   - https://azure.microsoft.com/free/

2. Create or use an existing Microsoft Entra ID tenant.

3. Assign one of the following administrative roles:
   - Global Administrator
   - User Administrator

4. Access the Microsoft Entra Admin Center:
   - https://entra.microsoft.com

> **Security Note:** Never publish passwords, Tenant IDs, Object IDs, secrets, or any other sensitive data in a public repository.

---

## Repository Structure

```text
/
├── README.md
├── 01-create-user-manually/
│   ├── README.md
│   └── images/
├── 02-create-group-and-assign-membership/
│   ├── README.md
│   └── images/
├── 03-reset-password-disable-and-re-enable-an-account/
│   ├── README.md
│   └── images/
├── 04-sign-in-logs-audit-and-monitoring/
│   ├── README.md
│   └── images/
├── 05-mover-and-leaver-promotion-and-offboarding/
│   ├── README.md
│   └── images/
├── 06-access-review/
│   ├── README.md
│   └── images/
└── 07-break-glass-and-conditional-access/
    ├── README.md
    └── images/
```

Each folder contains its own walkthrough, screenshots, and documentation.

---

## Lab Modules

Click any module below to open the complete walkthrough.

### 🔹 [01 · Create a User Manually](01-create-user-manually/)

Create and configure a new user account in Microsoft Entra ID.

### 🔹 [02 · Create a Group and Assign Membership](02-create-group-and-assign-membership/)

Manage access using security groups and group membership.

### 🔹 [03 · Reset Password, Disable, and Re-enable an Account](03-reset-password-disable-and-re-enable-an-account/)

Perform common identity administration and Help Desk tasks.

### 🔹 [04 · Sign-in Logs: Audit and Monitoring](04-sign-in-logs-audit-and-monitoring/)

Review sign-in activity and security-related events.

### 🔹 [05 · Mover and Leaver: Promotion and Offboarding](05-mover-and-leaver-promotion-and-offboarding/)

Simulate role changes and employee offboarding processes.

### 🔹 [06 · Access Review](06-access-review/)

Validate user access through identity governance controls.

### 🔹 [07 · Break Glass and Conditional Access](07-break-glass-and-conditional-access/)

Configure emergency administrative access and Conditional Access policies.

---

## Best Practices and Security

- Assign permissions through groups rather than directly to users.
- Follow the principle of least privilege.
- Disable accounts immediately when employees leave the organization.
- Review Sign-in Logs regularly.
- Never publish credentials or sensitive information.
- Document administrative activities and security-related changes.

---

## Lab Cleanup

After completing the lab:

1. Delete test users.
2. Delete test groups.
3. Remove test Access Reviews.
4. Remove any unused policies.
5. Verify that disabled accounts remain disabled.

---

## Disclaimer

This project was created, tested, and validated by **Diego Yonoff**.

Artificial Intelligence tools were used solely to assist with documentation formatting, grammar improvements, and content organization.

All configurations, testing, screenshots, validation, and administrative actions were performed manually within a Microsoft Entra ID environment.

The project is intended for educational and portfolio purposes only.

---

[← Back to index](../README.md)
