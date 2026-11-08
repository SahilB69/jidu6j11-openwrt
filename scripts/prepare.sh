#!/usr/bin/env bash
# Clone OpenWrt, merge the device-support PR, apply patches, set up feeds and .config.
# Run from anywhere; works relative to the repo root.
# Env: OPENWRT_REPO, OPENWRT_BRANCH, PR_NUMBER, TARGET, SUBTARGET, EXPECTED_DEVICES
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OPENWRT_REPO="${OPENWRT_REPO:-https://github.com/openwrt/openwrt.git}"
OPENWRT_BRANCH="${OPENWRT_BRANCH:-main}"
PR_NUMBER="${PR_NUMBER:-}"
IWINFO_PRS="${IWINFO_PRS:-}"
TARGET="${TARGET:-qualcommbe}"
SUBTARGET="${SUBTARGET:-ipq95xx}"

git config --global user.name "ci"
git config --global user.email "ci@localhost"
shopt -s nullglob

echo "::group::Clone OpenWrt"
rm -rf openwrt
git clone --branch "$OPENWRT_BRANCH" "$OPENWRT_REPO" openwrt
cd openwrt
UPSTREAM_SHA="$(git rev-parse HEAD)"
PR_SHA=""
if [ -n "$PR_NUMBER" ]; then
  git fetch origin "pull/$PR_NUMBER/head"
  PR_SHA="$(git rev-parse FETCH_HEAD)"
  git merge --no-edit FETCH_HEAD
fi
cat > "$ROOT/build-info.env" <<EOF
UPSTREAM_SHA=$UPSTREAM_SHA
PR_NUMBER=$PR_NUMBER
PR_SHA=$PR_SHA
IWINFO_PRS="$IWINFO_PRS"
EOF
echo "::endgroup::"

echo "::group::Apply patches/openwrt"
for p in "$ROOT"/patches/openwrt/*.patch; do
  echo "Applying $p"
  git am --3way "$p"
done
echo "::endgroup::"

echo "::group::Copy custom BDFs"
# BDF files live in bdf/ in this repo; the ipq-wifi package expects them in src/
if [ -d "$ROOT/bdf" ]; then
  mkdir -p package/firmware/ipq-wifi/src
  cp -v "$ROOT"/bdf/* package/firmware/ipq-wifi/src/
fi
echo "::endgroup::"

echo "::group::Copy ath11k patches"
# patches/ath11k/*.patch go into the mac80211 package's ath11k patch dir
mkdir -p package/kernel/mac80211/patches/ath11k
for p in "$ROOT"/patches/ath11k/*.patch; do
  cp -v "$p" package/kernel/mac80211/patches/ath11k/
done
echo "::endgroup::"

echo "::group::Apply open iwinfo PRs"
# Downloaded as patches and dropped into the iwinfo package's patches/ dir
for n in $IWINFO_PRS; do
  mkdir -p package/network/utils/iwinfo/patches
  echo "Fetching iwinfo PR #$n"
  curl -fsSL --retry 3 "https://github.com/openwrt/iwinfo/pull/$n.patch" \
    -o "package/network/utils/iwinfo/patches/900-iwinfo-pr-$n.patch"
done
echo "::endgroup::"

# Persistent dirs restored/saved by actions/cache
mkdir -p "$ROOT/cache/dl" "$ROOT/cache/ccache"
ln -sfn "$ROOT/cache/dl" dl
ln -sfn "$ROOT/cache/ccache" .ccache
echo "max_size = 3.0G" > "$ROOT/cache/ccache/ccache.conf"

echo "::group::Feeds"
cp feeds.conf.default feeds.conf
for f in "$ROOT"/feeds.conf.default.d/*; do
  [ -f "$f" ] || continue
  echo "" >> feeds.conf
  cat "$f" >> feeds.conf
done
./scripts/feeds update -a

# Patches for packages in the main packages feed (feeds/packages is a git clone)
for p in "$ROOT"/patches/packages/*.patch; do
  echo "Applying $p to feeds/packages"
  git -C feeds/packages am --3way "$p"
done

./scripts/feeds install -a
echo "::endgroup::"

if [ -d "$ROOT/files" ]; then
  cp -r "$ROOT/files" files
fi

echo "::group::Config"
if [ ! -f "$ROOT/config/base.diffconfig" ]; then
  echo "::error::config/base.diffconfig not found - commit it to the repo (see README)"
  exit 1
fi
: > .config
cat "$ROOT/config/base.diffconfig" >> .config

# extra-packages.txt: one package per line, "#" comments allowed.
# A leading "-" removes a package (e.g. "-ppp").
if [ -f "$ROOT/config/extra-packages.txt" ]; then
  awk '
    /^[[:space:]]*(#|$)/ { next }
    {
      p = $1
      if (substr(p, 1, 1) == "-") print "# CONFIG_PACKAGE_" substr(p, 2) " is not set"
      else                        print "CONFIG_PACKAGE_" p "=y"
    }
  ' "$ROOT/config/extra-packages.txt" >> .config
fi

cat >> .config <<'EOF'
CONFIG_CCACHE=y
CONFIG_VERSION_DIST="OpenWrt (unofficial)"
EOF

make defconfig

if [ -n "${EXPECTED_DEVICES:-}" ]; then
  n=$(grep -cE "^CONFIG_TARGET_DEVICE_${TARGET}_${SUBTARGET}_DEVICE_.*=y" .config || true)
  if [ "$n" -ne "$EXPECTED_DEVICES" ]; then
    echo "::error::Expected $EXPECTED_DEVICES device profiles enabled, found $n"
    exit 1
  fi
fi
echo "::endgroup::"