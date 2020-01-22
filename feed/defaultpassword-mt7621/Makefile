# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=defaultpassword-mt7621
PKG_VERSION:=1.0
PKG_RELEASE:=8

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+invizboxutils
	TITLE:=Default Password Setter for MT7621
endef

define Package/$(PKG_NAME)/description
	Provides the a script to set the default password from hardware after new flash for MT7621
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./uci-defaults/* $(1)/etc/uci-defaults/
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(CP) ./src/* $(1)/usr/lib/lua/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
