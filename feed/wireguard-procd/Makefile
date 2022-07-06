# Copyright (C) 2020 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=wireguard-procd
PKG_VERSION:=0.1
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+wireguard-tools +rng-tools
	TITLE:=Wireguard but managed using procd instead of netifd
endef

define Package/$(PKG_NAME)/description
	Wireguard but managed using procd instead of netifd
endef

define Package/$(PKG_NAME)/conffiles
	/etc/config/wireguard
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/config $(1)/etc/init.d
	$(INSTALL_CONF) files/wireguard.conf $(1)/etc/config/wireguard
	$(INSTALL_BIN) files/wireguard.init $(1)/etc/init.d/wireguard
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
