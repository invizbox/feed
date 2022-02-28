# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/version.mk

PKG_NAME:=invizboxutils
PKG_VERSION:=3.0
PKG_RELEASE:=12

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+luasocket +luasec +libiwinfo-lua +iwinfo +libubus-lua +libuci-lua +luaposix +diffutils +openvpn-openssl
	TITLE:=Utils needed for other packages
endef

define Package/$(PKG_NAME)/description
	Provides the a set of functions that other package need in a central place
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/
	$(CP) files/* $(1)/
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) lua/src/* $(1)/usr/lib/lua/
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) src/*.sh src/*.ash src/watch $(1)/bin/
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) src/15_defaultpassword $(1)/etc/uci-defaults/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
