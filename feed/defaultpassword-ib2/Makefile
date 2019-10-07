# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=defaultpassword-ib2
PKG_VERSION:=0.0
PKG_RELEASE:=2

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+invizboxutils
	TITLE:=Default Password Setter for IB2
endef

define Package/$(PKG_NAME)/description
	Provides the a script to set the default password from hardware after new flash for IB2
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./uci-defaults/* $(1)/etc/uci-defaults/
	$(INSTALL_DIR) $(1)/private
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
