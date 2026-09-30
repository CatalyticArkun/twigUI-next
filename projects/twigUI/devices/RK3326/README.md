# twigUI device profile: RK3326 (BatleXP G350, MagicX XU Mini M)

A second twigUI device profile beside `RK3326S`, which stays the GKD Pixel 2's and is
untouched by this. It is the profile behind SpruceMOSS-3326 (see `SPRUCEMOSS-3326.md`
at the top of the tree), and builds under either identity:

```sh
make SpruceMOSS-3326-RK3326   # PROJECT=twigUI DISTRO=SpruceMOSS-3326 DEVICE=RK3326
make RK3326-twig              # PROJECT=twigUI DISTRO=twigUI DEVICE=RK3326
```

**Nothing here has been built or run.** It is assembled from sources that each already
support these boards; the integration is the part that is new and unproven.

## Targets

| board | dtb | notes |
|---|---|---|
| BatleXP G350 | `rk3326-batlexp-g350.dtb` | pad reports `retrogame_joypad` 484b:1101 - the identity spruce's RGB30 already maps, so its SDL map and RetroArch autoconfig apply |
| MagicX XU Mini M | `rk3326-magicx-xu-mini-m.dtb` | inherits the XU10 board; pad renamed `XU Mini M Gamepad`, product 0x0200, so it needs its own mapping |

Neither board has an internal radio: **WiFi is a USB dongle**, which is why
`ADDITIONAL_DRIVERS` carries twigUI's RTL set rather than anything in the device tree.

The other dtbs ROCKNIX ships for this SoC (R36S and clones, RGB10x, ODROID-GO, RG351x,
GameForce Chi, XU10) come along because they share the same includes and patch set. They
are **not** targets of this profile: untested here, and listed only where ROCKNIX already
listed them.

## Where each piece came from

| piece | source |
|---|---|
| device tree, 18 kernel patches, u-boot, bootloader, mali-bifrost patches | ROCKNIX's own `projects/ROCKNIX/devices/RK3326` profile, copied |
| kernel pin (mainline 7.1.2) and its `mainline` + `7.0` patch dirs | ROCKNIX's `projects/ROCKNIX/packages/linux`, mirrored into `projects/twigUI/packages/linux` so this profile builds the tree its patches were written for |
| `generic-dsi`, `device-switch`, `mali-bifrost` packages | ROCKNIX project packages, vendored under this profile's `packages/` because package lookup only searches the current project |
| USB WLAN dongle drivers, no EmulationStation, no BlueZ, no swap | twigUI's `RK3326S` profile conventions |
| G350 board facts cross-checked (3200 mAh battery, `r36s_Gamepad` pad, PWM backlight) | dArkOS/UnofficialOS's G350 work, which agree with ROCKNIX's dts |
| `rocknix,device_switch` group for these two boards | new here, following ROCKNIX's `rk3326-device-group-r36.dtsi` pattern |

ArkOS's contribution is conceptual: its panel-picker UX is the reason a *runtime* board
and panel choice matters on this hardware at all. ROCKNIX's `generic-dsi` already carries
the Mini M's twelve candidate modelines, so the panel lottery is handled in the dts rather
than by a boot-time menu.

## Card models: SD1 and SD2

Both boards have two card slots - `&sdmmc` and `&sdio`, each with its own
card-detect - because neither has an internal radio to spend the SDIO controller
on. `start_spruce.sh` therefore resolves spruce's card at boot instead of
assuming one:

| model | what it is | how it is found |
|---|---|---|
| **SD1** | the built twigUI card itself: boot + system partitions, with spruce on the card's own FAT32 partition. twig's existing model, and the only one the first run knows about. | `LABEL=TWIGUI` |
| **SD2** | a separate spruce card in the other slot - the dArkMoss/moss model. Present means preferred, so a base card can keep a throwaway payload while a full spruce card is swapped in and out. | label `SPRUCEOS` first (what dArkMoss cards use), else any partition carrying `.tmp_update/updater` |

