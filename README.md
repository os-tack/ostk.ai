# ostk

**your os + tack**

A signed, local-first distributed operating system for AI agents. Invisible infrastructure. Auditable by default. Fleet-coordinated by design.

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
HUMANFILE: verified (T0 + T1) (key: 6C31536F...)
@ostk.ai.prime+3981 | v2.5.0 | POST 7/7
needles: 344 open
fleet: 3 alive | laws: invisible-write | ephemeral | filesystem | OCC | invisible-infra
```

### The Five Laws

1. **Invisible write** — coordination happens at write time, no new tools needed
2. **Ephemeral** — agents crash, compact, die. State lives in the filesystem
3. **Filesystem** — coordinate through files, not messages or inboxes
4. **OCC** — optimistic concurrency, no locks held during the expensive phase
5. **Invisible infra** — the OS is invisible to agents running under it

### Seven kernel primitives

Built on POSIX. Battle-hardened since 1983.

| # | Primitive | What it does |
|---|---|---|
| 1 | atomic_write | tmp + fsync + rename. Crash-safe file replacement. |
| 2 | gen + CAS | Optimistic concurrency control via generation counters. |
| 3 | Hot PR | Auto-merge non-overlapping concurrent writes. |
| 4 | audit log | Append-only event log. Every state change. `jq`-queryable. |
| 5 | identity | Kernel-assigned, GPG-signed, survives restart. |
| 6 | digest | Fleet status injected into every tool response. |
| 7 | 304 elision | Skip re-reading unchanged files. Saves context budget. |

### The daemon

`ostk listen` runs the kernel daemon: a long-lived anchor process that holds the socket, the process table, and the scheduler. Clients (TUI, MCP, CLI) attach and detach without disturbing running agents.

```bash
ostk listen                    # start the daemon
ostk                           # attach TUI to running daemon
```

The daemon survives client crashes. Agents survive daemon crashes (drain snapshots + audit log replay reconstruct the fleet on restart).

### Fleet coordination

The scheduler dispatches work across a fleet of agents. Workers spawn, run, drain, and reap — all managed by the kernel.

```
$ ostk ps
scheduler   opus     active   12m   ctx:34%
worker-a    sonnet   active   3m    ctx:18%
worker-b    sonnet   done     0s    ctx:0%     (reaped)
```

Agent lifecycle tools the scheduler can call:
- `spawn_agent` — create a managed worker session with heartbeat + drain support
- `reap_agent` — remove a completed or dead worker
- `spawn_stack` — create an isolated sub-stack with its own audit log and token budget
- `seal_stack` — terminate a sub-stack and archive its state

### Crash recovery

Every agent writes a drain snapshot at every turn boundary (default ON). If the daemon crashes:

1. New daemon starts, acquires the anchor lock
2. `fold(audit.jsonl)` replays the audit log to reconstruct the fleet state
3. Orphaned lineages with drain snapshots are rehydrated automatically
4. Revival policy per agent: `revive` (auto-recover), `reap` (drop), `ask` (operator decides)

Mid-flight recovery: the scheduler's tick loop detects crashed workers via heartbeat and hot-rehydrates them without a daemon restart.

### Sub-stacks

Isolated blast-radius boundaries for multi-worker tasks:

```
.ostk/stacks/bugfix-27/
  audit.jsonl    # scoped audit log
  drain/         # scoped drain snapshots
  inbox/         # commands from anchor
  nudges/        # reports to anchor
```

Each sub-stack has its own token budget. Overruns force-seal the stack. The anchor is unaffected.

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

Capability boundaries. They define what agents **can't** do:

```
# .ostk/pins/default/pin.caps
read: .ostk/ .language
write: .ostk/store/default/
execute: shell(readonly)
deny: write-kernel modify-governance
```

The OS enforces pins invisibly at write time. Agents never know they're constrained.

## Verify

Every release is GPG signed. The signing key is in [`KEYS`](KEYS) and [`prime.asc`](prime.asc).

```bash
gpg --import prime.asc
gpg --verify ostk-v2.5.0-aarch64-apple-darwin.tar.gz.asc
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

## The OS is distributed

The kernel sits on POSIX. The prompt cache spans hosts. The architecture is designed for fleet coordination across machines — today via filesystem primitives, tomorrow via the Anthropic Files API as a cross-host storage tier.

Any instance that can verify the signature chain can run the OS. That's not consensus algorithms. It's closer to how a constitution distributes authority: not by replication, but by a shared, verifiable document that anyone can hold.

## Quick Start

```bash
ostk                           # open TUI, start working
ostk boot                      # see OS state + trust level
ostk listen                    # run the kernel daemon
ostk hay "..."                 # capture a thought
ostk compile                   # turn thoughts into work items
ostk lineage resolve ID --revive  # resolve an Ask-pending session
ostk bench                     # run benchmarks
ostk pin issue NAME            # create a capability boundary
```

## Architecture

- **Kernel specification**: [ostk.ai/docs/kernel-spec](https://ostk.ai/docs/kernel-spec) — seven primitives, Five Laws, memory hierarchy, dual-CPU scheduler
- **Session topology**: [ostk.ai/docs/session-topology](https://ostk.ai/docs/session-topology) — anchors, lineages, drain snapshots, crash recovery, sub-stacks
- **Test suite**: 2997 tests, 0 failures

## License

MIT. See [LICENSE](LICENSE).

---

*ostk — your os + tack*
*the agents don't know this is happening. that's the design.*
