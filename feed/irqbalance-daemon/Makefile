# Copyright (C) 2019 InvizBox Ltd.

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/version.mk

PKG_NAME:=irqbalance-daemon
PKG_VERSION:=0.0
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+irqbalance
	TITLE:=irqbalance package with procd
endef

define Package/$(PKG_NAME)/description
	Provides the functionality of irqbalance package with process management from procd
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) irqbalance.init $(1)/etc/init.d/irqbalance
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