Rules that make this safe:

- The SD2 search never looks at the disk the device booted from, so SD1 is only
  ever reached through its `TWIGUI` label. It works the same whichever slot holds
  the base card.
- A candidate is probed read-only before it is adopted, so a card that is not
  spruce's is left untouched.
- First run is unchanged: it expands and formats SD1's partition and reboots
  before any SD2 search happens.
- If SD2 is found but will not mount, the script falls back to SD1 rather than
  leaving the device with nothing.
- exFAT is a module in this kernel, so it is loaded before probing; an exFAT
  spruce card works as well as FAT32.
- The decision is logged to `/flash/spruce-card.log`.

There is deliberately no wait loop for a late-appearing SD2 card: both slots are
probed by the kernel well before `twig.service`, which runs after sway. If a
slow card ever loses the race, a bounded wait belongs here.

## Board selection

The image is ROCKNIX's RK3326 "b" image (`projects/twigUI/config.xml`): mainline u-boot
reads the board's ADC divider into `hwid_adc`, and `b_boot.ini` maps it to a dtb:

| ADC | dtb | note |
|---|---|---|
| PX30S silicon (DDR GRF check, before any ADC test) | `rk3326s-gkd-pixel2` | ROCKNIX's mainline Pixel 2 path; not a spruce target of this profile |
| 140-190 | `rk3326-powkiddy-rgb10x` | |
| 1000-1050 | `rk3326-magicx-xu-mini-m` | the same band as the XU10, which ROCKNIX's "a" image detects instead |
| 490-540 | `rk3326-batlexp-g350` | **changed here**: ROCKNIX boots its EE-clone dtb in this band |

The 490-540 band belongs to the K36 board family, which the G350 and the EE clones both
descend from; UnofficialOS's hwrev table names it "BattleXP G350 K36 Clones" and agrees
with the other two bands (xumini 1000-1050, r33s 140-190), so it samples the same ADC.
Boards the script does not name get a generated `extlinux.conf.<board>` beside
`extlinux.conf` (`extlinux.conf.eeclone`, `.xu10`, `.rgb20s`); renaming one over
`extlinux.conf` pins that board.

`device-switch` then works at runtime, from the `rocknix,device_switch` group:

```sh
device-switch --options     # g350 xumini xu10
device-switch xumini        # repoint and reboot
device-switch               # which board this image is currently set to
```

## Open items

- **Kernel and bootloader built, image not.** `scripts/build_mt linux u-boot` completes in
  `ghcr.io/rocknix/rocknix-build` (2026-09-30): all 26 kernel patches apply to 7.1.2, the
  seven `b` dtbs compile (the G350's with `this = "g350"`, the Mini M's with `this =
  "xumini"`), and u-boot produces `b_uboot.bin`, `b_boot.scr` and the generated
  `extlinux.conf.eeclone/.rgb20s/.xu10`. The host alone cannot check any of this - without
  `xmlstarlet` the config.xml lookups come back empty and a plan still "resolves".
- `glibc`'s `OPT_ENABLE_KERNEL`, `wlroots`/`sway`'s rockchip variant and
  `ffmpeg-rockchip`'s `V4L2_SUPPORT` all case on `RK3326S`/`RK3588` in the twigUI project.
  This profile deliberately takes their defaults; whether any of them should follow the
  `RK3326S` branch needs a build to answer.
- spruce itself needs platform files for both boards (`G350.cfg`, a Mini M cfg, their
  `device_functions`, PyUI device classes) and a fix for spruce's `*0xd04*` detection,
  which currently resolves every RK3326 board to `Pixel2`. See `SPRUCEMOSS-3326.md` for
  how that has to ride on twig's pinned spruce payload.
- No prebuilt spruce binary has been shown to render on RK3326; twig's own method is to
  build the emulator stack against the target GPU stack, which is what this profile does.
