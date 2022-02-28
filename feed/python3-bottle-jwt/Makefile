# Copyright (C) 2018 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=python3-bottle-jwt
PKG_VERSION:=0.11
PKG_RELEASE:=3

PKG_LICENSE:=MIT

PYPI_NAME:=bottle-jwt
PKG_HASH:=20ff783802e827802a2ca12bbbf2a49e3737fcf85ab3b88c2384cee826636bfb

include ../../../packages/lang/python/pypi.mk
include $(INCLUDE_DIR)/package.mk
include ../../../packages/lang/python/python3-package.mk

PYTHON3_PKG_SETUP_ARGS:=

define Package/$(PKG_NAME)
	SECTION:=lang
	CATEGORY:=Languages
	SUBMENU:=Python
	TITLE:=bottle-jwt is a bottle plugin to handle jwt
	URL:=https://github.com/agile4you/bottle-jwt
	DEPENDS:=+python3-bottle2 +python3-PyJWT +python3-six
endef

define Package/$(PKG_NAME)/description
 bottle-jwt is a bottle plugin to handle jwt
endef

$(eval $(call Py3Package,$(PKG_NAME)))
$(eval $(call BuildPackage,$(PKG_NAME)))
