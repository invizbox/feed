include $(TOPDIR)/rules.mk

PKG_NAME:=python3-apispec
PKG_VERSION:=3.3.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT

PKG_SOURCE:=apispec-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://files.pythonhosted.org/packages/9d/cf/a8cfa99650325487ad1efa20d9a14c44de3c45c6baf291bbeab8738e2256/
PKG_HASH:=419d0564b899e182c2af50483ea074db8cb05fee60838be58bb4542095d5c08d
PKG_BUILD_DIR:=$(BUILD_DIR)/apispec-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk
include ../../../packages/lang/python/python3-package.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	TITLE:=A pluggable API specification generator (OpenAPI)
	URL:=https://github.com/marshmallow-code/apispec
	DEPENDS:=+python3-bottle2
endef

define Package/$(PKG_NAME)/description
	A pluggable API specification generator (OpenAPI)
endef

define Build/Compile
	$(call Build/Compile/Py3Mod,,install --prefix=/usr --root=$(PKG_INSTALL_DIR))
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)$(PYTHON3_PKG_DIR)
	$(CP) \
		$(PKG_INSTALL_DIR)$(PYTHON3_PKG_DIR)/* \
		$(1)$(PYTHON3_PKG_DIR)
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
