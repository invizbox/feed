'use strict';
'require view';
'require fs';
'require ui';
'require rpc';
'require uci';
'require form';

const vpnAccount = view.extend({
  load: function(){ return Promise.all([uci.changes(), uci.load('vpn')]); },
  render: function(){
    let m, s, o;

    m = new form.Map('vpn');
    m.chain('ipsec');

    s = m.section(form.NamedSection, 'active', 'vpn', 'VPN Account');

    o = s.option(form.Value, 'username', 'VPN Username');
    o.placeholder = 'my_identifier';
    o.rmempty = false;

    o = s.option(form.Value, 'password', 'VPN Password');
    o.rmempty = false;
    o.password = true;
    o.datatype = 'maxlength(63)';

    return m.render();
  },
  handleSaveApply: function(ev, mode) {
    return this.handleSave(ev).then(function() {
      classes.ui.changes.apply(mode == '0');
      const username = document.getElementById('widget.cbid.vpn.active.username').value;
      const password = document.getElementById('widget.cbid.vpn.active.password').value;
      fs.write('/etc/openvpn/login.auth', username + '\n' + password);
      uci.set('ipsec', 'vpn_1', 'eap_identity', username);
      uci.set('ipsec', 'vpn_1', 'eap_password', password);
      uci.save();
      function displayError(){ classes.ui.changes.displayStatus('warning',
          E('p', 'Something went wrong applying the configuration changes…')); }
      classes.ui.changes.displayStatus('notice spinning', E('p', 'Applying configuration changes…'));
      uci.apply().then(function(){
        fs.exec_direct('/usr/lib/lua/luci/apply_vpn_config.lua').then(function(){
          classes.ui.changes.confirm(mode == '0', Date.now() + L.env.apply_rollback * 1000);
        }, displayError);
      }, displayError);
    });
  },
  handleReset: null
});
return vpnAccount;
