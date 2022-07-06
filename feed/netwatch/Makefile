# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=netwatch
PKG_VERSION:=3.0
PKG_RELEASE:=6

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)/Default/description
	Monitors the network to identify changes in available networks/interfaces and modifies routing tables accordingly
endef

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+invizboxutils +dnsmasq +ledcontrol
	TITLE:=Network Watcher for InvizBox original
endef

define Package/$(PKG_NAME)/conffiles
	/etc/config/devices
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) lua/src/* $(1)/usr/lib/lua/
	$(INSTALL_DIR) $(1)/bin
	$(INSTALL_BIN) bin/* $(1)/bin/
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) files/netwatch.init $(1)/etc/init.d/netwatch
endef

define Package/$(PKG_NAME)/preinst
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
	cp /etc/config/devices /tmp/devices
fi
exit 0
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
touch $${IPKG_INSTROOT}/etc/config/devices
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Restoring known devices"
	cp /tmp/devices /etc/config/devices
	echo "Enabling rc.d symlink for netwatch"
	/etc/init.d/netwatch enable
fi
exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Removing rc.d symlink for netwatch"
	/etc/init.d/netwatch disable
fi
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
