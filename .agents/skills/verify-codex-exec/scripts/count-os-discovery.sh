#!/usr/bin/env bash
# usage: count-os-discovery.sh <run-dir>
# Counts successful execve of the binaries os_info::get() spawns on Linux.
set -euo pipefail
run="${1:?usage: count-os-discovery.sh <run-dir>}"
for prog in lsb_release dpkg-query getconf; do
  n="$(cat "$run"/strace/trace.* | grep -cE "^execve\(\"[^\"]*/$prog\".* = 0$" || true)"
  echo "$prog $n"
done
