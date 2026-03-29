# Authorization Policy

ostk uses GPG-based identity. Access tiers are determined at session start.

## Getting authorized

1. Generate a GPG key if you don't have one:
   ```
   gpg --gen-key
   ```

2. Add it to your GitHub account:
   Settings → SSH and GPG keys → New GPG key

3. Install ostk and boot. You're T2 — read-only access, can explore.

4. To get write access (T1), get your key cross-signed by a T0 holder:
   ```
   # Share your fingerprint with a T0 holder
   gpg --fingerprint your@email.com

   # They sign your key:
   gpg --sign-key YOUR_FINGERPRINT
   gpg --export --armor YOUR_FINGERPRINT > signed-key.asc

   # You import their signature:
   gpg --import signed-key.asc
   ```

5. Boot again. The kernel detects the cross-signature → T1.

## Trust tiers

| Tier | What it means | How you get it | Default pin |
|------|--------------|----------------|-------------|
| T0 | Dual-signed (human + kernel) | Ratified by existing T0 holder | No restrictions |
| T1 | Cross-signed by T0 holder | Your GPG key signed by a T0 key | `deny: write-kernel modify-governance` |
| T2 | GPG on GitHub, not cross-signed | GitHub account with verified GPG | `deny: write-kernel modify-governance write-src` |
| T3 | Anonymous / no GPG | No verifiable identity | Cannot boot |

Trust is determined by the **GPG web of trust**, not by platform accounts.
GitHub is used for identity discovery (where to find your key fingerprint),
but the authority is the cross-signature chain rooted at the @ostk.ai root key.

## Policy enforcement

Access policy is defined in HUMANFILE and enforced by the kernel at the write path.
Policy is OS-governed, not manually approved. The kernel reads trust tiers from
session state — human ratification is required only for T0 elevation.

## PIN format

PINs are capability boundaries for agents. Each pin lives in `.ostk/pins/{name}/pin.caps`:

```
read: .ostk/ .language
write: .ostk/store/{name}/
execute: shell(readonly)
deny: write-kernel modify-governance
```

### Deny tokens

| Token | What it denies |
|-------|---------------|
| `write-kernel` | Writes to `.ostk/` — the OS state directory |
| `modify-governance` | Writes to HUMANFILE, ENTITYFILE, .primefile, GOVERNANCE.md, Agentfile, agents/ |
| `write-src` | Writes to `src/` — source code |

### Purpose

PINs exist so the **human** controls what agents can touch:

- Without pins: agents have full filesystem access
- With default pin: agents can't modify the OS or governance files
- With custom pins: you define exact boundaries per agent

The OS enforces pins invisibly. When an agent writes to a denied path,
the write is silently blocked. The agent never knows. The audit trail records it.

### Creating pins

```bash
# Issue a pin with default capabilities
ostk pin issue my-agent

# Issue with specific capabilities
ostk pin issue my-agent --caps "read write execute"

# Then edit the pin.caps file to customize deny rules:
# .ostk/pins/my-agent/pin.caps
```

### Why this design?

The OS is invisible to agents. Agents don't request capabilities — the human
declares boundaries. This inverts the traditional permission model: instead of
"grant access to X," it's "deny everything except Y."

The default is permissive (allow all writes). The human adds restrictions.
The OS enforces them. The agents never know.

### Tier-default pins (v2.2.1)

With v2.2.1, pins are **automatic**. Your trust tier determines your default
restrictions at boot. No `OSTK_PIN` env var needed.

Explicit pins (via `ostk run --pin <name>`) can only **add** restrictions
on top of your tier default. The tier is a floor, not an override.
A T2 user cannot escape `write-src` denial via an explicit pin.
