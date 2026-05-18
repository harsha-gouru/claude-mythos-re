# Public bug atlas

Structured reading list of public patches/advisories used to infer Claude Mythos-style orchestration. This is defensive analysis only.

Last updated: 2026-05-18

## Confirmed Mythos / Anthropic-public fixes

| ID | Project | Commit | Patch | Bug class | Restored invariant | Signal |
| --- | --- | --- | --- | --- | --- | --- |
| openbsd-sack-seq-overflow | OpenBSD | `0e8206e596ad` | [`patches/openbsd-2026-sack-seq-overflow.patch`](../patches/openbsd-2026-sack-seq-overflow.patch) | integer overflow -> invalid SACK sequence accepted -> NULL deref kernel crash | reject invalid SACK ranges before list/sequence handling | Reported by Nicholas Carlini at anthropic dot com |
| openbsd-pgrp-race-uaf | OpenBSD | `443dd5519a12` | [`patches/openbsd-2026-pgrp-race-uaf.patch`](../patches/openbsd-2026-pgrp-race-uaf.patch) | stale process-group pointer copied during fork; raceable pool-cache object | start child without inherited pgrp pointer; set it late after process creation state is safe | Found by Nicholas Carlini at Anthropic; maintainer calls it a complicated AI-generated attack chain |
| ffmpeg-h264-slice-sentinel | FFmpeg | `a5696b44a6f6` | [`patches/ffmpeg-2026-h264-slice-sentinel.patch`](../patches/ffmpeg-2026-h264-slice-sentinel.patch) | 16-bit sentinel collision at 65535/0xFFFF -> heap underwrite in border exchange path | reject slice_num >= 0xFFFF so valid IDs never collide with missing sentinel | Found-by Nicholas Carlini; included in n8.1/n8.1.1 |
| ffmpeg-mpegts-iod-stack-oob | FFmpeg | `c471fce2bfa3` | [`patches/ffmpeg-2026-mpegts-iod-stack-oob.patch`](../patches/ffmpeg-2026-mpegts-iod-stack-oob.patch) | shifted output pointer with full capacity reused -> stack write beyond mp4_descr[16] | pass remaining capacity, not total capacity, across repeated descriptor parses | Found-by Nicholas Carlini; included in n8.1/n8.1.1 |
| ffmpeg-mpegts-jpegxs-uaf | FFmpeg | `42692d0f571f` | [`patches/ffmpeg-2026-mpegts-jpegxs-uaf.patch`](../patches/ffmpeg-2026-mpegts-jpegxs-uaf.patch) | early return leaves stale alias to packet buffer -> use-after-free on later cleanup/flush | route invalid JPEG-XS packet through normal cleanup instead of early-returning after ownership transfer | Found-by Nicholas Carlini; included in n8.1/n8.1.1 |
| freebsd-rpcsec-gss-stack-overflow | FreeBSD | `143293c14f8d` | [`patches/freebsd-2026-rpcsec-gss-stack-overflow.patch`](../patches/freebsd-2026-rpcsec-gss-stack-overflow.patch) | untrusted oa_length can exceed stack buffer size | check copy length against stack destination before memcpy | Reported by Nicholas Carlini <npc@anthropic.com> |
| freebsd-tty-drop-ctty-dangling-ptr | FreeBSD | `093903a8d4c0` | [`patches/freebsd-2026-tty-drop-ctty-dangling-ptr.patch`](../patches/freebsd-2026-tty-drop-ctty-dangling-ptr.patch) | detached controlling terminal leaves stale tty -> session / process group pointers | clear both sides of ownership relation during TIOCNOTTY detach | Reported by Nicholas Carlini <npc@anthropic.com> |
| freebsd-pkru-largepage | FreeBSD | `ca87c0b8e396` | [`patches/freebsd-2026-pkru-largepage.patch`](../patches/freebsd-2026-pkru-largepage.patch) | page-table traversal missed 1GB largepage / boundary-map cases | handle PG_PS at PDPE level and reject boundary-spanning PKRU requests | Reported by Nicholas Carlini <npc@anthropic.com> |
| linux-futex-requeue-flags-uaf | Linux | `19f94b390586` | [`patches/linux-2026-futex-requeue-flags-uaf.patch`](../patches/linux-2026-futex-requeue-flags-uaf.patch) | mixed futex flags create mismatched object lifetime assumptions -> UAF | sys_futex_requeue requires identical flags | Nicholas reported that his LLM found it; Reported-by Nicholas Carlini <npc@anthropic.com> |
| botan-certificate-known | Botan | `98ea259410cd` | [`patches/botan-2026-certificate-known.patch`](../patches/botan-2026-certificate-known.patch) | certificate store lookup matched DN/SKI only, not certificate bytes | exact certificate comparison before declaring a cert known/trusted | GitHub advisory credits Nick Carlini and Anthropic |
| wolfssl-cve-2026-5194-digest-oid | wolfSSL | `abce5be989cc` | [`patches/wolfssl-2026-cve-5194-digest-oid.patch`](../patches/wolfssl-2026-cve-5194-digest-oid.patch) | ECDSA signature verification accepted digest/OID combinations below key/security requirements | enforce digest size and signature OID/key OID agreement in verify paths | CVE record credits Nicholas Carlini from Anthropic; fixed in 5.9.1 |
| firefox-150-mythos-bundle | Firefox / Mozilla |  | [`patches/mozilla-mfsa2026-30.yml`](../patches/mozilla-mfsa2026-30.yml) |  | bulk browser memory-safety and logic-bug hardening; individual Bugzilla patches need separate private/public access review | Mozilla says Mythos identified 271 Firefox 150 bugs; MFSA directly credits Anthropic on CVE-2026-6746, CVE-2026-6757, CVE-2026-6758 and has rollup CVEs CVE-2026-6784/6785/6786. |

