# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=ledcontrol
PKG_VERSION:=2.0
PKG_RELEASE:=2

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+invizboxutils
	TITLE:=LED Control
endef

define Package/$(PKG_NAME)/description
	This package provides the LED controls to set the states for the InvizBox Go and the InvizBox 2
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) bin/* $(1)/bin
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) lua/src/* $(1)/usr/lib/lua/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
