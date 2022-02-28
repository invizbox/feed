# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/version.mk

PKG_NAME:=update
PKG_VERSION:=$(VERSION_NUMBER)
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+unzip +invizboxutils +tor-basic
	TITLE:=VPN configs, IPKs and firmware updater
endef

define Package/$(PKG_NAME)/description
	Provides the functionality required to download up to date VPN configuration are regular interval
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/update
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) lua/src/* $(1)/usr/lib/lua/
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) bin/* $(1)/bin/
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) files/update.config $(1)/etc/config/update
	$(SED) 's,%V,$(VERSION_NUMBER),g' $(1)/etc/config/update
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) uci-defaults/98_update $(1)/etc/uci-defaults/
	$(SED) 's,%V,$(VERSION_NUMBER),g' $(1)/etc/uci-defaults/98_update
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
