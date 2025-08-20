# Shark Jack
## opkg fix

Per this thread, opkg needs a manual fix: https://forums.hak5.org/topic/50369-opkg-update-error/

First, use the ssh_ip_blinker payload to connect to the shark jack while it's in attack mode attached to an internet connection (aka your router not your computer).

SSH into the shark jack from its network address.

Replace all instances of `18.06-SNAPSHOT` with `18.06.9` within `/etc/opkg/disfeeds.conf`:

```conf
src/gz openwrt_core http://downloads.openwrt.org/releases/18.06.9/targets/ramips/mt76x8/packages
src/gz openwrt_base http://downloads.openwrt.org/releases/18.06.9/packages/mipsel_24kc/base
src/gz openwrt_luci http://downloads.openwrt.org/releases/18.06.9/packages/mipsel_24kc/luci
src/gz openwrt_packages http://downloads.openwrt.org/releases/18.06.9/packages/mipsel_24kc/packages
src/gz openwrt_routing http://downloads.openwrt.org/releases/18.06.9/packages/mipsel_24kc/routing
src/gz openwrt_telephony http://downloads.openwrt.org/releases/18.06.9/packages/mipsel_24kc/telephony
```

Then run:

```sh
opkg update
```

```sh
opkg install ca-bundle
opkg install ca-certificates
opkg install libustream-mbedtls
```

Rerun the updates to pull from hak5 repo now that it's fixed:

```
opkg update
```

## CURL

First, fix opkg, then run:

```sh
opkg update; opkg install libcurl curl
```
