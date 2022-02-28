# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-invizbox
PKG_VERSION:=3.1
PKG_RELEASE:=3

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+luci +luci-theme-material +luci-app-adblock +ca-bundle +ca-certificates +libustream-wolfssl +ip-tiny \
	+invizboxutils +strongswan-eap-mschapv2-light
	TITLE:=InvizBox pages
endef

define Package/$(PKG_NAME)/conffiles
	/etc/config/dns
endef

define Package/$(PKG_NAME)/description
	The InvizBox LuCI app for the InvizBox original interface
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) config/* $(1)/etc/config
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/invizbox
	$(INSTALL_DATA) htdocs/luci-static/resources/view/invizbox/* $(1)/www/luci-static/resources/view/invizbox
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DATA) root/usr/share/luci/menu.d/* $(1)/usr/share/luci/menu.d
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DATA) root/usr/share/rpcd/acl.d/* $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DIR) $(1)/www/luci-static/css
	$(INSTALL_DATA) src/css/* $(1)/www/luci-static/css
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci
	$(INSTALL_BIN) src/lua/* $(1)/usr/lib/lua/luci
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) src/sh/* $(1)/bin/
	$(INSTALL_DIR) $(1)/www/luci-static/material
	$(INSTALL_DATA) media/* $(1)/www/luci-static/material
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Setting theme back to material"
	uci set luci.themes.Material=/luci-static/material
	uci set luci.main.mediaurlbase=/luci-static/material
	uci commit luci
fi
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
