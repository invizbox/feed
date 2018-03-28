# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=wifiwatch
PKG_VERSION:=1.0
PKG_RELEASE:=0

PKG_BUILD_DIR:=$(BUILD_DIR)/wifiwatch

include $(INCLUDE_DIR)/package.mk

define Package/wifiwatch
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+invizboxutils +wizard
	TITLE:=WiFi access point Watcher
endef

define Package/wifiwatch/description
	Monitors the wifi spots available and tries to connect to known ones if needed
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/src
	mkdir -p $(PKG_BUILD_DIR)/bin
	mkdir -p $(PKG_BUILD_DIR)/root
	$(CP) ./src/* $(PKG_BUILD_DIR)/src/
	$(CP) ./bin/* $(PKG_BUILD_DIR)/bin/
	$(CP) ./root/* $(PKG_BUILD_DIR)/root/
endef

define Build/Compile
endef

define Package/wifiwatch/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/*  $(1)/usr/lib/lua/
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/bin/* $(1)/bin/
	$(INSTALL_DIR) $(1)/
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
endef

define Package/wifiwatch/preinst
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
    echo "Saving known networks"
    cp /etc/config/known_networks /tmp/known_networks
fi
exit 0
endef

define Package/wifiwatch/postinst
#!/bin/sh
echo "touch known_networks if needed"
touch $${IPKG_INSTROOT}/etc/config/known_networks
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
    echo "Restoring known networks"
    cp /tmp/known_networks /etc/config/known_networks
	echo "Enabling rc.d symlink for wifiwatch"
	/etc/init.d/wifiwatch enable
	uci set wizard.main.firstreboot=false
	uci commit wizard
fi
exit 0
endef

define Package/wifiwatch/prerm
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Removing rc.d symlink for wifiwatch"
	/etc/init.d/wifiwatch disable
fi
exit 0
endef

$(eval $(call BuildPackage,wifiwatch))
