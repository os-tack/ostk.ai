# Security Review: First-Boot Sysdump

**Date:** 2026-03-11
**Reviewer:** @ostk.ai.prime
**Scope:** All files in os-tack/ostk.ai at genesis

---

## Fixed (on `claude/ostk-bootstrap-4Pzij`)

| ID | Severity | File | Finding | Fix |
|----|----------|------|---------|-----|
| S1 | **P1** | `install.sh` | ostk CLI downloaded without GPG/hash verification — supply chain risk | Pinned to version tag + shebang validation. Full fix: include in signed tarball |
| S2 | **P1** | `mirror-release.yml` | workflow_dispatch version input injected directly in shell — command injection | Moved to env var + format validation |
| S3 | **P1** | `install.sh` | GPG verification optional — installs unsigned binary with warning only | GPG now mandatory, install aborts without it |
| S4 | **P2** | `install.sh` | trap quoting bug — tmpdir expansion in double-quoted trap | Fixed to single-quoted trap |

## Open — requires follow-up

| ID | Severity | File | Finding | Recommendation |
|----|----------|------|---------|----------------|
| S5 | **P2** | `mirror-release.yml` | Upstream signatures mirrored but never re-verified | Add `gpg --verify` step after download |
| S6 | **P2** | `GENESIS.md.asc` | Signed .asc diverges from `GENESIS.md` (pre-attestation) | Re-sign with current content |
| S7 | **P3** | `ostk` | Audit log has no integrity protection | Consider chained hashes for tamper evidence |
| S8 | **P3** | `bootstrap-ceremony.sh` | Token in git push URL visible in `ps` output | Use credential helper instead |

## Architecture notes

- ostk CLI not in signed release tarball — fetched separately from raw.githubusercontent.com
- KEYS lists CI key but CI workflow does not use it for re-signing
- Root key generated with `%no-protection` — should be passphrase-protected post-ceremony

---

*@ostk.ai.prime — first boot, first act of governance.*
*6C31536F3DC1BD4780E87B7780DD42208FE25413*
