#!/usr/bin/env bash
set -euo pipefail
ROOT="${ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
OUT="$ROOT/patches"
mkdir -p "$OUT"
show_patch() {
  local repo="$1" id="$2" commit="$3"
  git -C "$ROOT/sources/$repo" show --stat --patch --find-renames --find-copies "$commit" > "$OUT/$id.patch"
}
copy_blob() {
  local repo="$1" id="$2" spec="$3"
  git -C "$ROOT/sources/$repo" show "$spec" > "$OUT/$id"
}
show_patch openbsd-src openbsd-2026-sack-seq-overflow 0e8206e596add74fef1653b4472de6b3723c435f
show_patch openbsd-src openbsd-2026-x509-depth-offbyone e9af5eb5a61d189327b553b24d0d31f19c64b63f
show_patch openbsd-src openbsd-2026-pgrp-race-uaf 443dd5519a128d63a206302f7338eaef025b8076
show_patch ffmpeg-official ffmpeg-2026-h264-slice-sentinel a5696b44a6f692118f5ebf6e420f0158971e9345
show_patch ffmpeg-official ffmpeg-2026-mpegts-iod-stack-oob c471fce2bfa3d2f0e01f051b40c9a361e468226b
show_patch ffmpeg-official ffmpeg-2026-mpegts-jpegxs-uaf 42692d0f571f335174049e06c855b20340d73e6d
show_patch ffmpeg-official ffmpeg-2026-dirac-mctmp-heap-oob bbdce45fda1ef92f0a8f5a8a995dde3a79fa7acc
show_patch ffmpeg-official ffmpeg-2026-assenc-parentheses 08d7646abf956372908ad288cd08c4d894a85d6e
show_patch ffmpeg-official ffmpeg-2026-boxblur-offbyone 444f2cf047b92fac8d470f969dbd04bf1107757c
show_patch ffmpeg-official ffmpeg-2026-g2meet-stack 989e621bcd93c3c79dbfbe65710505259b8c73e9
show_patch freebsd-src freebsd-2026-rpcsec-gss-stack-overflow 143293c14f8de00c6d3de88cd23fc224e7014206
show_patch freebsd-src freebsd-2026-tty-drop-ctty-dangling-ptr 093903a8d4c05d1adff79895a52a3e3009ff07a7
show_patch freebsd-src freebsd-2026-pkru-largepage ca87c0b8e396fff01d55f1985c2556934c35a950
show_patch freebsd-src freebsd-2026-shm-kinfo-zero 25cc459286a02b646751541ccde5a33319471c73
show_patch freebsd-src freebsd-2026-so-splice-ktls d88a159da42a75dbd46ea4f6f9c8059975dab5e8
show_patch freebsd-src freebsd-2026-ip-mroute-lock-leak 18b7115cba2f698909a4801dc2cc1b04b1f4f210
show_patch freebsd-src freebsd-2026-in-mcast-lock-leak bebc1a5b09e358b420077a1b5c0f85f8e7f0812f
show_patch freebsd-src freebsd-2026-pass-ccb-allowlist e1cff854997884ed9b7251d409d9c9c7a025606d
show_patch freebsd-src freebsd-2026-cam-gdevlist-status 3454d97aaec12f4a8c676c34182200471eecae24
show_patch linux linux-2026-futex-requeue-flags-uaf 19f94b39058681dec64a10ebeb6f23fe7fc3f77a
show_patch linux linux-2024-ipset-bitmap-range-check 35f56c554eb1b56b77b3cf197a6b00922d49033d
show_patch linux linux-2024-af-unix-oob-uaf 5aa57d9f2d5311f19434d95b2a81610aa263e23b
show_patch linux linux-2024-qdisc-root-uaf 2e95c4384438adeaa772caa560244b1a2efef816
show_patch botan botan-2026-certificate-known 98ea259410cde03e9f507c29a8f8d3ee2c27cd8f
show_patch botan botan-2026-certificate-known-regression 719ef9ddfa3d760f0b6e78877a3740c64a4f84ae
show_patch wolfssl wolfssl-2026-cve-5194-digest-oid abce5be989ccd0665e2b9445abb856886975dfd1
show_patch ghostpdl ghostscript-2026-type1-mm-blend-bounds 4e392a82d1b1780cab85804728317f36a9c4f7f7
show_patch opensc opensc-2026-strcat-cache-path 9ab1daf21029dd18f8828d684ee6151d9238edab
show_patch cgif cgif-2026-lzw-alloc-size 07052febd3a252d30e6f0de67b2ea4f6b9aacddd
copy_blob mozilla-advisories mozilla-mfsa2026-30.yml HEAD:announce/2026/mfsa2026-30.yml
