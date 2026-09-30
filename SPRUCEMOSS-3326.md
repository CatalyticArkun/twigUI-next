# SpruceMOSS-3326 (twig)

A spruceOS base OS for the Rockchip RK3326 handhelds, built from twigUI-next (a
ROCKNIX fork) with the conventions of the \*MOSS bases. Started 2026-09-30.
**Nothing here has been built or run.**

Its RK3566 sibling is **SpruceMOSS-3566 (dark)**: the dArkMoss lineage
(spruceUI/dArkMoss, from dArkOS), for the RGB30, Miniloong Pocket 1 and Miyoo
Flip. It does not live in this repository.

## What it takes from each side

| from twigUI-next / ROCKNIX | from the \*MOSS bases (dArkMoss, oakMOSS) |
|---|---|
| mainline kernels, per-SoC device profiles, and device trees for boards nobody else carries | the SD1/SD2 card model: base OS on one card, spruce on either |
| one image per SoC, the board chosen at boot (u-boot ADC detection, `device-switch`) | `OS_NAME` in `/etc/os-release` as spruce's base-OS discriminator |
| the Mali blob + Panfrost graphics stacks, and the USB WLAN dongle driver set | a thin platform layer in spruce rather than per-device copies |
| the `twig` package: spruce payload, systemd hand-off, image assembly | the base owning its own card mount and update story |

`OS_NAME` comes free: `scripts/image` writes `OS_NAME="${DISTRONAME}"`, so these
images report `OS_NAME="SpruceMOSS-3326"`, plus `HW_DEVICE` (`RK3326` or
`RK3326S`) and `OS_VERSION`. `PROJECT` stays `twigUI` on purpose: the distro
layer is 216 lines, while the project carries hundreds of packages, so ROCKNIX
and twigUI rebases keep working.

```sh
make SpruceMOSS-3326-RK3326     # BatleXP G350, MagicX XU Mini M
make SpruceMOSS-3326-RK3326S    # GKD Pixel 2 (twigUI's own profile, renamed)
```

Both run an `arm` pass before `aarch64`, like twigUI's `RK3326S` target:
`ENABLE_32BIT` defaults to true in the distro.

## Devices

| device | profile | kernel | how the board is chosen | status |
|---|---|---|---|---|
| GKD Pixel 2 | `RK3326S` | twig's vendor 5.10 | fixed `fdt` (single-board image) | **works today** as twigUI; only the distro name changes. Package plan identical to twigUI's (496 steps) |
| BatleXP G350 | `RK3326` | mainline 7.1.2 (ROCKNIX's pin) | u-boot ADC band 490-540 | profile assembled and resolved (501 steps), unbuilt |
| MagicX XU Mini M | `RK3326` | mainline 7.1.2 | u-boot ADC band 1000-1050 | profile assembled and resolved, unbuilt |

The RK3326 image is ROCKNIX's "b" image: mainline u-boot, which exports the
board's ADC reading as `hwid_adc`, and `b_boot.ini`, which maps it to a dtb. Two
facts about that mapping:

- The **G350's band (490-540) is shared with the EE clones** - both descend from
  the K36 board, and UnofficialOS's hwrev table names the band "BattleXP G350 K36
  Clones". ROCKNIX boots the EE-clone dtb there; this image boots the G350's.
  EE-clone owners get `extlinux.conf.eeclone`, which the u-boot package
  generates for every dtb the boot script does not name.
- The **Pixel 2 also boots this image**: `b_boot.ini` detects PX30S silicon from a
  DDR GRF register before any ADC check. That is ROCKNIX's mainline Pixel 2
  path, not a spruce target here - spruce's Pixel 2 support expects the
  `RK3326S` image's binaries.

`device-switch` covers the rest at runtime. `rk3326-device-group-twig.dtsi`
groups `g350`, `xumini` and `xu10`, and each board's dts sets
`rocknix,device_switch/this`, so a running system can name its board without a
new os-release stamp.

## Card model

`start_spruce.sh` resolves spruce's card at boot:

- **SD1** - the built card itself, spruce on its own FAT32 partition
  (`LABEL=TWIGUI`). The default, and the only model first boot knows.
- **SD2** - a separate spruce card in the other slot, the dArkMoss/oakMOSS model.
  Present means preferred. Found by the `SPRUCEOS` label or by carrying
  `.tmp_update/updater`.

The G350 and XU Mini M have two card slots (`&sdmmc` and `&sdio`, both with
card-detect: neither has an internal radio). The Pixel 2 has one, so it is SD1
only and the SD2 search finds nothing. dArkMoss reached the same contract
independently (`f6c1969` detects the spruce card by content, not label).

## Board identity for spruce

spruce resolves every RK3326 board to `Pixel2` (the `*0xd04*` case of
`helperFunctions.sh`, and the same line in `.tmp_update/updater`). The fix
reads `OS_NAME`, then the board:

| `OS_NAME` | `rocknix,device_switch/this` | spruce `PLATFORM` |
|---|---|---|
| `SpruceMOSS-3326` or `twigUI` | `g350` | `G350` (new) |
| `SpruceMOSS-3326` or `twigUI` | `xumini` | `XUMiniM` (new) |
| anything else, or no node | - | `Pixel2` (unchanged) |

## The spruce payload

twig pins a spruce release (`c104be3fd`, spruce 4.4.1) and reshapes it at build
time: whole-file replacements from `install/SDCARD`, then `install/delete.txt`
(which strips every other platform's files), then the emulators it builds from
source, renamed for the Pixel 2 (`ra64.pixel2`, `PPSSPPSDL_Pixel2`,
`OpenBOR_Pixel2`, `lib64_Pixel2_trngaje`). SpruceMOSS-3326 keeps the same pin, so
twig's overlay stays valid. Consequences for the new boards:

- spruce names those binaries directly in nine lines (the `button_actions.sh`
  kill lists, `save_poweroff.sh`, the Pixel 2 platform and device functions,
  the drastic and OpenBOR launch paths), and branches on `PLATFORM` being
  `Pixel2` in about thirty places, from the emulator launchers to USB storage
  mode and PyUI's device factory.
- Board additions have to land **after** twig's overlay, delete list and
  emulator copy: the delete list would remove a new board's RetroArch config,
  and the overlay replaces files (`App/PortMaster/launch.sh`, for one, sets
  `PYSDL2_DLL_PATH` for `Pixel2` only).

## Known gaps

- **Never built.** Package plans resolve in `ghcr.io/rocknix/rocknix-build`; no
  compiler has run.
- **Updates are device-blind in the spruce half.** twig's OTA downloader takes
  the first `_update` asset of spruceUI/twigUI-next's latest release, and the EZ
  Updater extracts a `twigUI_V*.tar.gz` onto the spruce card without checking
  the device. The system half is safe - init refuses a system whose `HW_DEVICE`
  differs, and one whose file name lacks this distro's name - but by then the
  spruce card already holds the Pixel 2 payload.
- **Wi-Fi regulatory database.** ROCKNIX now builds `regulatory.db` into kernels
  with a built-in cfg80211, or the radio stays in world domain 00 (5 GHz
  no-IR). twigUI's `linux` package predates that change.
- **No platform files yet** for the G350 or the XU Mini M, in spruce or here.

## RK3566 under twigUI

`make RK3566-twig` builds ROCKNIX's RK3566 profile under twigUI's own identity
(12 dtbs including the RGB30; resolves at 502 package steps). It is kept only as
the candidate to offer twigUI itself, while it is being explored whether
twigUI will take RK3566 devices. SpruceMOSS-3566 does not depend on it.