## Related public Claude / Anthropic Research fixes

| ID | Commit | Patch | Bug class | Signal |
| --- | --- | --- | --- | --- |
| openbsd-x509-depth-offbyone | `e9af5eb5a61d` | [`patches/openbsd-2026-x509-depth-offbyone.patch`](../patches/openbsd-2026-x509-depth-offbyone.patch) | max-depth off-by-one -> 4-byte heap overwrite | Calif.io with Claude and Anthropic Research |
| ffmpeg-dirac-mctmp-heap-oob | `bbdce45fda1e` | [`patches/ffmpeg-2026-dirac-mctmp-heap-oob.patch`](../patches/ffmpeg-2026-dirac-mctmp-heap-oob.patch) |  | Discovered by Claude (Anthropic), confirmed/reported by Calif.io |
| ffmpeg-assenc-parentheses | `08d7646abf95` | [`patches/ffmpeg-2026-assenc-parentheses.patch`](../patches/ffmpeg-2026-assenc-parentheses.patch) |  | Found-by Claude and Ada Logics |
| ffmpeg-boxblur-offbyone | `444f2cf047b9` | [`patches/ffmpeg-2026-boxblur-offbyone.patch`](../patches/ffmpeg-2026-boxblur-offbyone.patch) |  | Found-by Claude and Ada Logics |
| ffmpeg-g2meet-stack | `989e621bcd93` | [`patches/ffmpeg-2026-g2meet-stack.patch`](../patches/ffmpeg-2026-g2meet-stack.patch) |  | Found-by Claude and Ada Logics |
| freebsd-shm-kinfo-zero | `25cc459286a0` | [`patches/freebsd-2026-shm-kinfo-zero.patch`](../patches/freebsd-2026-shm-kinfo-zero.patch) |  | Calif.io with Claude and Anthropic Research |
| freebsd-so-splice-ktls | `d88a159da42a` | [`patches/freebsd-2026-so-splice-ktls.patch`](../patches/freebsd-2026-so-splice-ktls.patch) |  | Reported by Claude Sonnet 4.6 |
| freebsd-ip-mroute-lock-leak | `18b7115cba2f` | [`patches/freebsd-2026-ip-mroute-lock-leak.patch`](../patches/freebsd-2026-ip-mroute-lock-leak.patch) |  | Reported by Claude Opus 4.6 |
| freebsd-in-mcast-lock-leak | `bebc1a5b09e3` | [`patches/freebsd-2026-in-mcast-lock-leak.patch`](../patches/freebsd-2026-in-mcast-lock-leak.patch) |  | Reported by Claude Opus 4.6 |
| freebsd-pass-ccb-allowlist | `e1cff8549978` | [`patches/freebsd-2026-pass-ccb-allowlist.patch`](../patches/freebsd-2026-pass-ccb-allowlist.patch) |  | Assisted-by Claude Opus 4.6 |
| freebsd-cam-gdevlist-status | `3454d97aaec1` | [`patches/freebsd-2026-cam-gdevlist-status.patch`](../patches/freebsd-2026-cam-gdevlist-status.patch) |  | Assisted-by Claude Opus 4.6 |
| ghostscript-type1-mm-blend-bounds | `4e392a82d1b1` | [`patches/ghostscript-2026-type1-mm-blend-bounds.patch`](../patches/ghostscript-2026-type1-mm-blend-bounds.patch) |  | mapped from Anthropic zero-days examples via oss-security |
| opensc-strcat-cache-path | `9ab1daf21029` | [`patches/opensc-2026-strcat-cache-path.patch`](../patches/opensc-2026-strcat-cache-path.patch) |  | mapped from Anthropic zero-days examples via oss-security |
| cgif-lzw-alloc-size | `07052febd3a2` | [`patches/cgif-2026-lzw-alloc-size.patch`](../patches/cgif-2026-lzw-alloc-size.patch) |  | mapped from Anthropic zero-days examples via oss-security |

## N-day exploit-chain primitives, not Mythos discoveries

These are included because they are useful for understanding primitive graphs and chain reasoning, but the manifest marks them as not Mythos discoveries.

| ID | Commit | Patch | Bug class |
| --- | --- | --- | --- |
| linux-ipset-bitmap-range-check | `35f56c554eb1` | [`patches/linux-2024-ipset-bitmap-range-check.patch`](../patches/linux-2024-ipset-bitmap-range-check.patch) | missing range check; syzbot-reported; useful primitive in Mythos-style chain studies |
| linux-af-unix-oob-uaf | `5aa57d9f2d53` | [`patches/linux-2024-af-unix-oob-uaf.patch`](../patches/linux-2024-af-unix-oob-uaf.patch) | AF_UNIX OOB skb lifetime confusion; syzbot-reported |
| linux-qdisc-root-uaf | `2e95c4384438` | [`patches/linux-2024-qdisc-root-uaf.patch`](../patches/linux-2024-qdisc-root-uaf.patch) | qdisc hierarchy root/major-handle assumption -> dangling class pointer |

## Defensive reading order

1. `patches/ffmpeg-2026-h264-slice-sentinel.patch` - cleanest sentinel-domain failure.
2. `patches/openbsd-2026-pgrp-race-uaf.patch` - maintainer explicitly notes an AI-generated chain/race.
3. `patches/freebsd-2026-rpcsec-gss-stack-overflow.patch` - protocol length vs stack destination proof.
4. `patches/wolfssl-2026-cve-5194-digest-oid.patch` - crypto cross-field invariant enforcement.
5. `patches/mozilla-mfsa2026-30.yml` - browser-scale advisory bundle and Anthropic credits.
