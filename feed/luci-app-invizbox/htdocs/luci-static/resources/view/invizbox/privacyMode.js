'use strict';
'require view';
'require fs';
'require ui';
'require rpc';
'require uci';
'require form';

const privacyMode = view.extend({
	load: function(){ Promise.all([uci.changes(), uci.load('vpn')]); },
	render: function(){
		let m, s, o;

		m = new form.Map('vpn');
		m.chain('ipsec');
		m.chain('openvpn');
		m.chain('tor');

		s = m.section(form.NamedSection, 'active', 'vpn', 'Privacy Mode');

		o = s.option(form.ListValue, 'mode', 'Privacy Mode', 'Select the Privacy Mode for your InvizBox.');
		o.value('vpn', 'VPN');
		o.value('tor', 'Tor');
		o.value('extend', 'WiFi Extender');
		o.widget = 'radio';

		return m.render();
	},
	handleSaveApply: function(ev, mode) {
		return this.handleSave(ev).then(function() {
			const privacyMode = document.querySelector('input[name="cbid.vpn.active.mode"]:checked').value;
			const currentProtocolId = uci.get('vpn', 'active', 'protocol_id');
			const currentProtocol = currentProtocolId && uci.get('vpn', currentProtocolId, 'vpn_protocol') || '';
			if (privacyMode === 'vpn') {
				if (currentProtocol === 'OpenVPN') {
					uci.set('ipsec', 'general', 'enabled', '0');
					uci.set('ipsec', 'vpn_1', 'enabled', '0');
					uci.set('openvpn', 'vpn_1', 'enabled', '1');
				} else {
					uci.set('ipsec', 'general', 'enabled', '1');
					uci.set('ipsec', 'vpn_1', 'enabled', '1');
					uci.set('openvpn', 'vpn_1', 'enabled', '0');
				}
				uci.set('tor', 'tor', 'enabled', '0');
			} else {
				uci.set('ipsec', 'general', 'enabled', '0');
				uci.set('ipsec', 'vpn_1', 'enabled', '0');
				uci.set('openvpn', 'vpn_1', 'enabled', '0');
				uci.set('tor', 'tor', 'enabled', '1');
			}
      uci.save();
      function displayError(){ classes.ui.changes.displayStatus('warning',
					E('p', 'Something went wrong applying the configuration changes…')); }
			classes.ui.changes.displayStatus('notice spinning', E('p', 'Applying configuration changes…'));
			uci.apply().then(function(){
				Promise.all([
					fs.exec_direct('/etc/init.d/tor', [ 'restart' ]),
					fs.exec_direct('/usr/lib/lua/luci/apply_vpn_config.lua')
				]).then(function(){
					classes.ui.changes.confirm(mode == '0', Date.now() + L.env.apply_rollback * 1000);
				}, displayError);
			}, displayError);
		});
	},
  handleReset: null
});
return privacyMode;
