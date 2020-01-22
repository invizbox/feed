# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-invizbox
PKG_VERSION:=2.1
PKG_RELEASE:=10

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+luci +luci-theme-material +luci-app-adblock +ca-bundle +ca-certificates +libustream-openssl
	TITLE:=Configuration Wizard and InvizBox pages
endef

define Package/$(PKG_NAME)/conffiles
	/etc/config/wizard
endef

define Package/$(PKG_NAME)/description
	The initial launch and configuration wizard and all the packages for an InvizBox device
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/src
	mkdir -p $(PKG_BUILD_DIR)/resources
	mkdir -p $(PKG_BUILD_DIR)/root
	$(CP) ./src/* $(PKG_BUILD_DIR)/src/
	$(CP) ./resources/* $(PKG_BUILD_DIR)/resources
	$(CP) ./root/* $(PKG_BUILD_DIR)/root/
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci
	$(CP) $(PKG_BUILD_DIR)/src/luci/* $(1)/usr/lib/lua/luci/
	$(INSTALL_DIR) $(1)/www
	$(CP) $(PKG_BUILD_DIR)/src/www/* $(1)/www/
	$(INSTALL_DIR) $(1)/
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
	$(INSTALL_DIR) $(1)/www/luci-static/js
	$(INSTALL_DIR) $(1)/www/luci-static/material
	$(CP) $(PKG_BUILD_DIR)/resources/3rdparty/js/* $(1)/www/luci-static/js
	$(CP) $(PKG_BUILD_DIR)/src/js/* $(1)/www/luci-static/js
	$(CP) $(PKG_BUILD_DIR)/resources/3rdparty/font-awesome/* $(1)/www/luci-static/material
	$(CP) $(PKG_BUILD_DIR)/resources/media/* $(1)/www/luci-static/material
endef

define Package/$(PKG_NAME)/preinst
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Saving wizard state"
	cp /etc/config/wizard /tmp/wizard
fi
exit 0
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Restoring wizard state and setting theme back to material"
	cp /tmp/wizard /etc/config/wizard
	uci set luci.themes.Material=/luci-static/material
	uci set luci.main.mediaurlbase=/luci-static/material
	uci commit luci
fi
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
