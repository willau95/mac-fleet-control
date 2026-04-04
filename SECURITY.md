# Security Notice & Disclaimer

## ⚠️ IMPORTANT — READ BEFORE USE

### No Warranty, No Liability

This software is provided **"AS IS"** without warranty of any kind, express or implied. The authors and contributors:

- **Accept NO responsibility** for any damage, data loss, security breach, unauthorized access, or any other consequence resulting from the use of this software
- **Make NO guarantees** about the security, reliability, or fitness of this software for any purpose
- **Provide NO support** obligations of any kind
- **Are NOT liable** for any direct, indirect, incidental, special, exemplary, or consequential damages

### User Responsibility

By using this software, **YOU** accept full responsibility for:

1. **Authorization** — Ensuring you have legal authorization to remotely control all target machines
2. **Compliance** — Complying with all applicable local, state, national, and international laws and regulations
3. **Consent** — Obtaining proper consent from all machine owners and users
4. **Security** — Securing your Tailscale network, SSH keys, and all credentials
5. **Data Protection** — Protecting any personal or sensitive data accessible through remote control
6. **Network Security** — Securing your network against unauthorized access
7. **Physical Security** — Protecting machines with disabled screen locks and auto-login from unauthorized physical access

### Security Considerations

This software makes the following changes to worker machines that **reduce security** in exchange for remote manageability:

| Change | Risk | Your Responsibility |
|--------|------|---------------------|
| Disables sleep/hibernation | Higher power consumption, always-on attack surface | Physical security of the machine |
| Enables auto-login | Anyone with physical access can use the machine | Keep machines in secure locations |
| Disables screen lock | No password barrier for physical access | Physical security |
| Disables automatic updates | Missing security patches | Manually apply critical updates |
| Stores login credentials (kcpassword) | Weak XOR encoding, not true encryption | Physical security of the machine |
| SSH key-based auth | Key compromise = full access | Protect private keys |
| StrictHostKeyChecking=no | Vulnerable to MITM on first connection | Use within trusted networks |

### Intended Use

This software is designed for:
- **IT administrators** managing their own Mac fleet
- **DevOps teams** managing development/staging machines
- **Organizations** managing company-owned devices with proper authorization

This software is **NOT designed for** and **MUST NOT be used for**:
- Unauthorized access to any computer
- Surveillance or monitoring without consent
- Any illegal activity
- Controlling machines you do not own or have authorization to manage

### Legal Notice

Unauthorized access to computer systems is illegal in most jurisdictions. This includes but is not limited to:

- **Computer Fraud and Abuse Act (CFAA)** — United States
- **Computer Misuse Act 1990** — United Kingdom
- **Criminal Code Act 1995 (Div 477-478)** — Australia
- **Personal Data Protection Act (PDPA)** — Singapore/Malaysia
- Similar laws in other jurisdictions

**Violation of these laws can result in criminal prosecution and civil liability.**

### Reporting Security Issues

If you discover a security vulnerability, **DO NOT** open a public issue.

Please report it privately via:
- **GitHub Security Advisories**: [Report a vulnerability](https://github.com/willau95/mac-fleet-control/security/advisories/new)
- Or email: **willau95@proton.me**

We will respond within 48 hours.

---

**By using this software, you acknowledge that you have read and understood this notice and accept all risks and responsibilities described above.**
