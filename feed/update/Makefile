# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/version.mk

PKG_NAME:=update
PKG_VERSION:=$(VERSION_NUMBER)
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/update

include $(INCLUDE_DIR)/package.mk

define Package/update
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+unzip +invizboxutils +tor
	TITLE:=VPN configs, IPKs and firmware updater
endef

define Package/update/description
	Provides the functionality required to download up to date VPN configuration are regular interval
endef

define Package/update/conffiles
/etc/opkg_clearnet.conf
/etc/updateinfo
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/bin
	mkdir -p $(PKG_BUILD_DIR)/src
	mkdir -p $(PKG_BUILD_DIR)/root
	$(CP) ./bin/* $(PKG_BUILD_DIR)/bin/
	$(CP) ./src/* $(PKG_BUILD_DIR)/src/
	$(CP) ./root/* $(PKG_BUILD_DIR)/root/
endef

define Build/Compile
endef

define Package/update/postinst
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
    uci -c /etc set updateinfo.version.firmware=$(VERSION_NUMBER)
    uci -c /etc set updateinfo.onion.new_firmware=http://invizboxinobxs4f.onion/go_3.x/latest/InvizBox-Go-%s-sysupgrade.bin
    uci -c /etc set updateinfo.onion.new_firmware_sha=http://invizboxinobxs4f.onion/go_3.x/latest/InvizBox-Go-%s-sysupgrade.sha
    uci -c /etc set updateinfo.clearnet.new_firmware=http://54.194.50.97/go_3.x/latest/InvizBox-Go-%s-sysupgrade.bin
    uci -c /etc set updateinfo.clearnet.new_firmware_sha=http://54.194.50.97/go_3.x/latest/InvizBox-Go-%s-sysupgrade.sha
    uci -c /etc commit updateinfo
fi
exit 0
endef

define Package/update/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/* $(1)/usr/lib/lua/
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/bin/* $(1)/bin/
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_CONF) $(PKG_BUILD_DIR)/root/etc/* $(1)/etc/
	$(SED) 's,%V,$(VERSION_NUMBER),g' $(1)/etc/updateinfo
endef

$(eval $(call BuildPackage,update))
