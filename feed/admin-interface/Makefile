# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/version.mk

PKG_NAME:=admin-interface
PKG_VERSION:=0.4
PKG_RELEASE:=24

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+rest-api +lighttpd +netwatch2
	TITLE:=Administration Interface for InvizBox 2
endef

define Package/$(PKG_NAME)/description
	Provides an administration interface to interact with an Invizbox 2
endef

define Package/$(PKG_NAME)/conffiles
	/etc/config/admin-interface
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/
	$(CP) root/* $(1)/
	$(INSTALL_DIR) $(1)/www
	$(CP) www/* $(1)/www
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
