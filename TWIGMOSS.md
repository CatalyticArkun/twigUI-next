# TwigMoss

A spruceOS base OS for the Rockchip RK3326 and RK3566 handhelds, taking the
machinery of twigUI-next (a ROCKNIX fork) and the conventions of dArkMoss (a
dArkOS fork). Started 2026-09-30. **Nothing here has been built or run.**

## What it takes from each parent

| from twigUI-next / ROCKNIX | from dArkMoss |
|---|---|
| mainline kernels, per-SoC device profiles, and device trees for boards nobody else carries | the SD1/SD2 card model: base OS on one card, spruce on either |
| `device-switch`: one image ships every dtb for its SoC, the board is chosen at runtime | `OS_NAME` in `/etc/os-release` as spruce's base-OS discriminator |
| the Mali blob + Panfrost graphics stacks, and the USB WLAN dongle driver set | a thin, shared platform layer in spruce (`dArkMossCommon`) rather than per-device copies |
| the `twig` package: spruce payload overlay, systemd hand-off, image assembly | the base owning its own spruce account, card mount and update story |

`OS_NAME` comes free: `scripts/image` writes `OS_NAME="${DISTRONAME}"`, so a
TwigMoss image reports `OS_NAME="TwigMoss"` beside dArkMoss's
`OS_NAME="DARKMOSS"`, plus `HW_DEVICE="<profile>"` (RK3326, RK3326S, RK3566) and
`OS_VERSION`. That is the same shape spruce's detection already reads for
dArkMoss - no new mechanism.

Build:

```sh
make TwigMoss-RK3326     # G350, XU Mini M (and ROCKNIX's other RK3326 boards)
make TwigMoss-RK3326S    # GKD Pixel 2
make TwigMoss-RK3566     # RGB30 (and the Anbernic/Powkiddy RK3566 family)
```

`PROJECT` stays `twigUI` on purpose: the distro layer is 216 lines, while the
project carries hundreds of packages. TwigMoss is a distro identity plus device
profiles over that project, so ROCKNIX rebases keep working.

## Target devices

The spruce umbrella's RK3326 and RK3566 devices, plus the four named additions.

| device | SoC | profile | device tree | status |
|---|---|---|---|---|
| GKD Pixel 2 | RK3326S | `RK3326S` | ships (`rk3326s-gkd-pixel2.dts`) | **works today** as twigUI; TwigMoss only renames the distro. Keeps its vendor 5.10 kernel |
| BatleXP G350 | RK3326 | `RK3326` | ships (ROCKNIX) | profile assembled, unbuilt. Pad reports `retrogame_joypad` 484b:1101, the identity spruce's RGB30 already maps |
| MagicX XU Mini M | RK3326 | `RK3326` | ships (ROCKNIX) | profile assembled, unbuilt. Pad renamed, needs its own mapping. Panel is an ST7703 with twelve candidate modelines |
| Powkiddy RGB30 | RK3566 | `RK3566` | mainline + ROCKNIX's RGB30 panel patch | profile assembled, unbuilt. **Already shipping on dArkMoss** - TwigMoss is an alternative, not a rescue |
| Miniloong Pocket 1 | RK3566 | `RK3566` | **none upstream** - its dts exists only in christianhaitian's 5.10 tree | needs a mainline dts port. Shipping on dArkMoss today |
| Miyoo Flip | RK3566 | `RK3566` | **none** - no `miyoo` reference anywhere in this tree | needs a dts *and* the SPI-NAND preloader patch: its boot ROM never reads the SD card |

Free with the RK3566 profile, and new to spruce: the Anbernic RG353P/PS/V/VS/X,
RG503, RG Arc, and Powkiddy RGB10 Max 3, RGB20 Pro and RK2023.

## Card model

`start_spruce.sh` resolves spruce's card at boot, because these boards have two
slots:

- **SD1** - the built card itself, spruce on its own FAT32 partition
  (`LABEL=TWIGUI`). The default, and the only model first boot knows.
- **SD2** - a separate spruce card in the other slot, the dArkMoss/moss model.
  Present means preferred. Found by the `SPRUCEOS` label or by carrying
  `.tmp_update/updater`.

dArkMoss reached the same contract independently and on the same day
(`f6c1969` dropped its own label requirement for content detection), so the
three \*MOSS bases agree here. oakMOSS is the next one to align.

## Board identity for spruce

spruce resolves RK3566 boards from an os-release stamp and still resolves
*every* RK3326 board to `Pixel2` (`helperFunctions.sh`, the `*0xd04*` case).
TwigMoss does not need a new stamp: `device-switch` already publishes the board
in the device tree at `rocknix,device_switch/this` (`g350`, `xumini`, ...), which
this fork's `rk3326-device-group-twig.dtsi` sets. So spruce's fix is to read
`OS_NAME` plus that node, and the mapping is:

| `OS_NAME` | board | spruce `PLATFORM` |
|---|---|---|
| `TwigMoss` | `g350` | `G350` (new) |
| `TwigMoss` | `xumini` | `XUMiniM` (new) |
| `TwigMoss` | Pixel 2 | `Pixel2` (exists) |
| `TwigMoss` | RGB30 | `RGB30` (exists) |

## Deliberately not done yet

- **No build.** Every profile here is reasoned from the build system's lookup
  rules, not from a successful run.
- **No update payload.** dArkMoss's `.dmupd` flow is worth copying, but it keys
  off a GPT layout with a named `resource` partition; twig images are not
  partitioned that way.
- **No spruce platform files.** `G350.cfg`, an XU Mini M cfg, their device
  functions and PyUI classes all belong in spruceOS. Use its existing
  `devices/rocknix/rocknix_device.py` as the PyUI parent, not the `gkd` classes:
  twig already ships a forked copy of those (NetworkManager, where spruce's
  in-tree Pixel 2 is ConnMan), and a second fork is not wanted.
- **No shared spruce-side layer yet.** A `twigMossCommon` cannot span the Pixel 2
  and the new boards blindly: the Pixel 2 profile is a vendor 5.10 kernel, the
  others mainline. Split it by SoC family, or move the Pixel 2 to mainline first
  (ROCKNIX carries its dts) as a separate, testable decision.
- **oakMOSS alignment** comes after the first TwigMoss board boots, so what gets
  carried over is measured rather than assumed.
