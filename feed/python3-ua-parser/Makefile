include $(TOPDIR)/rules.mk

PKG_NAME:=python3-ua-parser
PKG_VERSION:=0.10.0
PKG_RELEASE:=1
PKG_LICENSE:=PKG_LICENSE:=Apache-2.0

PYPI_NAME:=ua-parser
PKG_HASH:=47b1782ed130d890018d983fac37c2a80799d9e0b9c532e734c67cf70f185033

include ../../../packages/lang/python/pypi.mk
include $(INCLUDE_DIR)/package.mk
include ../../../packages/lang/python/python3-package.mk

define Package/$(PKG_NAME)
	SECTION:=lang
	CATEGORY:=Languages
	SUBMENU:=Python
	TITLE:=Python port of Browserscope's user agent parser
	URL:=https://github.com/ua-parser/uap-python
	DEPENDS:=+python3-light +python3-yaml
endef

define Package/$(PKG_NAME)/description
	Python port of Browserscope's user agent parser
endef

$(eval $(call Py3Package,$(PKG_NAME)))
$(eval $(call BuildPackage,$(PKG_NAME)))
