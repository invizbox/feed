# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=torcheck
PKG_VERSION:=0.0
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/torcheck

include $(INCLUDE_DIR)/package.mk

define Package/torcheck
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+tor
	TITLE:=Tor Status Check
endef

define Package/torcheck/description
	Provides the ability to report on the status of tor
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/src
	$(CP) ./src/* $(PKG_BUILD_DIR)/src/
endef

define Build/Compile
endef

define Package/torcheck/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci
	$(CP) $(PKG_BUILD_DIR)/src/*  $(1)/usr/lib/lua/luci/
endef

$(eval $(call BuildPackage,torcheck))
