# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/version.mk

PKG_NAME:=rest-api
PKG_VERSION:=0.4
PKG_RELEASE:=17

include $(INCLUDE_DIR)/package.mk
include ../../../packages/lang/python/python3-package.mk
include ../api-version.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+python3-bottle-jwt +lighttpd +lighttpd-mod-fastcgi +lighttpd-mod-access +lighttpd-mod-accesslog \
	+lighttpd-mod-redirect +lighttpd-mod-magnet +lighttpd-mod-rewrite +python3-flup +dropbear +ca-bundle \
	+ca-certificates +libustream-openssl +python3-logging +python3-codecs +python3-email +openssl-util \
	+python3-apispec +python3-ua-parser +fping +openvpn-openssl +logrotate +iptables +iptables-mod-conntrack-extra \
	+strongswan-eap-mschapv2 +iputils-ping
	TITLE:=REST API for InvizBox 2 management
endef

define Package/$(PKG_NAME)/description
	Provides a RESTful API to interact with an InvizBox 2
endef

define Package/$(PKG_NAME)/conffiles
	/etc/config/devices
	/etc/config/rest-api
endef

define Build/Configure
	if [ "$(PKG_VERSION).$(PKG_RELEASE)" != "$(REST_API_EXPECTED_VERSION)" ]; then \
		echo "Build error: Make sure you update the REST_API_EXPECTED_VERSION in api-version.mk and consider if your REST API has changed or not."; \
		exit 1; \
	fi
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/
	$(CP) root/* $(1)/
	$(INSTALL_DIR) $(1)/usr/lib/lua/
	$(INSTALL_BIN) ./luasrc/* $(1)/usr/lib/lua/
	$(INSTALL_DIR) $(1)/usr/lib/python3.6/site-packages/rest_api
	$(CP) ./src/* $(1)/usr/lib/python3.6/site-packages/rest_api
	$(INSTALL_DIR) $(1)/etc/dns_blacklist
	$(INSTALL_DIR) $(1)/lib/upgrade/keep.d
	$(INSTALL_DATA) files/rest-api.upgrade $(1)/lib/upgrade/keep.d/rest-api
	$(SED) 's,%V,$(API_VERSION),g' $(1)/etc/config/rest-api
	$(SED) 's,%V,$(API_VERSION),g' $(1)/etc/uci-defaults/20_rest-api
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
fi
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
