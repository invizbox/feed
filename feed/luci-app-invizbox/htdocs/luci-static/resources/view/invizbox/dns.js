'use strict';
'require view';
'require fs';
'require ui';
'require rpc';
'require uci';
'require form';

const dns = view.extend({
  load: function(){ return Promise.all([uci.changes(), uci.load('dns')]); },
  render: function(){
    let m, s, o;

    m = new form.Map('dns');
    m.chain('dhcp');

    s = m.section(form.NamedSection, 'main', 'dns', 'DNS');

    o = s.option(form.ListValue, 'dns_id', 'DNS Provider',
      'This DNS is used by the InvizBox as well as all devices in WiFi Extender mode.');
    o.value('dhcp', 'from Router (WAN)');
    uci.sections('dns', 'servers', function(section){ return o.value(section['.name'], section.name); });

    return m.render();
  },
  handleSaveApply: function(ev, mode) {
    return this.handleSave(ev).then(function() {
      const dns_id = document.getElementById('widget.cbid.dns.main.dns_id').value;
      if (dns_id === 'dhcp') {
        uci.set('dhcp', 'auto', 'noresolv', null);
        uci.set('dhcp', 'auto', 'resolvfile', '/tmp/resolv.conf.d/resolv.conf.auto');
        uci.set('dhcp', 'auto', 'server', null);
        uci.set('dhcp', 'invizbox', 'noresolv', null);
        uci.set('dhcp', 'invizbox', 'resolvfile', '/tmp/resolv.conf.d/resolv.conf.auto');
        uci.set('dhcp', 'invizbox', 'server', ['/onion/172.31.1.1#9053']);
      } else {
        uci.set('dhcp', 'auto', 'noresolv', '1');
        uci.set('dhcp', 'auto', 'resolvfile', null);
        uci.set('dhcp', 'auto', 'server', uci.get('dns', dns_id, 'dns_server'));
        uci.set('dhcp', 'invizbox', 'noresolv', '1');
        uci.set('dhcp', 'invizbox', 'resolvfile', null);
        uci.set('dhcp', 'invizbox', 'server',
          uci.get('dns', dns_id, 'dns_server').concat('/onion/172.31.1.1#9053'));
      }
      uci.save();
      classes.ui.changes.apply(mode == '0');
      fs.exec_direct('/etc/init.d/dnsmasq', [ 'restart' ]);
    });
  },
  handleReset: null
});
return dns;
