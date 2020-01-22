# Copyright (C) 2018 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=python3-bottle-jwt
PKG_VERSION:=0.11
PKG_RELEASE:=2

PKG_LICENSE:=MIT

PKG_SOURCE:=bottle-jwt-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://pypi.python.org/packages/bd/e0/4b9625119a11b5197f6212e4e7ac3a8b06b98343cd75e7db5f654b453854
PKG_MD5SUM:=72e1203a69a817e30a3c3dc3e146b145
PKG_BUILD_DIR:=$(BUILD_DIR)/bottle-jwt-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk
include ../../../packages/lang/python/python3-package.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	TITLE:=bottle-jwt is a bottle plugin to handle jwt
	URL:=https://github.com/agile4you/bottle-jwt
	DEPENDS:=+python3-bottle2 +python3-PyJWT +python3-six2
endef

define Package/$(PKG_NAME)/description
 bottle-jwt is a bottle plugin to handle jwt
endef

define Build/Compile
	$(call Build/Compile/Py3Mod,,install --prefix=/usr --root="$(PKG_INSTALL_DIR)")
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)$(PYTHON3_PKG_DIR)
	$(CP) \
		$(PKG_INSTALL_DIR)$(PYTHON3_PKG_DIR)/* \
		$(1)$(PYTHON3_PKG_DIR)
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
