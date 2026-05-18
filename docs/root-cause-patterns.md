# Root-cause patterns

## What the public patches suggest Mythos-like agents are good at

1. **Boundary values that collide with sentinels**
   - FFmpeg H.264: valid `slice_num` reaches `0xFFFF`, the same value used for empty table entries.
   - Defensive rule: sentinel domains must be disjoint from all legal runtime values.

2. **Capacity context lost across layered parsers**
   - FFmpeg MPEG-TS IOD: parser gets `base + count` but still believes total capacity is 16.
   - Defensive rule: APIs must take remaining capacity, not original capacity, after pointer shifting.

3. **Ownership transfer followed by early return**
   - FFmpeg JPEG-XS/MPEG-TS: buffer ownership is moved, validation returns early, stale alias remains.
   - Defensive rule: once ownership changes, all exits must pass through the normal cleanup/commit path.

4. **Lifecycle edges that leave stale back-pointers**
   - OpenBSD pgrp, FreeBSD tty: fork/detach paths copied or retained pointers after the owning relation changed.
   - Defensive rule: clear both sides of a relationship at detach; do not copy live ownership pointers into half-created objects.

5. **Max-size mismatch between protocol and local storage**
   - FreeBSD RPCSEC_GSS: protocol field length can exceed stack destination.
   - Defensive rule: every memcpy from untrusted protocol length needs a destination-size proof at the copy site.

6. **Rare architecture/page-table modes skipped by traversal code**
   - FreeBSD PKRU: 1GB pages and boundary VM entries were outside the usual path.
   - Defensive rule: page-table walkers need explicit cases for every leaf level and cross-boundary request.

7. **Semantic equality replaced by weak lookup keys**
   - Botan: certificate-known returned true for DN/SKI match without comparing the certificate.
   - Defensive rule: auth/trust decisions need exact-object or cryptographic equivalence, not metadata lookup equivalence.

8. **Crypto verify paths missing cross-field invariants**
   - wolfSSL CVE-2026-5194: digest size and signature/key OID agreement were not consistently enforced.
   - Defensive rule: signature verification must bind digest length, digest algorithm, key type, and encoded signature OID.

9. **Kernel ABI surfaces need allowlists, not blocklists**
   - FreeBSD pass(4): dangerous CCB func_codes were reachable because the filter was a negative check.
   - Defensive rule: ioctls that proxy kernel operations should allowlist safe operation families.

10. **Initialization/output status consistency**
    - FreeBSD shm and CAM: uninitialized or inconsistent output/status fields leaked state or violated wait assertions.
    - Defensive rule: zero structs at API boundaries and set completion status on every early-return path.

## How to reverse-engineer each case safely

For each patch:

1. Read the commit message first.
2. Identify the invariant restored by the fix.
3. Diff the immediate pre/post code around the patched lines.
4. Search the same subsystem for sibling code that assumes the same invariant.
5. Stop at defensive reasoning and regression-test shape; do not write weaponized PoCs.

Useful commands:

```bash
cd claude-mythos-re
less patches/ffmpeg-2026-h264-slice-sentinel.patch
git -C sources/ffmpeg-official show --word-diff a5696b44a6 -- libavcodec/h264_slice.c
git -C sources/openbsd-src show 443dd5519a1 -- sys/kern/kern_fork.c
git -C sources/freebsd-src show 143293c14f8 -- sys/rpc/rpcsec_gss/svc_rpcsec_gss.c
```

## Practical defensive scanner ideas

- Sentinel-domain checker: prove every counter/index written into a sentinel-backed array cannot equal the sentinel.
- Remaining-capacity checker: flag functions that pass shifted pointers with unshifted capacities.
- Ownership-state checker: flag early returns after ownership transfer assignments.
- Bidirectional-lifetime checker: flag detach/drop paths that clear only one side of a relation.
- Protocol-copy checker: bind every untrusted length field to the destination object size at the copy point.
- Crypto-invariant checker: enforce algorithm/key/digest/OID agreement at every signature verify boundary.
