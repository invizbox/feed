# Copyright (C) 2018 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=invizbox-htpdate
PKG_VERSION:=1.2.2
PKG_RELEASE:=1
PKG_SOURCE:=htpdate-$(PKG_VERSION).tar.xz
PKG_SOURCE_URL:=http://www.vervest.org/htp/archive/c/
PKG_HASH:=5f1f959877852abb3153fa407e8532161a7abe916aa635796ef93f8e4119f955
PKG_LICENSE:=GPL-2.0+
PKG_LICENSE_FILES:=

PKG_BUILD_DIR:=$(BUILD_DIR)/htpdate-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	TITLE:=an HTP (Hypertext Time Protocol) implementation
	URL:=http://www.vervest.com/htp/
endef

define Package/$(PKG_NAME)/description
	The HTTP Time Protocol (HTP) is used to synchronize a computer's time
	with web servers as reference time source. Htpdate will synchronize your
	computer's time by extracting timestamps from HTTP headers found
	in web server responses. Htpdate can be used as a daemon, to keep your
	computer synchronized.
endef

define Build/Configure
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/htpdate $(1)/usr/sbin/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))

