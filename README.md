# ostk

**your os + tack**

A signed, local-first OS for AI agents. Invisible infrastructure. Auditable by default.

## Install

```bash
curl -fsSL https://ostk.ai/install | sh
```

Verifies GPG signature before running. Requires: bash, curl, gpg.

## Verify

Every release is signed. Verify before you trust:

```bash
gpg --verify ostk-v1.1-aarch64-apple-darwin.tar.gz.asc
```

The signing key fingerprint is published in this repository at `KEYS`.

## Boot

```
$ ostk boot
$ ostk compile
$ ostk bench
```

## Authorize

ostk uses GPG for identity. Add your GPG key to GitHub and you're authorized:

1. Generate a key: `gpg --gen-key`
2. Export: `gpg --armor --export YOUR_KEY_ID`
3. Add to GitHub: Settings → SSH and GPG keys → New GPG key

Accounts without verified GPG keys can read but not write to OS-governed repositories.

## What is the OS?

The OS coordinates AI agents through your filesystem. Signed writes. Auditable history.
Gen counters track every edit. Hot PR resolves conflicts. The audit trail is append-only.

The agents don't know any of this is happening. That's the design.

## License

MIT. See [LICENSE](LICENSE).

---

*ostk — your os + tack*
