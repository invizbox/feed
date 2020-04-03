# Copyright (C) 2018 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=python3-six2
PKG_VERSION:=1.14.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT

PKG_SOURCE:=six-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://files.pythonhosted.org/packages/21/9f/b251f7f8a76dec1d6651be194dfba8fb8d7781d10ab3987190de8391d08e
PKG_HASH:=236bdbdce46e6e6a3d61a337c0f8b763ca1e8717c03b369e87a7ec7ce1319c0a
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
