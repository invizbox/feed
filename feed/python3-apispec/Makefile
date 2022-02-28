include $(TOPDIR)/rules.mk

PKG_NAME:=python3-apispec
PKG_VERSION:=4.0.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT

PYPI_NAME:=apispec
PKG_HASH:=360e28e5e84a4d7023b16de2b897327fe3da63ddc8e01f9165b9113b7fe1c48a

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
