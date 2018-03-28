# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=usb-automount
PKG_VERSION:=1.0
PKG_RELEASE:=0

PKG_BUILD_DIR:=$(BUILD_DIR)/usb-automount

include $(INCLUDE_DIR)/package.mk

define Package/usb-automount
	SECTION:=invizbox
	CATEGORY:=InvizBox
	TITLE:=Automount USB
	DEPENDS:=+ledcontrol +hdparm +blkid +block-mount +e2fsprogs
endef

define Package/usb-automount/description
	Provides a hotplug.d script that mounts a usb drive on insertion
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/bin
	mkdir -p $(PKG_BUILD_DIR)/src
	$(CP) ./bin/* $(PKG_BUILD_DIR)/bin/
	$(CP) ./src/* $(PKG_BUILD_DIR)/src/
endef

define Build/Compile
endef

define Package/usb-automount/install
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_DIR) $(1)/etc/hotplug.d/block
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/bin/*  $(1)/bin/
	$(CP) $(PKG_BUILD_DIR)/src/99-usb-automount.sh  $(1)/etc/hotplug.d/block/
endef

define Package/usb-automount/postinst
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
    vpn_username=$$(uci get vpn.active.username)
    vpn_password=$$(uci get vpn.active.password)
    if [[ "$${vpn_username}" != "" && "$${vpn_password}" != "" && -z $$(dd if=/dev/mtd2 bs=1 skip=65432 count=64 | grep "@invizbox") ]]; then
        echo "Storing VPN credentials to mtd as available in config and not in mtd"
        . /bin/mtdutils.ash
        write_string_to_mtd2 $${vpn_username} 64 65432
        write_string_to_mtd2 $${vpn_password} 24 65496
    fi
fi
exit 0
endef

$(eval $(call BuildPackage,usb-automount))
