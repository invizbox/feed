include $(TOPDIR)/rules.mk

PKG_NAME:=python3-ua-parser
PKG_VERSION:=0.9.0
PKG_RELEASE:=1
PKG_LICENSE:=PKG_LICENSE:=Apache-2.0

PKG_SOURCE:=ua-parser-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://files.pythonhosted.org/packages/91/f6/d574a5795c9776eb4ecf9a5f7ef191d31a89fbdf1cc3437b5d2efc26716c/
PKG_HASH:=be17242abcd4f3d11543e9b82826f152b47c724623a32bb94ce02e549b0cfce2
PKG_BUILD_DIR:=$(BUILD_DIR)/ua-parser-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk
include ../../../packages/lang/python/python3-package.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	TITLE:=Python port of Browserscope's user agent parser
	URL:=https://github.com/ua-parser/uap-python
	DEPENDS:=+python3-light +python3-yaml
endef

define Package/$(PKG_NAME)/description
	Python port of Browserscope's user agent parser
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
