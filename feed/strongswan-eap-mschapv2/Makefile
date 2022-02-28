# Copyright (C) 2019 InvizBox Ltd.

include $(TOPDIR)/rules.mk

PKG_NAME:=strongswan-eap-mschapv2
PKG_VERSION:=1.0
PKG_RELEASE:=0

LE_CERT_FILENAME:=lets-encrypt-x3-cross-signed.pem
LE_CERT_URL:=https://letsencrypt.org/certs/
PROTONVPN_FILENAME:=ProtonVPN_ike_root.der
PROTONVPN_URL:=https://protonvpn.com/download/
SURFSHARK_URL_NAME:=ikev2
SURFSHARK_URL:=https://my.surfshark.com/vpn/api/v1/server/configurations/
SURFSHARK_FILENAME:=surfshark_ikev2.crt

include $(INCLUDE_DIR)/package.mk

define Download/letsencrypt-cert
	FILE:=$(LE_CERT_FILENAME)
	URL:=$(LE_CERT_URL)
	HASH:=skip
endef

define Download/protonvpn-cert
	FILE:=$(PROTONVPN_FILENAME)
	URL:=$(PROTONVPN_URL)
	HASH:=skip
endef

define Download/surfshark-cert
	FILE:=$(SURFSHARK_FILENAME)
	URL:=$(SURFSHARK_URL)
	URL_FILE:=$(SURFSHARK_URL_NAME)
	HASH:=skip
endef

$(eval $(call Download,letsencrypt-cert))
$(eval $(call Download,protonvpn-cert))
$(eval $(call Download,surfshark-cert))

define Package/strongswaneapmschapv2/Default
	SECTION:=invizbox
	CATEGORY:=InvizBox
	DEPENDS:=+kmod-ipsec \
		+kmod-crypto-sha256 \
		+kmod-crypto-rng \
		+kmod-crypto-wq \
		+vti \
		+kmod-ip-vti \
		+strongswan \
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

define Package/strongswaneapmschapv2/Default/description
	This package provides Strongswan with the necessary packages for IPSec for IKEv2 with EAP-MSCHAPv2 as well as the
	Let's Encrypt CA cert and the ProtonVPN ike root cert
endef

define Package/strongswan-eap-mschapv2
$(call Package/strongswaneapmschapv2/Default)
endef

define Package/strongswan-eap-mschapv2-light
$(call Package/strongswaneapmschapv2/Default)
endef

define Build/Compile
endef

define Package/strongswan-eap-mschapv2/install
	$(INSTALL_DIR) $(1)/bin/
	$(INSTALL_BIN) src/ipsec_keepalive.sh $(1)/bin/
	$(INSTALL_DIR) $(1)/etc/ssl/certs
	$(INSTALL_DIR) $(1)/etc/ipsec.d
	$(LN) /etc/ssl/certs $(1)/etc/ipsec.d/cacerts
	$(INSTALL_DATA) $(DL_DIR)/$(LE_CERT_FILENAME) $(1)/etc/ssl/certs
	$(INSTALL_DATA) $(DL_DIR)/$(PROTONVPN_FILENAME) $(1)/etc/ssl/certs
	$(INSTALL_DATA) $(DL_DIR)/$(SURFSHARK_FILENAME) $(1)/etc/ssl/certs
endef

define Package/strongswan-eap-mschapv2-light/install
	$(INSTALL_DIR) $(1)/bin/
	$(INSTALL_BIN) src/ipsec_keepalive.sh $(1)/bin/
	$(INSTALL_DIR) $(1)/etc/ssl/certs
	$(INSTALL_DIR) $(1)/etc/ipsec.d/cacerts
	$(LN) /etc/ssl/certs/DST_Root_CA_X3.crt  $(1)/etc/ipsec.d/cacerts
	$(LN) /etc/ssl/certs/ISRG_Root_X1.crt $(1)/etc/ipsec.d/cacerts
	$(INSTALL_DATA) $(DL_DIR)/$(LE_CERT_FILENAME) $(1)/etc/ssl/certs
	$(LN) /etc/ssl/certs/$(LE_CERT_FILENAME) $(1)/etc/ipsec.d/cacerts
	$(INSTALL_DATA) $(DL_DIR)/$(PROTONVPN_FILENAME) $(1)/etc/ssl/certs
	$(LN) /etc/ssl/certs/$(PROTONVPN_FILENAME) $(1)/etc/ipsec.d/cacerts
	$(INSTALL_DATA) $(DL_DIR)/$(SURFSHARK_FILENAME) $(1)/etc/ssl/certs
	$(LN) /etc/ssl/certs/$(SURFSHARK_FILENAME) $(1)/etc/ipsec.d/cacerts
endef

$(eval $(call BuildPackage,strongswan-eap-mschapv2))
$(eval $(call BuildPackage,strongswan-eap-mschapv2-light))
