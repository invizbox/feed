'use strict';
'require view';
'require fs';
'require ui';

let romTorrc = null;
let proxyConfig = null;
let geoipConfig = null;
const torBridgeConfiguration = view.extend({
  load: function(){
    return Promise.all([
      L.resolveDefault(fs.read_direct('/etc/tor/bridges')).then(function(config) {
        if (!config || config.split('\n').length < 2) {
          return [];
        }
        let bridgeLines = config.split('\n');
        bridgeLines.shift();
        const bridges = [];
        bridgeLines.map(function(line){
          bridges.push(line.replace(/^Bridge /, ''));
        });
        return bridges;
      }),
      L.resolveDefault(fs.read_direct('/rom/etc/tor/torrc')),
      L.resolveDefault(fs.read_direct('/etc/tor/proxy')),
      L.resolveDefault(fs.read_direct('/etc/tor/geoip'))
    ]);
  },
  render: function(torConfigs){
    const bridgeConfigurationLines = torConfigs[0];
    romTorrc = torConfigs[1] || '';
    proxyConfig = torConfigs[2] || '';
    geoipConfig = torConfigs[3] || '';
    return E([], [
      E('div', {}, [
        E('div', { 'class': 'cbi-section' }, [
          E('h3', {}, [ 'Tor Bridge Configuration' ]),
          E('textarea', {
            'id': 'bridge-configuration',
            'class': 'editable-text-area',
            'wrap': 'off',
            'rows': bridgeConfigurationLines.length + 1
          }, bridgeConfigurationLines.join('\n')),
          E('p', { 'class': 'cbi-map-descr' }, [
            E('span', {},
              'Please enter in the bridges you want Tor to use, one per line.\nThe format is : "ip:port '
              + '[fingerprint]" where fingerprint is optional. e.g. 121.101.27.4:443 '
              + ' 4352e58420e68f5e40ade74faddccd9d1349413.\nTo get bridge information, see '
            ),
            E('a', {
              'href': 'https://bridges.torproject.org/bridges',
              'rel': 'noopener noreferrer',
              'target': '_blank',
            }, 'the Tor bridges page'),
            E('span', {}, '.'),
          ]),
        ]),
      ]),
    ]);
  },
  handleSaveApply: function() {
    const text = document.getElementById('bridge-configuration').value;
    let bridges = '';
    if (text && text.length > 0) {
      const lines = text.split('\n');
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (!line.trim()) {
          continue;
        }
        if (line.trim().split(/\s+/).length === 1 || line.trim().split(/\s+/).length === 2) {
          bridges += 'Bridge ' + line + '\n';
        } else {
          bridges = null;
          break;
        }
      }
      if (!bridges) {
        return L.ui.addNotification(null, E('p', 'Invalid bridge configuration format.'), 'danger');
      }
    }
    function displayError() {
      L.ui.addNotification(null, E('p', 'Something went wrong when updating your bridge configuration…'), 'danger');
    }
    const bridgeConfig = bridges ? 'UseBridges 1\n' + bridges : '';
    return fs.write('/etc/tor/bridges', bridgeConfig).then(function(){
      fs.write('/etc/tor/torrc', romTorrc + proxyConfig + bridgeConfig + geoipConfig).then(function(){
        L.ui.addNotification(null, E('p',
          'Your Tor configuration has been updated. To make use of your new configuration, make sure to'
          + ' restart Tor on the Tor Status page.'));
      }, displayError);
    }, displayError);
  },
  handleSave: null,
  handleReset: null
});
return torBridgeConfiguration;
