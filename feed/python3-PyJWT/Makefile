# Copyright (C) 2018 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=python3-PyJWT
PKG_VERSION:=1.7.1
PKG_RELEASE:=1

PKG_LICENSE:=MIT

PKG_SOURCE:=PyJWT-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://files.pythonhosted.org/packages/2f/38/ff37a24c0243c5f45f5798bd120c0f873eeed073994133c084e1cf13b95c
PKG_HASH:=8d59a976fb773f3e6a39c85636357c4f0e242707394cadadd9814f5cbaa20e96
PKG_BUILD_DIR:=$(BUILD_DIR)/PyJWT-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk
include ../../../packages/lang/python/python3-package.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	TITLE:=PyJWT is a A Python implementation of RFC 7519.
	URL:=https://github.com/jpadilla/pyjwt
	DEPENDS:=+python3-light
endef

define Package/$(PKG_NAME)/description
 PyJWT is a A Python implementation of RFC 7519.
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
