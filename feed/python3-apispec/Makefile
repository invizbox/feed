include $(TOPDIR)/rules.mk

PKG_NAME:=python3-apispec
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_LICENSE:=MIT

PKG_SOURCE:=apispec-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://files.pythonhosted.org/packages/67/15/346c04988dd67d36007e28145504c520491930c878b1f484a97b27a8f497/
PKG_HASH:=57a7b81fd19fff0663a7e5ffd196eaea79b5364151ed2b65533be36d55e0229c
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
