'use strict';
'require view';
'require ui';
'require rpc';
'require uci';
'require form';

const callSetPassword = rpc.declare({
	object: 'luci',
	method: 'setPassword',
	params: [ 'username', 'password' ],
	expect: { result: false }
});

const hotspot = view.extend({
	load: function(){ return Promise.all([uci.changes(), uci.load('wireless')]); },
	render: function(){
		let m, s, o;

		m = new form.Map('wireless');

		s = m.section(form.TypedSection, 'wifi-iface', 'Hotspot');
		s.anonymous = true;

		o = s.option(form.Value, 'ssid', 'Hotspot Name');
		o.datatype = 'maxlength(32)';
		o.rmempty = false;

		let passwordOption = s.option(form.Value, '_wpa_key', 'Hotspot Password', 'Minimum of 8 characters');
		passwordOption.datatype = 'wpakey';
		passwordOption.ucioption = 'key';
		passwordOption.password = true;

		o = s.option(form.Value, '_wpa_key_2', 'Confirm Password', 'This password is also used in the Administration UI');
		o.datatype = 'wpakey';
		o.ucioption = 'key';
		o.password = true;
		o.write = function(){};

		o.validate = function(section_id, value) {
			if (value !== passwordOption.formvalue(section_id)) {
				return 'Passwords do not match';
			}
			return true;
		};

		s.option(form.Flag, 'hidden', 'Hidden SSID',
			'Hide the InvizBox hotspot so that it is not broadcast to new devices.');
		s.option(form.Flag, 'isolate', 'Wireless Isolation',
			'Isolate devices on the InvizBox hotspot so that they can not communicate with eachother.');

		return m.render();
	},
	handleSaveApply: function(ev, mode) {
		return this.handleSave(ev).then(function() {
			classes.ui.changes.apply(mode == '0');
			callSetPassword('root', document.getElementById('widget.cbid.wireless.lan._wpa_key').value);
		});
	},
    handleReset: null
});
return hotspot;
