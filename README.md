# OpenWrt snapshots for Jio Router AX6000 (JIDU6J11)

[![Build](https://github.com/SahilB69/jidu6j11-openwrt/actions/workflows/build.yml/badge.svg)](https://github.com/SahilB69/jidu6j11-openwrt/actions/workflows/build.yml)
[![Latest release](https://img.shields.io/github/v/release/SahilB69/jidu6j11-openwrt?label=latest%20snapshot)](https://github.com/SahilB69/jidu6j11-openwrt/releases/latest)

Unofficial daily OpenWrt snapshot builds for the Jio Router AX6000 (JIDU6J11, IPQ9554), covering all six SKUs. Each build adds the device support that isn't in official OpenWrt yet, a few extra patches, and a set of useful packages.

> **Unofficial build.** Not affiliated with Jio or the OpenWrt project. Snapshots are development builds and can break. Flashing firmware can brick your device, so use these images at your own risk.

## Supported SKUs

| SKUs | UART voltage |
|------|--------------|
| 6111, 6411, 6611 | 3.3 V |
| 6711, 6811, 6911 | 1.8 V |

**Flash only the image for your exact SKU.** The SKUs differ in hardware details such as Wi-Fi calibration data and UART voltage, so a wrong image can break Wi-Fi or worse. UART voltage also matters if you ever need a serial adapter for recovery.

The SKUs also differ physically, and not just in the internal hardware:

- **Wi-Fi antennas:** some SKUs have 4 antennas and others have 8.
- **Antenna design and placement:** the antennas differ in design and in where they sit in the case.
- **Heatsink:** the design and size of the heatsink vary between SKUs.

These differences affect Wi-Fi range and thermals, so keep them in mind when comparing results, and include your SKU in any report.

<!-- TODO: add which SKUs have 4 vs 8 antennas -->

<!-- TODO: how to find your SKU (where it is printed on the device) -->

## Downloads

Builds are published on the [Releases page](https://github.com/SahilB69/jidu6j11-openwrt/releases) as `snapshot-YYYYMMDD`. The last 7 daily releases are kept, and older ones are deleted automatically. Each release contains:

- **Sysupgrade images**, one per SKU. Pick the one that matches your device.
- **`initramfs-uImage.itb`**, an image that boots from RAM. Use it for a first install or for recovery.
- **`sha256sums`**, for checking that a download is intact.

GitHub also adds a "Source code" archive to every release. It only holds this repo's files (configs, scripts, patches), not OpenWrt itself.

## Installing

- **Already running OpenWrt on this device:** flash the sysupgrade image for your SKU, either in LuCI (System → Backup / Flash Firmware) or with `sysupgrade`. Back up your configuration first, because snapshots can change config formats and old settings may not carry over cleanly.
- **First install from stock firmware:** see the device-support pull request, [openwrt/openwrt#26498](https://github.com/openwrt/openwrt/pull/26498).

<!-- TODO: stock-firmware install procedure -->

## What's included

- **OpenWrt `main` with device support merged in.** The Jio AX6000 isn't in official snapshots yet, so each build merges [PR #26498](https://github.com/openwrt/openwrt/pull/26498) on top of the current `main`. This goes away once the PR is merged upstream.
- **Custom Wi-Fi board data and driver patches.** Board files in `bdf/` are copied into the `ipq-wifi` package, and ath11k patches in `patches/ath11k/` are added to the mac80211 package. These are changes that can't go upstream or aren't merged yet.
- **iwinfo [PR #51](https://github.com/openwrt/iwinfo/pull/51).** It's downloaded and applied at build time. It adds the IPQ9574 device ID.
- **Patched Wi-Fi regulatory domain.** A custom ath11k patch provides a merged FCC regulatory domain, enabling up to 30 dBm transmit power across supported 5 GHz channels and channel widths.
- **Wi-Fi enabled by default.** A `uci-defaults` script automatically enables all configured Wi-Fi radios and interfaces on first boot.
- **Extra packages.** USB storage and network support, common filesystems, VPN and traffic-shaping tools, a few LuCI apps and handy command-line tools are built into the image. The current list is in [`config/extra-packages.txt`](config/extra-packages.txt). Kernel modules that aren't in the image can't be installed later, because there is no package feed for these builds yet.

## How the builds work

- The workflow ([`.github/workflows/build.yml`](.github/workflows/build.yml)) runs daily at 02:00 IST (20:30 UTC) and can also be started by hand from the Actions tab. Tick "Build even if nothing changed" to force a build.
- It first checks whether anything changed: the OpenWrt `main` commit, the device-support PR, the iwinfo PR, or files in this repo. If not, it skips the build, so you only get a new release when there is something new.
- All six SKUs are built in a single run and published together.
- Downloads and compiler output are cached between runs to keep builds fast.

## Repository layout

```
.github/workflows/build.yml          daily build and release workflow
config/
  base.diffconfig                    target and the six device profiles
  extra-packages.txt                 extra packages, one per line
patches/
  openwrt/                           patches for the OpenWrt tree (applied with git am)
  packages/                          patches for packages from the packages feed
  ath11k/                            copied into package/kernel/mac80211/patches/ath11k
bdf/                                 board files, copied into package/firmware/ipq-wifi/src
files/                               files added to the root filesystem
feeds.conf.default.d/                extra package feeds
scripts/
  prepare.sh                         clones OpenWrt, applies PRs and patches, sets up feeds and .config
  gen-release-notes.sh               generates the release notes
```

## Customizing or forking

- **Packages:** edit `config/extra-packages.txt`. A leading `-` removes a package that would otherwise be included.
- **Patches:** add `git format-patch` files to `patches/openwrt/` (numbered, so the order is clear), or to `patches/ath11k/` for the Wi-Fi driver. Keep them with plain LF line endings: add `*.patch -text` to `.gitattributes` so Git doesn't convert them.
- **After a PR is merged upstream:** clear `PR_NUMBER` (device support) or `IWINFO_PRS` (iwinfo) at the top of `build.yml`, otherwise the patch may fail because the change is already there.
- **Local build:** run `scripts/prepare.sh` on a machine with the OpenWrt build dependencies, then `cd openwrt && make download && make -j$(nproc)`.

## Help get this merged upstream

The device support in these builds is still waiting to be merged into official OpenWrt in [PR #26498](https://github.com/openwrt/openwrt/pull/26498). If you use these images, please take a look at the PR and leave your feedback on the PR page:

- **Review it.** Comments on the code, device tree and commit messages are welcome.
- **Say if it works for you.** Mention your SKU (6111, 6411, 6611, 6711, 6811 or 6911), the build date, and what you tested.
- **Report what doesn't work.** Include the SKU, the build date and the steps to reproduce, so the problem can be traced to one variant.

Reports from more SKUs show the maintainers that the support has been tested on more than one variant, which helps the PR get merged.

## Reporting problems

Problems with these builds (packages, patches, the workflow) belong in this repo's issues. Bugs in OpenWrt itself or in the device support should be reported upstream, in the OpenWrt project or on PR #26498.

## Credits

Thanks to [@Sandiep](https://github.com/Sandiep) for his initial work and contributions on this project.

Built on [OpenWrt](https://openwrt.org/) and the work of everyone behind its ath11k, qualcommbe and iwinfo code. Patches here keep the licenses of the files they modify, mostly GPL-2.0.
