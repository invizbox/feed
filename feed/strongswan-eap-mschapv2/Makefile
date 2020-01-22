# Copyright (C) 2019 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=strongswan-eap-mschapv2
PKG_VERSION:=0.0
PKG_RELEASE:=1

LE_CERT_FILENAME:=lets-encrypt-x3-cross-signed.pem
LE_CERT_URL:=https://letsencrypt.org/certs/

include $(INCLUDE_DIR)/package.mk

define Download/letsencrypt-cert
	FILE:=$(LE_CERT_FILENAME)
	URL:=$(LE_CERT_URL)
	HASH:=skip
endef

$(eval $(call Download,letsencrypt-cert))

define Package/$(PKG_NAME)
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+kmod-ipsec \
		+vti \
		+kmod-ip-vti \
		+strongswan-minimal \
		+strongswan-ipsec \
		+strongswan-pki \
		+strongswan-mod-eap-mschapv2 \
		+strongswan-mod-addrblock \
		+strongswan-mod-curl \
		+strongswan-mod-pem \
		+strongswan-mod-af-alg \
		+strongswan-mod-agent \
		+strongswan-mod-curve25519 \
		+strongswan-mod-ha \
		+strongswan-mod-eap-identity \
		+strongswan-mod-eap-md5 \
		+strongswan-mod-eap-radius \
		+strongswan-mod-eap-tls \
		+strongswan-mod-md5 \
		+strongswan-mod-openssl \
		+strongswan-mod-pgp \
		+strongswan-mod-uci \
		+strongswan-mod-xauth-eap \
		+strongswan-mod-xauth-generic
		TITLE:=IPSec for IKEv2 with EAP-MSCHAPv2 and the Let's Encrypt CA cert
endef

define Package/$(PKG_NAME)/description
	This package provides Strongswan with the necessary packages for IPSec for IKEv2 with EAP-MSCHAPv2 as well as the
	Let's Encrypt CA cert
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/etc/ssl/certs
	$(INSTALL_DIR) $(1)/etc/ipsec.d
	$(LN) /etc/ssl/certs $(1)/etc/ipsec.d/cacerts
	$(INSTALL_DATA) $(DL_DIR)/$(LE_CERT_FILENAME) $(1)/etc/ssl/certs
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
