#!/usr/bin/env bash
# Print release notes (markdown) to stdout.
# Usage: HASH=<build hash> SKUS="6111 ..." scripts/gen-release-notes.sh <out-dir>
set -euo pipefail

OUT="${1:?usage: $0 <out-dir>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${HASH:?HASH is not set}"
: "${SKUS:?SKUS is not set}"

# shellcheck disable=SC1091
source "$ROOT/build-info.env"

declare -A UART=(
  [6111]="3.3 V" [6411]="3.3 V" [6611]="3.3 V"
  [6711]="1.8 V" [6811]="1.8 V" [6911]="1.8 V"
)

upstream_date="$(git -C "$ROOT/openwrt" log -1 --format=%cs "$UPSTREAM_SHA" 2>/dev/null || echo unknown)"

cat <<EOF
Unofficial OpenWrt snapshot builds for the Jio Router AX6000 (JIDU6J11). Not affiliated with Jio or the OpenWrt project.

> **Check your SKU before flashing.** Images are SKU-specific (wifi calibration and UART voltage differ). Flashing the wrong one can break wifi.

| SKU | UART | Sysupgrade image | Size |
|-----|------|------------------|------|
EOF

for sku in $SKUS; do
  f="$(find "$OUT" -maxdepth 1 -name "*-${sku}-*sysupgrade*" | head -n1)"
  if [ -n "$f" ]; then
    size="$(du -h "$f" | cut -f1)"
    echo "| $sku | ${UART[$sku]:-?} | \`$(basename "$f")\` | $size |"
  else
    echo "| $sku | ${UART[$sku]:-?} | _missing_ | - |"
  fi
done

cat <<EOF

**Base:** openwrt/openwrt \`${UPSTREAM_SHA:0:12}\` ($upstream_date)
EOF

if [ -n "$PR_NUMBER" ]; then
  echo "**Device support PR:** #$PR_NUMBER at \`${PR_SHA:0:12}\`"
fi

if [ -n "${IWINFO_PRS:-}" ]; then
  echo "**iwinfo PRs applied:** $(for n in $IWINFO_PRS; do printf '#%s ' "$n"; done)"
fi

cat <<EOF

Verify downloads with \`sha256sums\`.

Build-Hash: $HASH
EOF