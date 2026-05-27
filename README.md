# ostk

**your os + tack** — a local-first operating system for AI agents.

ostk is a kernel that lives in your project's `.ostk/` directory. It coordinates AI agents through the filesystem instead of through messages, locks, or services. Every write is journaled; the journal is sealed per epoch with DSSE envelopes. The agents don't know any of this is happening. That's the design.

## Install

```bash
curl -fsSL https://ostk.ai/install.sh | sh
```

The installer downloads the latest signed binary, verifies the GPG signature against the prime key, and drops `ostk` into `~/.local/bin`. After install:

```bash
cd your-project          # any git repo
ostk init                # creates .ostk/, HUMANFILE, Agentfile, pin.caps from the signed governance bail
ostk boot                # brings the kernel up
```

Requires: bash, curl, gpg (for verification). macOS Apple Silicon, Linux x86_64/aarch64 (gnu + musl), Windows x86_64.

## What ostk is

A POSIX-resident kernel for AI agents:

- **Substrate as projection.** `.ostk/journal.jsonl`, `decisions.jsonl`, `needles/`, `drivers.jsonl`, `agents.jsonl` — the kernel's state is the on-disk log. Registries are memoized projections. Daemon dies → registries rebuild from source on next boot. There is no "in-memory truth."
- **Invisible coordination.** Agents see the tools they expect — shell, file:read, file:edit, web, task, recall. They don't see locks, leases, or service endpoints. The kernel intercepts at write time and handles conflict, audit, attestation.
- **Filesystem as namespace.** `/ostk/proc/<alias>/stat`, `/ostk/needles/<id>/body`, `/ostk/fed/<project>/` — the VFS mount exposes kernel state under a stable path layout. `cat`, `ls`, `find` all work.
- **Signed, distributed, no consensus.** Trust flows through GPG. Any instance that can verify the signature chain can run the OS. Not replication — a shared, verifiable document, the way a constitution distributes authority.

## The Five Laws

These hold across every release:

1. **Invisible write** — coordination happens at write time. No new tools.
2. **Ephemeral** — agents crash, compact, die. State lives in the filesystem.
3. **Filesystem** — coordinate through files, not messages or inboxes.
4. **OCC** — optimistic concurrency. No locks held during the expensive phase.
5. **Invisible infra** — the OS is invisible to agents running under it.

## Quick start (v7)

After `ostk init && ostk boot`:

```bash
ostk help                              # full verb surface
ostk work capture "fix the auth flow"  # add an idea to the pile
ostk work triage                       # turn captures into needles
ostk work pull --peek                  # next needle to tackle
ostk work show '→1612' --depends       # explore needle + its graph
ostk recall '→1612'                    # fetch a substrate record by address
ostk recall_search "embedding store"   # free-text search across substrate
ostk shutdown                          # clean kernel exit
```

The TUI:

```bash
ostk                                   # attach to running daemon
```

## What you get

When you `curl … | sh` and then `ostk init && ostk boot`, this is what shows up:

**The kernel.** A POSIX-resident daemon you boot once per project. It holds the anchor lock, owns the audit log, runs the scheduler, and serves a verb surface to clients (the TUI, MCP servers, CLI invocations). It's a single daemon per project root — open the TUI in two terminals and they attach to the same kernel. When the daemon crashes, the next boot replays `audit.jsonl` and resurrects the fleet from drain snapshots; there's no consensus protocol, no quorum, no service mesh.

**A verb surface.** 135 verbs in the canonical CLI table (`src/kernel/cli_surface.rs`), split into classes. **Class 1** is the agent-callable System ABI — 27 core-resident verbs (`bash`, `fs_ops`, `dispatch`, `context_evict`, `context_load`, `context_pin`, `context_store`, `recall`, `recall_search`, `help`, ...) frozen with `abi_hash` parity to `crates/ostk-abi/src/verbs.rs`; shape changes force an ABI semver bump. **Class 2 Lifecycle** is daemon control (`boot`, `init`, `shutdown`, `tui`). **Class 2 SystemUtility** is the operator overlay — 22 flat verbs (`show`, `trace`, `decide`, `commit`, `inspect`, `ps`, `kill`, `attach`, `bail`, `profile`, `secret`, `grant`, ...). **Class 3 Namespaces** are 7 parents (`work`, `trust`, `recovery`, `fleet`, `agentfile`, `vfs`, `serve`) with members like `work.capture`, `work.triage`, `work.pull`, `work.show`, `recovery.seal`. `ostk help` walks the tree.

