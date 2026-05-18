# Source links and reproduction notes

## Primary public sources

- Anthropic Mythos Preview: https://red.anthropic.com/2026/mythos-preview/
- Anthropic zero-day examples: https://red.anthropic.com/2026/zero-days/
- Mozilla Firefox 150 advisory: https://www.mozilla.org/en-US/security/advisories/mfsa2026-30/
- Mozilla announcement: https://blog.mozilla.org/en/firefox/ai-security-zero-day-vulnerabilities/
- Mozilla hardening details: https://hacks.mozilla.org/2026/05/behind-the-scenes-hardening-firefox/
- Openwall oss-security mapping for early Claude-found examples: https://www.openwall.com/lists/oss-security/2026/02/20/5
- wolfSSL security page: https://www.wolfssl.com/docs/security-vulnerabilities/
- wolfSSL PR 10131: https://github.com/wolfSSL/wolfssl/pull/10131

## Local source clone map used to extract patches

The heavyweight source repos are intentionally not committed. Recreate under `sources/` if you want to regenerate patches.

| Local dir | Upstream |
|---|---|
| `sources/openbsd-src` | `https://github.com/openbsd/src.git` |
| `sources/ffmpeg-official` | `https://git.ffmpeg.org/ffmpeg.git` |
| `sources/linux` | `https://github.com/torvalds/linux.git` |
| `sources/freebsd-src` | `https://github.com/freebsd/freebsd-src.git` |
| `sources/botan` | `https://github.com/randombit/botan.git` |
| `sources/wolfssl` | `https://github.com/wolfSSL/wolfssl.git` |
| `sources/ghostpdl` | `https://github.com/ArtifexSoftware/ghostpdl.git` |
| `sources/opensc` | `https://github.com/OpenSC/OpenSC.git` |
| `sources/cgif` | `https://github.com/dloebl/cgif.git` |
| `sources/mozilla-advisories` | `https://github.com/mozilla/foundation-security-advisories.git` |
| `sources/gecko-dev` | `https://github.com/mozilla/gecko-dev.git` |

## Regenerate patch artifacts

```bash
mkdir -p sources
# clone the repos listed above into sources/<dir>
./scripts/extract_patches.sh
```

`patches/` is committed so casual readers do not need the multi-GB source clones.
