include $(TOPDIR)/rules.mk

PKG_NAME:=python3-flup
PKG_VERSION:=1.0.3
PKG_RELEASE:=2
PKG_LICENSE:=BSD-3-Clause

PKG_SOURCE:=flup-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://pypi.python.org/packages/source/f/flup/
PKG_MD5SUM:=a64e7a6374e043480ee92534c735964e
PKG_BUILD_DIR:=$(BUILD_DIR)/flup-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk
include ../../../packages/lang/python/python3-package.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	TITLE:=Random assortment of WSGI servers
	URL:=http://www.saddi.com/software/flup/
	DEPENDS:=+python3-light
endef

define Package/$(PKG_NAME)/description
	Random assortment of WSGI servers
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
