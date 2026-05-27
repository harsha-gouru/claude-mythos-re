# Public bug atlas

Structured reading list of public patches/advisories used to infer Claude Mythos-style orchestration. This is defensive analysis only.

Last updated: 2026-05-27

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

## Mythos disclosure dashboard — revealed 2026-05-20

These 26 findings had their disclosure windows close on 2026-05-20 and were published on [red.anthropic.com/2026/cvd/](https://red.anthropic.com/2026/cvd/). Patches fetched from upstream maintainers 2026-05-27. Identifiers, severity, and bug class are authoritative from the dashboard manifest (SHA-3 `b7a0c5362...`); fix invariants are derived from the actual maintainer-authored commits.

| ID | Project | Identifier | Severity | Bug class | Patch | Fix invariant |
| --- | --- | --- | --- | --- | --- | --- |
| nginx-cve-27654-a | nginx | CVE-2026-27654 | critical | heap-buffer-overflow | [`patches/nginx-2026-27654-webdav-copy-move-path-validation.patch`](../patches/nginx-2026-27654-webdav-copy-move-path-validation.patch) | DAV COPY/MOVE handler validates source+destination resolve under configured root |
| nginx-cve-27654-b | nginx | CVE-2026-27654 | critical | arbitrary-file-write | [`patches/nginx-2026-27654-webdav-alias-destination-length.patch`](../patches/nginx-2026-27654-webdav-alias-destination-length.patch) | destination URI length check when `alias` directive is in effect; prevents alias-prefix underflow |
| jq-cve-32316 | jq | CVE-2026-32316 | medium | heap-buffer-overflow | [`patches/jq-2026-32316-jvp-string-append-overflow.patch`](../patches/jq-2026-32316-jvp-string-append-overflow.patch) | `jvp_string_append` checks `(currlen+len)*2` against `UINT32_MAX` before alloc |
| mapserver-cve-33721 | MapServer | CVE-2026-33721 | medium | heap-buffer-overflow | [`patches/mapserver-2026-33721-sld-raster-symbolizer-overflow.patch`](../patches/mapserver-2026-33721-sld-raster-symbolizer-overflow.patch) | `msSLDParseRasterSymbolizer()` bounds-checks threshold/value array before write |
| temporal-cve-5199 | temporalio/temporal | CVE-2026-5199 | critical | broken-access-control | [`patches/temporal-2026-5199-cross-namespace-batch-workflow.patch`](../patches/temporal-2026-5199-cross-namespace-batch-workflow.patch) | batch workflow handler verifies target namespace matches caller's before manipulation |
| wolfssl-cve-5446 | wolfSSL | CVE-2026-5446 | high | crypto-failure | [`patches/wolfssl-2026-5446-aria-gcm-nonce-reuse.patch`](../patches/wolfssl-2026-5446-aria-gcm-nonce-reuse.patch) | TLS 1.2 ARIA-GCM per-record IV from explicit nonce + sequence number, not session nonce |
| wolfssl-cve-5447 | wolfSSL | CVE-2026-5447 | medium | heap-buffer-overflow | [`patches/wolfssl-2026-5447-certfromx509-aki-overflow.patch`](../patches/wolfssl-2026-5447-certfromx509-aki-overflow.patch) | `CertFromX509` validates AuthorityKeyIdentifier length against dest buffer before copy |
| wolfssl-cve-5448 | wolfSSL | CVE-2026-5448 | medium | heap-buffer-overflow | [`patches/wolfssl-2026-5448-x509-notafter-notbefore-overflow.patch`](../patches/wolfssl-2026-5448-x509-notafter-notbefore-overflow.patch) | `wolfSSL_X509_notAfter/notBefore` bounds-checks ASN.1 date length before 2-byte heap write |
| wolfssl-cve-5466 | wolfSSL | CVE-2026-5466 | high | signature-bypass | [`patches/wolfssl-2026-5466-eccsi-r0-s0-forgery.patch`](../patches/wolfssl-2026-5466-eccsi-r0-s0-forgery.patch) | `wc_VerifyEccsiHash` enforces `r,s ∈ [1, q-1]` after decoding |
| wolfssl-cve-5477 | wolfSSL | CVE-2026-5477 | high | integer-overflow | [`patches/wolfssl-2026-5477-cmac-totalsz-wraparound.patch`](../patches/wolfssl-2026-5477-cmac-totalsz-wraparound.patch) | CMAC `totalSz` widened / wraparound-safe; first-block detection no longer relies on `totalSz != 0` |
| wolfssl-cve-5479 | wolfSSL | CVE-2026-5479 | high | crypto-failure | [`patches/wolfssl-2026-5479-evp-chacha20-poly1305-tag-unverified.patch`](../patches/wolfssl-2026-5479-evp-chacha20-poly1305-tag-unverified.patch) | EVP `DecryptFinal_ex` constant-time compares Poly1305 tag and fails on mismatch |
| wolfssl-cve-5500 | wolfSSL | CVE-2026-5500 | high | crypto-failure | [`patches/wolfssl-2026-5500-cms-authenveloped-gcm-tag-truncation.patch`](../patches/wolfssl-2026-5500-cms-authenveloped-gcm-tag-truncation.patch) | `wc_PKCS7_DecodeAuthEnvelopedData` rejects GCM tag length below `AES_BLOCK_SIZE` |
| wolfssl-cve-5501 | wolfSSL | CVE-2026-5501 | high | improper-cert-validation | [`patches/wolfssl-2026-5501-x509-verify-ca-false-bypass.patch`](../patches/wolfssl-2026-5501-x509-verify-ca-false-bypass.patch) | `wolfSSL_X509_verify_cert`'s `!isCa` branch fails closed instead of accepting CA:FALSE issuer |
| wolfssl-cve-5503 | wolfSSL | CVE-2026-5503 | high | heap-buffer-overflow | [`patches/wolfssl-2026-5503-ech-publicname-sni-overflow.patch`](../patches/wolfssl-2026-5503-ech-publicname-sni-overflow.patch) | `TLSX_EchChangeSNI` checks `TLSX_Find` result before mutating extensions list |
| nomad-cve-7474 | nomad | CVE-2026-7474 | critical | path-traversal | [`patches/nomad-2026-7474-host-volume-plugin-path-traversal.patch`](../patches/nomad-2026-7474-host-volume-plugin-path-traversal.patch) | `host_volume_plugin.go` constrains resolved plugin path inside configured plugin directory |
| libyang-ghsa-9f49 | libyang | GHSA-9f49-8x56-jmjc | medium | use-after-free | [`patches/libyang-2026-ghsa-9f49-metadata-list-uaf.patch`](../patches/libyang-2026-ghsa-9f49-metadata-list-uaf.patch) | `lyd_parser_set_data_flags` updates list-head pointer only when freeing actual head |
| craftcms-ghsa-cc7p | CraftCMS | GHSA-cc7p-2j3x-x7xf | high | privilege-escalation | [`patches/craftcms-2026-ghsa-cc7p-impersonate-token-privesc.patch`](../patches/craftcms-2026-ghsa-cc7p-impersonate-token-privesc.patch) | `UsersController->actionImpersonateWithToken()` verifies caller's permissions against target |
| mastodon-ghsa-chgx | mastodon | GHSA-chgx-jx3p-rf73 | high | signature-bypass | [`patches/mastodon-2026-ghsa-chgx-ld-sig-bypass.patch`](../patches/mastodon-2026-ghsa-chgx-ld-sig-bypass.patch) | `LinkedDataSignature` + `JsonLdHelper` normalize JSON-LD before signature verify |
| mastodon-ghsa-crr4 | mastodon | GHSA-crr4-7rm4-8gpw | high | ssrf | [`patches/mastodon-2026-ghsa-crr4-ssrf-ipv6-bypass.patch`](../patches/mastodon-2026-ghsa-crr4-ssrf-ipv6-bypass.patch) | `PrivateAddressCheck` includes IPv6 unspecified `::`, IPv4-mapped IPv6, and private ranges |
| gitoxide-ghsa-f26g | gitoxide | GHSA-f26g-jm89-4g65 | high | rce | [`patches/gitoxide-2026-ghsa-f26g-submodule-update-rce.patch`](../patches/gitoxide-2026-ghsa-f26g-submodule-update-rce.patch) | `gix-submodule` `update` field from `.gitmodules` strictly forbidden in `CommandForbiddenInModulesConfiguration` |
| junrar-cve-28208 | junrar | GHSA-j273-m5qq-6825 / CVE-2026-28208 | medium | path-traversal | [`patches/junrar-2026-28208-backslash-path-traversal.patch`](../patches/junrar-2026-28208-backslash-path-traversal.patch) | `LocalFolderExtractor` normalizes `\` to `/` on Linux/Unix before path-traversal check |
| freerdp-cliprdr | freerdp | GHSA-mpxh-8fq3-x8mh | high | heap-buffer-overflow | [`patches/freerdp-2026-ghsa-mpxh-cliprdr-capslen-overflow.patch`](../patches/freerdp-2026-ghsa-mpxh-cliprdr-capslen-overflow.patch) | `cliprdr_main.c` validates `capabilitySetLength` in server caps before downstream read |
| freerdp-planar | freerdp | GHSA-mvpx-xj7r-3p3r | medium | heap-buffer-overflow | [`patches/freerdp-2026-ghsa-mvpx-planar-bounds.patch`](../patches/freerdp-2026-ghsa-mvpx-planar-bounds.patch) | `libfreerdp/codec/planar.c` bounds checks around decode loop (planar.c:472) |
| freerdp-gfx | freerdp | GHSA-p6r2-4hgm-m6ff | high | heap-buffer-overflow | [`patches/freerdp-2026-ghsa-p6r2-gfx-bounds.patch`](../patches/freerdp-2026-ghsa-p6r2-gfx-bounds.patch) | `libfreerdp/gdi/gfx.c` bounds checks in surface decode (the real bug behind the ASAN interceptor frame) |
| ghost-cve-26980 | Ghost | GHSA-w52v-v783-gw97 / CVE-2026-26980 | critical | sql-injection | [`patches/ghost-2026-26980-content-api-sql-injection.patch`](../patches/ghost-2026-26980-content-api-sql-injection.patch) | Content API filter parser rejects/escapes raw SQL operators; parameterized query construction |
| imagemagick-cve-33901 | ImageMagick | GHSA-x9h5-r9v2-vcww / CVE-2026-33901 | high | heap-buffer-overflow | [`patches/imagemagick-2026-33901-mvg-pattern-overflow.patch`](../patches/imagemagick-2026-33901-mvg-pattern-overflow.patch) | MVG pattern renderer uses bounded copy + verifies token length before write |
| minio-cve-42600 | minio | GHSA-xh8f-g2qw-gcm7 / CVE-2026-42600 | medium | path-traversal | [`patches/minio-2026-42600-readmultiple-path-traversal.patch`](../patches/minio-2026-42600-readmultiple-path-traversal.patch) | `xl-storage.go` + `storage-rest-server.go` `ReadMultiple` validates msgpack-supplied paths stay in disk root |

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
