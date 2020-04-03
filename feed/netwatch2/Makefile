# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=netwatch2
PKG_VERSION:=0.2
PKG_RELEASE:=5

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default/description
	IB2 version - Monitors the network to identify changes in available networks/interfaces and modifies routing tables accordingly
endef

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+invizboxutils +ledcontrol-ib2
	TITLE:=Network Watcher for IB2
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) ./src/* $(1)/usr/lib/lua/
	$(INSTALL_DIR) $(1)/
	$(CP) ./root/* $(1)/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
