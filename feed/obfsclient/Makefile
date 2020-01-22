# Copyright (C) 2016 Invizbox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=obfsclient
PKG_VERSION:=0.0.2
PKG_RELEASE:=2
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/Yawning/obfsclient.git
PKG_SOURCE:=$(PKG_NAME).tar.gz
PKG_SOURCE_VERSION:=a7aedbc77d6714ad32c042a51334e541da8d6a41
PKG_SOURCE_SUBDIR:=$(PKG_NAME)

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

PKG_FIXUP:=autoreconf
PKG_INSTALL:=1

include $(INCLUDE_DIR)/package.mk

define Package/obfsclient
	SECTION:=net
	CATEGORY:=Network
	SUBMENU:=Web Servers/Proxies
	TITLE:=A pluggable transports proxy
	URL:=https://github.com/Yawning/obfsclient
	DEPENDS:=+libopenssl +glib2 +libstdcpp +libpthread +libevent2 +liballium
endef

define Package/obfsclient/description
 obfsclient - A C++11 obfs2/3 Tor managed pluggable transport client
 By design it will only function as a ClientTransportPlugin for Tor. It does use a reasonably complete implementation of the Pluggable Transport spec so when used properly, it will function as a drop in replacement for asn's Python implementation.
endef

define Package/obfsclient/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/obfsclient $(1)/usr/bin/
	$(INSTALL_DIR) $(1)/etc/tor
	touch $(1)/etc/tor/bridges $(1)/etc/tor/geoip $(1)/etc/tor/proxy
endef

$(eval $(call BuildPackage,obfsclient))
