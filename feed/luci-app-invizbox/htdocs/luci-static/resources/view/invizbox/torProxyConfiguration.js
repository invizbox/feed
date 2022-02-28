'use strict';
'require dom';
'require form';
'require fs';
'require ui';
'require view';

let formData = {
  proxy: {
    ipAddress: null,
    password: null,
    port: null,
    type: 'none',
    username: null,
  }
};
let romTorrc = null;
let bridgeConfig = null;
let geoipConfig = null;
const proxyConfiguration = view.extend({
  load:function(){
    return Promise.all([
  	  L.resolveDefault(fs.read_direct('/etc/tor/proxy')).then(function(config) {
        if (!config) {
    	  return;
        }
        let configLines = config.split('\n');
        configLines.map(function(line){
    	  if (line.startsWith('HTTPSProxy ')) {
            formData.proxy.type = 'HTTPSProxy ';
            formData.proxy.ipAddress = line.split(':')[0].substring(11);
            formData.proxy.port = line.split(':')[1];
            formData.proxy.type = 'HTTPSProxy';
          } else if (line.startsWith('Socks4Proxy ')) {
            formData.proxy.type = 'Socks4Proxy';
            formData.proxy.ipAddress = line.split(':')[0].substring(12);
            formData.proxy.port = line.split(':')[1];
          } else if (line.startsWith('Socks5Proxy ')) {
            formData.proxy.type = 'Socks5Proxy';
            formData.proxy.ipAddress = line.split(':')[0].substring(12);
            formData.proxy.port = line.split(':')[1];
          } else if (line.startsWith('Socks5ProxyUsername ')) {
            formData.proxy.username = line.substring(20);
          } else if (line.startsWith('Socks5ProxyPassword ')) {
            formData.proxy.password = line.substring(20);
          } else if (line.startsWith('HTTPSProxyAuthenticator ')) {
            formData.proxy.username = line.split(':')[0].substring(24);
            formData.proxy.password = line.split(':')[1];
          }
        });
      }),
      L.resolveDefault(fs.read_direct('/rom/etc/tor/torrc')),
      L.resolveDefault(fs.read_direct('/etc/tor/bridges')),
      L.resolveDefault(fs.read_direct('/etc/tor/geoip'))
    ]);
  },
  render: function(torConfigs){
    romTorrc = torConfigs[1] || '';
    bridgeConfig = torConfigs[2] || '';
    geoipConfig = torConfigs[3] || '';
    let m, s, o;
    m = new form.JSONMap(formData);
    s = m.section(form.NamedSection, 'proxy', 'proxy', 'Proxy Configuration');

    o = s.option(form.ListValue, 'type', 'Type');
    o.value('none', 'None');
    o.value('HTTPSProxy', 'HTTP/HTTPS');
    o.value('Socks4Proxy', 'SOCKS4');
    o.value('Socks5Proxy', 'SOCKS5');

    o = s.option(form.Value, 'ipAddress', 'IP Address');
    o.datatype = 'ip4addr';
    o.depends('type', 'HTTPSProxy');
    o.depends('type', 'Socks4Proxy');
    o.depends('type', 'Socks5Proxy');
    o.placeholder = '192.168.1.5';

    o = s.option(form.Value, 'port', 'Port');
    o.depends('type', 'HTTPSProxy');
    o.depends('type', 'Socks4Proxy');
    o.depends('type', 'Socks5Proxy');
    o.datatype = 'port';
    o.placeholder = '80';

    o = s.option(form.Value, 'username', 'Username');
    o.depends('type', 'HTTPSProxy');
    o.depends('type', 'Socks5Proxy');
    o.placeholder = 'optional';

    o = s.option(form.Value, 'password', 'Password');
    o.depends('type', 'HTTPSProxy');
    o.depends('type', 'Socks5Proxy');
    o.password = true;
    o.placeholder = 'optional';

    return m.render();
  },
  handleSave: function() {
    return dom.callClassMethod(document.querySelector('.cbi-map'), 'save').then(function() {
      let proxyConfig = '';
      const proxy = formData.proxy;
      if (proxy.type !== 'none') {
        if (!proxy.ipAddress) {
          return ui.addNotification(null, E('p', 'Option "IP Address" is missing an input value.'), 'danger');
        } else if (!proxy.port) {
          return ui.addNotification(null, E('p', 'Option "Port" is missing an input value.'), 'danger');
        } else if (document.getElementsByClassName('cbi-input-invalid').length > 0) {
          return ui.addNotification(null, E('p', 'The form contains invalid entries.'), 'danger');
        }
        proxyConfig = proxy.type + ' ' + proxy.ipAddress + ':' + proxy.port + '\n';
        if (proxy.username && proxy.password) {
          if (proxy.type === 'HTTPSProxy') {
            proxyConfig += 'HTTPSProxyAuthenticator ' + proxy.username + ':' + proxy.password + '\n';
          } else if (proxy.type === 'Socks5Proxy') {
            proxyConfig += 'Socks5ProxyUsername ' + proxy.username + '\nSocks5ProxyPassword ' + proxy.password + '\n';
          }
        }
      }
      function displayError() {
        L.ui.addNotification(null, E('p', 'Something went wrong when updating your proxy configuration…'), 'danger');
      }
      return fs.write('/etc/tor/proxy', proxyConfig).then(function () {
        fs.write('/etc/tor/torrc', romTorrc + proxyConfig + bridgeConfig + geoipConfig).then(function(){
          L.ui.addNotification(null, E('p', 'Your Tor configuration has been updated. To make use of your'
            + ' new configuration, make sure to restart Tor on the Tor Status page.'));
        }, displayError);
      }, displayError);
    });
  },
  handleSaveApply: null,
  handleReset: null
});
return proxyConfiguration;
