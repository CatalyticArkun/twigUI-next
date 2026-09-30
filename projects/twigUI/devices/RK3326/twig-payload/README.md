# RK3326 spruce payload additions

twig builds spruce's card payload from a pinned spruce commit, reshaped at build time
(`projects/twigUI/packages/twig`: `install/SDCARD` overlaid, `install/delete.txt` applied,
emulators copied in). This directory adds this profile's boards on top, applied by that
package right after the emulators:

| file | what |
|---|---|
| `*.patch` | spruce-side board support, applied in order with `patch -p1` |
| `logo.bmp` | the boot logo (`/flash/logo.bmp`, shown by the initramfs): spruce's tree, 640x480. twig's own is the Pixel 2 artwork stored rotated for its portrait panel |
| `make-payload-repo.sh` | rebuilds the git repository the series is made in |

The series is made against the payload as built, not against spruce: that is what lets it
change files twig's overlay replaces. Because of that it is not a spruceOS branch, and
nothing in it has been through spruceOS's gates; carrying a board to spruce itself is a
port onto Development.

To change it:

```sh
./make-payload-repo.sh <spruceOS clone> <new dir>     # base commit + git am
# edit and commit in <new dir>, then refresh this directory:
git -C <new dir> format-patch --no-signature --zero-commit -o "$PWD" payload-base..HEAD
```

A refreshed series must still apply after a twig rebase moves the pin or the overlay; the
package stops with "does not apply to the RK3326 payload" when it does not.

| patch | board |
|---|---|
| 0001 | detection from `rocknix,device_switch/this`; twig-userspace branches take the new boards |
| 0002 | BatleXP G350 platform |
| 0003 | MagicX XU Mini M platform; the two boards' shared layer (`SpruceMOSS3326Common.cfg/.sh`, PyUI `SpruceMoss3326Device`) |
