# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=netwatch2
PKG_VERSION:=1.1
PKG_RELEASE:=14

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default/description
	IB2 version - Monitors the network to identify changes in available networks/interfaces and modifies routing tables accordingly
endef

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+invizboxutils +ledcontrol
	TITLE:=Network Watcher for InvizBox Go and 2
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) lua/src/* $(1)/usr/lib/lua/
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) bin/* $(1)/bin/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) files/netwatch2.init $(1)/etc/init.d/netwatch2
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
