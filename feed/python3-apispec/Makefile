include $(TOPDIR)/rules.mk

PKG_NAME:=python3-apispec
PKG_VERSION:=5.1.1
PKG_RELEASE:=1
PKG_LICENSE:=MIT

PYPI_NAME:=apispec
PKG_HASH:=d167890e37f14f3f26b588ff2598af35faa5c27612264ea1125509c8ff860834

include ../../../packages/lang/python/pypi.mk
include $(INCLUDE_DIR)/package.mk
include ../../../packages/lang/python/python3-package.mk

define Package/$(PKG_NAME)
	SECTION:=lang
	CATEGORY:=Languages
	SUBMENU:=Python
	TITLE:=A pluggable API specification generator (OpenAPI)
	URL:=https://github.com/marshmallow-code/apispec
	DEPENDS:=+python3-bottle2
	VARIANT:=python3
endef

define Package/$(PKG_NAME)/description
	A pluggable API specification generator (OpenAPI)
endef

$(eval $(call Py3Package,$(PKG_NAME)))
$(eval $(call BuildPackage,$(PKG_NAME)))
