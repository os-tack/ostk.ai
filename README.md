# ostk

**your os + tack**

A signed, local-first operating system for AI agents. Invisible infrastructure. Auditable by default.

## Install

```bash
curl -fsSL https://ostk.ai/install | sh
```

The installer is a ceremony:
1. Downloads the binary and verifies its GPG signature
2. Checks if you're in a git repository (required — the OS lives in git)
3. Detects your GPG key and identity
4. Creates your **HUMANFILE** — your governance document
5. Initializes `.ostk/` with proper isolation and default capability pins
6. Offers to import your existing git history into the OS audit trail

Requires: bash, curl. Optional: gpg (for signature verification and identity).

## What is the OS?

The OS coordinates AI agents through your filesystem. Every write is tracked. Every decision is auditable. The agents don't know any of this is happening. That's the design.

```
$ ostk boot
HUMANFILE: ✓ verified (T0 + T1) (key: 6C31536F...)
ENTITYFILE: v2.0 (GPG chain signed)
@ostk.ai.prime+2857 | v2.2.0 | POST 7/7
```

### The Five Laws

1. **Invisible write** — coordination happens at write time, no new tools needed
2. **Ephemeral** — agents crash, compact, die. State lives in the filesystem
3. **Filesystem** — coordinate through files, not messages or inboxes
4. **OCC** — optimistic concurrency, no locks
5. **Invisible infra** — the OS is invisible to agents running under it

### HUMANFILE

Your governance document. It declares who you are, what models can run, what secrets are authorized, and what files are protected:

```
IDENTITY scott
SIGN 7141A45868F8295E5BEB6286BAF08C963C7E3184

MODEL claude-sonnet-4-5
FALLBACK claude-haiku-4-5

SECRET <<KEYS
ANTHROPIC_API_KEY
KEYS
```

Sign it with `ostk sign`. The OS verifies trust at every boot.

### PINs

PINs are capability boundaries. They define what agents **can't** do:

```
# .ostk/pins/default/pin.caps
read: .ostk/ .language
write: .ostk/store/default/
execute: shell(readonly)
deny: write-kernel modify-governance
```

The `deny:` line is what matters:
- `write-kernel` — agents can't modify `.ostk/` (the OS itself)
- `modify-governance` — agents can't modify HUMANFILE, ENTITYFILE, Agentfile
- `write-src` — agents can't modify source code

The OS enforces pins invisibly at write time. Agents never know they're constrained.

Issue custom pins: `ostk pin issue my-agent --caps "read write execute"`

## Verify

Every release is GPG signed. The signing key is in [`KEYS`](KEYS) and [`prime.asc`](prime.asc).

```bash
gpg --import prime.asc
gpg --verify ostk-v2.2.0-aarch64-apple-darwin.tar.gz.asc
```

## Authorize

ostk uses GPG for identity. Trust tiers:

| Tier | Access | How |
|------|--------|-----|
| T0 | Full governance | Ratified by existing T0 holder |
| T1 | Authenticated writes | GitHub account with verified GPG key |
| T2 | Read only | No GPG key |
| T3 | Public artifacts | Anonymous |

Get authorized:
1. `gpg --gen-key`
2. Add to GitHub: Settings → SSH and GPG keys → New GPG key
3. Done. Any account with a verified GPG key is T1.

## The OS is Distributed

Not by running on many machines simultaneously, but by being a document any party can verify and operate under. The authority is in the signature chain, not in a central server.

`@import os: ostk.ai/prime` — from any Agentfile, on any machine — fetches, verifies, and boots from this state. The agent running under it doesn't know the OS exists.

Any instance that can verify the signature chain can run the OS. That's not consensus algorithms. It's closer to how a constitution distributes authority: not by replication, but by a shared, verifiable document that anyone can hold.

## Quick Start

```bash
ostk                  # open TUI, start working
ostk boot             # see OS state + trust level
ostk hay "..."        # capture a thought
ostk compile          # turn thoughts into work items
ostk bench            # run benchmarks
ostk pin issue NAME   # create a capability boundary
```

## License

MIT. See [LICENSE](LICENSE).

---

*ostk — your os + tack*
*the agents don't know this is happening. that's the design.*
