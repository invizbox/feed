# Copyright (C) 2018 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=python3-six2
PKG_VERSION:=1.12.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT

PKG_SOURCE:=six-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://files.pythonhosted.org/packages/dd/bf/4138e7bfb757de47d1f4b6994648ec67a51efe58fa907c1e11e350cddfca
PKG_MD5SUM:=d16a0141ec1a18405cd4ce8b4613101da75da0e9a7aec5bdd4fa804d0e0eba73
PKG_BUILD_DIR:=$(BUILD_DIR)/six-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk
include ../../../packages/lang/python/python3-package.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	TITLE:=six is a Python 2 and 3 compatibility library
	URL:=https://github.com/benjaminp/six
	DEPENDS:=+python3-light
endef

define Package/$(PKG_NAME)/description
 six is a Python 2 and 3 compatibility library
endef

define Build/Compile
	$(call Build/Compile/Py3Mod,,install --prefix=/usr --root="$(PKG_INSTALL_DIR)")
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)$(PYTHON3_PKG_DIR)
	$(CP) \
		$(PKG_INSTALL_DIR)$(PYTHON3_PKG_DIR)/* \
		$(1)$(PYTHON3_PKG_DIR)
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