**Drivers.** Capability providers the kernel routes calls to. Two kinds:

- **Internal drivers** are compiled into the ostk binary. Today these are `fcp-screen` (TUI display) and `fcp-web` (fetch + readability). They register unconditionally at boot — no HUMANFILE entry needed.
- **External drivers** are subprocesses speaking the fcp JSON-RPC protocol over stdio. They're declared in HUMANFILE as `DRIVER <name>`; the kernel demand-spawns them on first use via `driver_manager::need_driver()` and tracks `<name>.lock` + `<name>.log` artifacts under `.ostk/drivers/`. The default set in the bail HUMANFILE is `fcp-rust` (Rust-aware code chunker), `fcp-recall` (the daemonized recall surface — hybrid dense + BM25 retrieval over your local corpus, transcripts, code, decisions log).

To wire a new external driver, build an executable that speaks fcp JSON-RPC, then add it via HUMANFILE: `DRIVER my-driver` plus a kernel-known transport + command mapping (see the `DriverDecl` registry in `src/commands/boot/drivers.rs`). The kernel does **not** scan `.ostk/drivers/` for code — that directory holds only runtime artifacts.

**A filesystem view of OS state.** Mount `/ostk/` (FUSE on macOS Apple Silicon with the `-fuse` build; Linux requires a from-source build with `--features fuse`) and you can `cat`, `ls`, `grep`, `find` over the kernel's state.

- `/ostk/proc/<alias>/stat` — live agent metadata, like `/proc` on Linux.
- `/ostk/needles/<id>/body` — work-item bodies, addressable by needle ID (`→1612`).
- `/ostk/decisions/<key>/` — typed decisions, citation graph included.
- `/ostk/journal/stream` — live event tail.
- `/ostk/fed/<project>/` — federated read into your other ostk projects.
- `/ostk/index/` — codebase index slots.

Without FUSE the same paths resolve through the namespace API; calls and tool results agree on the layout.

**The substrate.** Five append-only logs that ARE the kernel's state, not caches of it:

- `journal.jsonl` — every event (spawns, writes, decisions, errors), signed per epoch.
- `needles/*.jsonl` — work items, tracked by ID. Needles are the unit of "what we're working on."
- `decisions.jsonl` — typed, citation-linked decisions ledger.
- `drivers.jsonl` — which drivers loaded, what they declared.
- `agents.jsonl` — live agents (status == active, pid alive).

Everything is jq-queryable. Registries are memoized projections; daemon dies → registries rebuild from these on next boot. There is no "in-memory truth" the substrate doesn't already contain.

**Identity, signed end-to-end.** A dual-signed `.primefile` keyed by your Ed25519 + GPG key plus the prime's key chain. The kernel verifies signatures at every boot. When boot confidence drops below 0.5 — signature mismatch, key revoked, ratification missing — the MCP surface collapses to `{boot, refine, help, audit}` until you ratify. Trust tiers (T0/T1/T2/T3, see below) determine who can write what.

**The governance bail.** Each release ships a signed `governance-v<VERSION>.bail` tarball containing the `HUMANFILE`, `Agentfile`, `ostk.toml`, and `pin.caps` templates, plus a GPG-signed `manifest.json` recording the source ref. `ostk init` unpacks the bail, verifies the signature, and writes per-project files with placeholder substitution (your username, GPG key, project name, kernel version). You can pack your own bails: `ostk bail pack --public` for share-able governance, `ostk bail pack` for full state encrypted to a recipient prime key.

**Crash recovery.** At every turn boundary, agents write a drain snapshot. If the daemon crashes:

1. A new daemon acquires the anchor lock.
2. `fold(audit.jsonl)` replays the audit log to reconstruct fleet state.
3. Orphaned lineages with drain snapshots rehydrate automatically.
4. Revival policy is per-agent: `revive` (auto-recover), `reap` (drop), `ask` (operator decides).

Mid-flight, the scheduler's tick loop detects crashed workers via heartbeat and hot-rehydrates them without a full daemon restart.

**Cross-platform binaries.** macOS aarch64 (Apple Silicon, codesigned + Apple-notarized) ships in two variants — the default build, and a `-fuse` build that links macFUSE for mount support. Linux x86_64 and aarch64 ship in both glibc 2.31 and musl flavors, built without FUSE (build from source with `--features fuse` if you want the mount layer on Linux). Windows x86_64. Each tarball is GPG-signed and ships an OAE.V4 BuildProvenance attestation. The Homebrew tap (`os-tack/homebrew-ostk`) is auto-updated on release.

