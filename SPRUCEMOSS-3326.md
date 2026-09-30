# SpruceMOSS-3326 (twig)

A spruceOS base OS for the Rockchip RK3326 handhelds, built from twigUI-next (a
ROCKNIX fork) with the conventions of the \*MOSS bases. Started 2026-09-30.
**The RK3326 kernel, device trees and u-boot build (2026-09-30); no image has been
assembled and nothing has run on hardware.**

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
| GKD Pixel 2 | `RK3326S` | twig's vendor 5.10 | fixed `fdt` (single-board image) | **works today** as twigUI; only the distro name changes. Package plan identical to twigUI's (496 steps); its payload gets no additions |
| BatleXP G350 | `RK3326` | mainline 7.1.2 (ROCKNIX's pin) | u-boot ADC band 490-540 | kernel, dtb (`this = "g350"`) and u-boot **built**; spruce platform written (payload patch 0002); unrun |
| MagicX XU Mini M | `RK3326` | mainline 7.1.2 | u-boot ADC band 1000-1050 | kernel and dtb (`this = "xumini"`) **built**; no spruce platform yet. Panel is portrait (480x640, `rotation = <90>`): twig's sway start-up rotates the UI from `fbcon/rotate`, but the early boot logo does not rotate |

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

spruce resolved every RK3326 board to `Pixel2` (the `*0xd04*` case of
`helperFunctions.sh`). Payload patch 0001 reads the board from the device tree;
the values exist only in this fork's device group, so no `OS_NAME` test is needed:

| `rocknix,device_switch/this` | spruce `PLATFORM` |
|---|---|
| `g350` | `G350` |
| `xumini` | `Pixel2` until the XU Mini M's platform exists, then `XUMiniM` |
| anything else, or no node (twigUI's own image) | `Pixel2`, unchanged |

The new boards answer to `GKD_PIXEL2` after their own name in `device_names()`
and PyUI's `get_device_names()`, the family-token pattern spruce uses for the
Anbernic XX line: they get exactly the emulators twig builds, with no Emu
`config.json` edits. `.tmp_update/updater` is left alone: it only uses the
platform to pick the Mini's startup or the Flip's session.

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

So the twig package now applies a device profile's `twig-payload/*.patch` right
after the emulator copy, and takes the profile's `logo.bmp` if it has one
(`projects/twigUI/devices/RK3326/twig-payload/README.md`). The series is made in a
git repo whose base commit is the payload as twig builds it; `make-payload-repo.sh`
rebuilds that repo from a spruceOS clone and reproduces the series exactly. It is
not a spruceOS branch and has not been through spruceOS's gates (they cover
Development, and no fleet pin covers twig's 4.4.1 line).

One more difference the G350 needed: twig's gamecontrollerdb maps the Pixel 2 by
label (GameController "a" is the printed A) but the G350's pad positionally. The
G350's cfg exports the label form for its GUID, so every GameController-based
config twig wrote for the Pixel 2 applies unchanged; raw-index configs are
translated by printed button.

## Known gaps

- **No image yet.** The RK3326 toolchain, kernel, dtbs and u-boot build in
  `ghcr.io/rocknix/rocknix-build` (`scripts/build_mt linux u-boot`, 93 packages);
  the rest of the image, the emulators included, has not been compiled. Getting
  that far took three fixes that twigUI itself needs on a clean build tree: `fbv`
  declared no init dependencies, twig's `libtool` override downloaded the wrong
  version, and gcc's libsanitizer needed ROCKNIX's patch for 7.x kernel headers.
  twig's `iwd` override has the libtool shape too (3.10 over 3.12, with 3.12's
  checksum) and is untested.
- **Updates are device-blind in the spruce half.** twig's OTA downloader takes
  the first `_update` asset of spruceUI/twigUI-next's latest release, and the EZ
  Updater extracts a `twigUI_V*.tar.gz` onto the spruce card without checking
  the device. The system half is safe - init refuses a system whose `HW_DEVICE`
  differs, and one whose file name lacks this distro's name - but by then the
  spruce card already holds the Pixel 2 payload.
- **Device-switch has no way back from the XU10.** The group lists `xu10`, but
  the XU10's own dtb carries no group node; switching to it strands the image on
  it. The XU10 is not a target.
- **advmame** on the Pixel 2 path points `SDL_GAMECONTROLLERCONFIG` at a file
  name, which SDL ignores, so the G350 falls back to the positional database
  line there.
- **No XU Mini M platform yet**, and its boot logo needs choosing by panel shape.

## RK3566 under twigUI

`make RK3566-twig` builds ROCKNIX's RK3566 profile under twigUI's own identity
(12 dtbs including the RGB30; resolves at 502 package steps). It is kept only as
the candidate to offer twigUI itself, while it is being explored whether
twigUI will take RK3566 devices. SpruceMOSS-3566 does not depend on it.
