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

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/bin
	mkdir -p $(PKG_BUILD_DIR)/src
	$(CP) ./bin/* $(PKG_BUILD_DIR)/bin/
	$(CP) ./src/* $(PKG_BUILD_DIR)/src/
endef

define Build/Compile
endef

define Package/update/postinst
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
    uci -c /etc set updateinfo.version.firmware=$(VERSION_NUMBER)
    uci -c /etc commit updateinfo
fi
exit 0
endef

define Package/update/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/* $(1)/usr/lib/lua/
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/bin/* $(1)/bin/
endef

$(eval $(call BuildPackage,update))
