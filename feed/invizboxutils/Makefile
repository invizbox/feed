# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/version.mk

PKG_NAME:=invizboxutils
PKG_VERSION:=2.3
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/invizboxutils

include $(INCLUDE_DIR)/package.mk

define Package/invizboxutils
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+luasocket +luasec
	TITLE:=Utils needed for other packages
endef

define Package/invizboxutils/description
	Provides the a set of functions that other package need in a central place
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/bin
	mkdir -p $(PKG_BUILD_DIR)/src
	$(CP) ./bin/* $(PKG_BUILD_DIR)/bin/
	$(CP) ./src/* $(PKG_BUILD_DIR)/src/
endef

define Build/Compile
endef

define Package/invizboxutils/install
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/bin/* $(1)/bin/
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/*  $(1)/usr/lib/lua/
endef

$(eval $(call BuildPackage,invizboxutils))
