# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=netwatch
PKG_VERSION:=1.2
PKG_RELEASE:=3

PKG_BUILD_DIR:=$(BUILD_DIR)/netwatch

include $(INCLUDE_DIR)/package.mk

define Package/netwatch/Default
	SECTION:=invizbox
	CATEGORY:=InvizBox
endef

define Package/netwatch/Default/description
	Monitors the network to identify changes in available networks/interfaces and modifies routing tables accordingly
endef

define Package/netwatch-base
$(call Package/netwatch/Default)
	DEPENDS:=+invizboxutils +dnsmasq +invizbox-htpdate +openvpn-openssl
	TITLE:=Network Watcher
endef

define Package/netwatch-mt7621
$(call Package/netwatch/Default)
	TITLE:=netwatch with LED for Invizbox Go
	DEPENDS:=+netwatch-base +ledcontrol-mt7621
endef

define Package/netwatch-mt7620
$(call Package/netwatch/Default)
	TITLE:=netwatch with LED for Invizbox Go
	DEPENDS:=+netwatch-base +ledcontrol-mt7620
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)/src
	mkdir -p $(PKG_BUILD_DIR)/root
	$(CP) ./src/* $(PKG_BUILD_DIR)/src/
	$(CP) ./root/* $(PKG_BUILD_DIR)/root/
endef

define Build/Compile
endef

define Package/netwatch-base/conffiles
	/etc/config/netwatch
	/etc/config/devices
endef

define Package/netwatch-base/install
	$(INSTALL_DIR) $(1)/usr/lib/lua
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/src/*  $(1)/usr/lib/lua/
	$(INSTALL_DIR) $(1)/
	$(CP) $(PKG_BUILD_DIR)/root/* $(1)/
endef

define Package/netwatch-base/preinst
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
    cp /etc/config/devices /tmp/devices
	ln -sf /tmp/resolv.conf /etc/resolv.conf
fi
exit 0
endef

define Package/netwatch-base/postinst
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

define Package/netwatch-base/prerm
#!/bin/sh
# check if we are on real system
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "Removing rc.d symlink for netwatch"
	/etc/init.d/netwatch disable
fi
exit 0
endef

$(eval $(call BuildPackage,netwatch-base))
$(eval $(call BuildPackage,netwatch-mt7620))
$(eval $(call BuildPackage,netwatch-mt7621))
