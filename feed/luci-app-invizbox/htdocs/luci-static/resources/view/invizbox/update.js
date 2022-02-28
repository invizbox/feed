'use strict';
'require view';
'require fs';
'require ui';

function getUpdateLog(){ return L.resolveDefault(fs.read_direct('/var/log/update.log'), 'No log data available.'); }

function performUpdate(){
  const logArea = document.getElementById('update-log');
  logArea.value = '';
  const updateButton = document.getElementById('update-button');
  updateButton.classList.add('spinning');
  updateButton.innerText = 'Performing update';
  updateButton.disabled = true;

  function updateLogContent(){
    return getUpdateLog().then(function(logdata){
      const loglines = logdata.trim().split(/\n/);
      logArea.setAttribute('rows', loglines.length + 1);
      logArea.value = loglines.join('\n');
    });
  }

  const poll = setInterval(function(){ updateLogContent(); }, 5000);
  return fs.exec_direct('/usr/lib/lua/update.lua', []).then(function(res){
    if (res != 0) {
      if (res === 'Unable to obtain update lock.\n') {
        L.ui.addNotification(null, E('p', 'An automatic update is already in progress.'));
      } else {
        L.ui.addNotification(null, E('p', 'There was a problem performing the update.'));
      }
    }
    clearInterval(poll);
    updateLogContent();
    updateButton.classList.remove('spinning');
    updateButton.innerText = 'Perform update';
    updateButton.disabled = false;
  });
}

const update = view.extend({
  load: function(){ return Promise.resolve(getUpdateLog()); },
  render: function(logdata){
    const loglines = logdata.trim().split(/\n/);
    return E([], [
      E('div', { 'style': 'display:flex;padding-bottom:1rem;align-items:baseline;' }, [
      	E('h2', {}, [ 'Update Log' ]),
				E('button', {
					'class': 'cbi-button cbi-button-action important',
					'click': function(){ performUpdate(); },
					'id': 'update-button',
					'style': 'margin-left:1rem;'
				}, 'Perform update'),
			]),
			E('div', { 'id': 'content_syslog' }, [
				E('textarea', {
					'id': 'update-log',
					'class': 'read-only-text-area',
					'readonly': 'readonly',
					'wrap': 'off',
					'rows': loglines.length + 1
				}, [ loglines.join('\n') ])
			])
		]);
  },
  handleSaveApply: null,
  handleSave: null,
  handleReset: null
});
return update;
