# Copyright (C) 2018 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=python3-PyJWT
PKG_VERSION:=2.1.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT

PYPI_NAME:=PyJWT
PKG_HASH:=fba44e7898bbca160a2b2b501f492824fc8382485d3a6f11ba5d0c1937ce6130

include ../../../packages/lang/python/pypi.mk
include $(INCLUDE_DIR)/package.mk
include ../../../packages/lang/python/python3-package.mk

define Package/$(PKG_NAME)
	SECTION:=lang
	CATEGORY:=Languages
	SUBMENU:=Python
	TITLE:=PyJWT is a A Python implementation of RFC 7519.
	URL:=https://github.com/jpadilla/pyjwt
	DEPENDS:=+python3-light
endef

define Package/$(PKG_NAME)/description
 PyJWT is a A Python implementation of RFC 7519.
endef

$(eval $(call Py3Package,$(PKG_NAME)))
$(eval $(call BuildPackage,$(PKG_NAME)))
