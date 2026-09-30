# twigUI device profile: RK3326 (BatleXP G350, MagicX XU Mini M)

A second twigUI device profile beside `RK3326S`, which stays the GKD Pixel 2's and is
untouched by this. Build it with:

```sh
make RK3326-twig      # PROJECT=twigUI DISTRO=twigUI DEVICE=RK3326 ARCH=aarch64
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

## Board selection

One image ships every dtb. `device-switch` rewrites extlinux's `FDT` line from the
`rocknix,device_switch` node, so:

```sh
device-switch --options     # g350 xumini xu10 (plus the R36 family on its own boards)
device-switch xumini        # repoint and reboot
device-switch               # which board this image is currently set to
```

UnofficialOS goes further and picks the board *automatically* in u-boot from an ADC
divider (G350 at 490-540, XU Mini M at 1000-1050, per its `001-set-hwrev.patch`). That is
the obvious next step if swapping a card between these two boards becomes routine; it is
deliberately not done here, because it means patching u-boot rather than shipping a dts.

## Open items

- **Never built.** The kernel case, patch dirs and vendored packages are reasoned from the
  build system's own lookup rules, not from a successful run.
- `glibc`'s `OPT_ENABLE_KERNEL`, `wlroots`/`sway`'s rockchip variant and
  `ffmpeg-rockchip`'s `V4L2_SUPPORT` all case on `RK3326S`/`RK3588` in the twigUI project.
  This profile deliberately takes their defaults; whether any of them should follow the
  `RK3326S` branch needs a build to answer.
- spruce itself needs platform files for both boards (`G350.cfg`, a Mini M cfg, their
  `device_functions`, PyUI device classes) and a fix for spruce's `*0xd04*` detection,
  which currently resolves every RK3326 board to `Pixel2`. That work lives in spruceOS,
  not here.
- No prebuilt spruce binary has been shown to render on RK3326; twig's own method is to
  build the emulator stack against the target GPU stack, which is what this profile does.
