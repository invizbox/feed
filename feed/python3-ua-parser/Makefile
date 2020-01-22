include $(TOPDIR)/rules.mk

PKG_NAME:=python3-ua-parser
PKG_VERSION:=0.8.0
PKG_RELEASE:=1
PKG_LICENSE:=PKG_LICENSE:=Apache-2.0

PKG_SOURCE:=ua-parser-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://pypi.python.org/packages/b0/02/94ea43fc432fb112fbb62a89855317c41c210fb5239a2ed9b94ecb63024f/
PKG_MD5SUM:=b73c5a86783e444afa2788075dddf48a
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
