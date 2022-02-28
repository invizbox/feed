# Copyright (C) 2016 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=usb-automount
PKG_VERSION:=1.1
PKG_RELEASE:=0

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	TITLE:=Automount USB
	DEPENDS:=+ledcontrol +block-mount +e2fsprogs +invizboxutils
endef

define Package/$(PKG_NAME)/description
	Provides a hotplug.d script that mounts a usb drive on insertion
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/hotplug.d/block
	$(INSTALL_DATA) src/99-usb-automount $(1)/etc/hotplug.d/block/
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