## HUMANFILE

Your governance document. Created by `ostk init` from the v7.0.0 bail template:

```
IDENTITY scott
SIGN 7141A45868F8295E5BEB6286BAF08C963C7E3184

MODEL claude-sonnet-4-6

SECRET <<KEYS
ANTHROPIC_API_KEY
GOOGLE_API_KEY
KEYS

DRIVER fcp-rust
DRIVER fcp-screen
DRIVER fcp-web
DRIVER fcp-recall
```

Sign it. The kernel verifies HUMANFILE → `.primefile` → prime key at every boot.

## PINs — capability pins

The default pin defines what agents **can** do; the deny floor pins what they **can't**:

```
# .ostk/pins/default/pin.caps
read:    . ~/.claude/projects/ ~/.cache/ ~/.local/share/ostk/ /tmp/
write:   .ostk/ ~/.cache/ostk/ /tmp/ /workspace/
execute: shell(governed)
deny:    write-kernel modify-governance write-secret
```

`shell(governed)` is the v7 default — every shell command goes through the invariant-V capability gate. The `deny:` floor blocks kernel writes (journal, .primefile), governance edits, and SECRET-block mutation regardless of allow rules above.

## Trust tiers

ostk uses GPG for identity, not platform accounts:

| Tier | Role | How |
|---|---|---|
| **T0** | Ratifies | Dual-signed root keys; can rotate trust |
| **T1** | Writes | Cross-signed by a T0 holder; everyday governance |
| **T2** | Proposes | GPG key not yet cross-signed; reviewed before merge |
| **T3** | Public | Anonymous; read-only access to public artifacts |

The kernel's MCP surface is confidence-gated: when `boot_confidence < 0.5` (e.g., signature mismatch), only `{boot, refine, help, audit}` are reachable until you ratify.

## Verify a release

Every release is GPG-signed by the prime key in [`prime.asc`](prime.asc) and additionally carries an OAE.V4 BuildProvenance envelope. The Homebrew tap (`os-tack/homebrew-ostk`) is auto-updated on release.

```bash
gpg --import prime.asc
gpg --verify ostk-7.0.0-aarch64-apple-darwin.tar.gz.asc
shasum -a 256 -c ostk-7.0.0-aarch64-apple-darwin.tar.gz.sha256
```

Each release also publishes an `.oae.json` BuildProvenance envelope alongside the tarball; the envelope is signed by the T1-CI Ed25519 key declared in `.primefile §KEYS T1 CI`. Consumer-side OAE verification lives in `recovery.repair` (rebuild from envelopes) and `trust.attestation` (telemetry); a dedicated `ostk verify` operator verb is not in v7's CLI surface.

## The bail

A bail is a signed, portable OS package. Public bails ship `HUMANFILE`, `Agentfile`, `ostk.toml`, `pin.caps` plus a signed `manifest.json`. Full bails additionally encrypt project state to a recipient key:

```bash
ostk bail pack --public           # share-able governance bundle
ostk bail pack                    # full state, encrypted to prime key
ostk bail verify governance-v7.0.0.bail
ostk bail unpack <bail>
```

The governance bail packed at each release is at https://github.com/os-tack/ostk.ai/releases/latest. Its templates are fetched at pack time from [os-tack/haystack](https://github.com/os-tack/haystack)`@<release-tag>/templates/governance/`; a drift sentinel in haystack pins them to the v7 ABI.

## Further reading

- **Docs**: https://ostk.ai/docs
- **Kernel spec**: `docs/spec/llmos-posix-kernel.md` (10 invariants I–X, memory hierarchy, dual-CPU scheduler)
- **Substrate**: `docs/spec/llmos-observation-substrate.md` (decisions, needles, journal, registries-as-projection)
- **Bail format**: `docs/spec/bail.md`
- **ABI**: `docs/spec/cli-hierarchy.md` (Class-1 vs Class-2 verbs)

## License

AGPL-3.0. See [LICENSE](LICENSE).

The kernel is auditable infrastructure — its inspection and modification rights matter as much as its execution rights.

---

*ostk — your os + tack*
*the agents don't know this is happening. that's the design.*
