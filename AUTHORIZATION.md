# Authorization Policy

ostk uses GPG-based identity. Access tiers are determined at session start.

## Getting authorized

1. Generate a GPG key if you don't have one:
   ```
   gpg --gen-key
   ```

2. Add it to your GitHub account:
   Settings → SSH and GPG keys → New GPG key

3. That's it. Any GitHub account with a verified GPG key is authorized at T1.

## Trust tiers

| Tier | What it means | How you get it |
|------|--------------|----------------|
| T0 | GPG-ratified, dual-signed | Ratified by an existing T0 holder |
| T1 | Authenticated session | GitHub account with verified GPG |
| T2 | Kernel alias only | No GPG key on file |
| T3 | Anonymous | No verifiable identity |

## Policy enforcement

Access policy is defined in HUMANFILE and enforced by the kernel at the write path.
Policy is OS-governed, not manually approved. The kernel reads trust tiers from
session state — human ratification is required only for T0 elevation.
