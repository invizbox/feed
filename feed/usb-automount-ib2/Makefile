# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=usb-automount-ib2
PKG_VERSION:=0.0
PKG_RELEASE:=7

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	TITLE:=Automount USB
	DEPENDS:=+ledcontrol-ib2 +block-mount +invizboxutils
endef

define Package/$(PKG_NAME)/description
	Provides a hotplug.d script that mounts a usb drive on insertion
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/hotplug.d/block
	$(CP) ./src/99-usb-automount.sh $(1)/etc/hotplug.d/block/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
