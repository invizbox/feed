#
# Copyright (C) 2015 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=python3-bottle2
PKG_VERSION:=0.12.19
PKG_RELEASE:=1

PYPI_NAME:=bottle
PKG_HASH:=a9d73ffcbc6a1345ca2d7949638db46349f5b2b77dac65d6494d45c23628da2c

include ../../../packages/lang/python/pypi.mk
include $(INCLUDE_DIR)/package.mk
include ../../../packages/lang/python/python3-package.mk

define Package/$(PKG_NAME)
	SECTION:=lang
	CATEGORY:=Languages
	SUBMENU:=Python
	TITLE:=Bottle is a fast, simple and lightweight WSGI micro web-framework for Python
	URL:=http://bottlepy.org
	DEPENDS:=+python3-light +python3-cgi +python3-urllib
endef

define Package/$(PKG_NAME)/description
 Bottle is a fast, simple and lightweight WSGI micro web-framework for Python.
 It is distributed as a single file module and has no dependencies other than the
 Python Standard Library.
endef

$(eval $(call Py3Package,$(PKG_NAME)))
$(eval $(call BuildPackage,$(PKG_NAME)))
