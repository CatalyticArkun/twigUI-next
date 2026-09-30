# SPDX-License-Identifier: GPL-2.0-or-later

. ${ROOT}/packages/devel/libtool/package.mk

PKG_VERSION="2.5.4"
PKG_SHA256="f81f5860666b0bc7d84baddefa60d1cb9fa6fceb2398cc3baca6afaa60266675"
# The package sourced above expanded PKG_URL with its own version; re-derive it,
# or the download fetches that version under this name and fails the checksum.
PKG_URL="https://ftpmirror.gnu.org/libtool/${PKG_NAME}-${PKG_VERSION}.tar.xz"
