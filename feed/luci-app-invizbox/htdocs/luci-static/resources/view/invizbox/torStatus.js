'use strict';
'require view';
'require fs';
'require uci';
'require ui';

function setSpinning(id, set){
  const button = document.getElementById(id);
  if (set) {
    button.classList.add('spinning');
    button.setAttribute('disabled', 'disabled');
  } else {
    button.classList.remove('spinning');
    button.removeAttribute('disabled');
  }
}

function refreshTorConnectionStatus(){
  setSpinning('connection-status-refresh-button', true);
  const status = document.getElementById('connection-status');
  status.innerText = '';
  fs.exec_direct('/usr/lib/lua/luci/tor_connection_status.lua', []).then(function (torConnectionStatus){
    status.innerText = torConnectionStatus;
    setSpinning('connection-status-refresh-button', false);
  });
}

function refreshTorCircuitStatus(){
  setSpinning('circuit-status-refresh-button', true);
  const status = document.getElementById('circuit-status');
  status.innerText = '';
  fs.exec_direct('/usr/lib/lua/luci/tor_circuit_status.lua', []).then(function (torCircuitStatus){
    const torCircuitStatusLines = torCircuitStatus.split('<br>');
    status.setAttribute('rows', torCircuitStatusLines.length + 1);
    status.innerHTML = torCircuitStatusLines.join('\n');
    setSpinning('circuit-status-refresh-button', false);
  });
}

const status = view.extend({
  load: function(){
    return Promise.all([
      fs.exec_direct('/usr/lib/lua/luci/tor_connection_status.lua', []),
      fs.exec_direct('/usr/lib/lua/luci/tor_version.lua', []),
      fs.exec_direct('/usr/lib/lua/luci/tor_circuit_status.lua', []),
    ]);
  },
  render: function(data){
    const torConnectionStatus = data[0];
    const torVersion = data[1];
    const torCircuitStatusLines = data[2].split('<br>');
    return E([], [
      E('div', {}, [
        E('div', { 'class': 'cbi-section' }, [
          E('h3', {}, [ 'Tor Status' ]),
          E('div', {}, [
            E('button', {
              'class': 'cbi-button cbi-button-action tor-action-button',
              'click': function(){
                setSpinning('restart-button', true);
                fs.exec_direct('/etc/init.d/tor', [ 'restart' ]).then(function(){
                  setSpinning('restart-button', false)
                })
              },
              'id': 'restart-button',
            }, 'Restart Tor'),
            E('button', {
              'class': 'cbi-button tor-action-button',
              'click': function(){
                setSpinning('stop-button', true);
                fs.exec_direct('/etc/init.d/tor', [ 'stop' ]).then(function(){
                  setSpinning('stop-button', false)
                })
              },
              'id': 'stop-button',
            }, 'Stop Tor'),
            E('button', {
              'class': 'cbi-button tor-action-button',
              'click': function(){
                setSpinning('new-identity-button', true);
                fs.exec_direct('/usr/lib/lua/luci/tor_new_identity.lua', []).then(function(){
                  setSpinning('new-identity-button', false)
                })
              },
              'id': 'new-identity-button',
            }, 'New Identity'),
          ]),
          E('div', {}, [
            E('div', { 'style': 'display: flex;align-items:baseline;' }, [
              E('h4', {}, 'Tor Connection Status'),
              E('button', {
                'class': 'cbi-button',
                id: 'connection-status-refresh-button',
                'style': 'margin-left:1rem;',
                click: function(){ refreshTorConnectionStatus(); },
              }, 'Refresh')
            ]),
            E('p', { id: 'connection-status' }, torConnectionStatus),
          ]),
          E('div', {}, [
            E('h4', {}, 'Tor Version'), E('p', {'id': 'tor-version',}, torVersion)
          ]),
          E('div', {}, [
            E('div', { 'style': 'display: flex;align-items:baseline;' }, [
              E('h4', {}, 'Tor Circuit Status'),
              E('button', {
                'class': 'cbi-button',
                id: 'circuit-status-refresh-button',
                'style': 'margin-left:1rem;',
                click: function(){ refreshTorCircuitStatus() },
              }, 'Refresh')
            ]),
            E('textarea', {
              'id': 'circuit-status',
              'class': 'read-only-text-area',
              'readonly': 'readonly',
              'wrap': 'off',
              'rows': torCircuitStatusLines.length + 1
            }, torCircuitStatusLines.join('\n')),
          ]),
        ]),
      ]),
    ]);
  },
  handleSaveApply: null,
  handleSave: null,
  handleReset: null
});
return status;
