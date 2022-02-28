'use strict';
'require dom';
'require form';
'require fs';
'require ui';
'require view';

let formData = {
  geoip: {
    mode: 'any',
    countries: [],
  }
};

let romTorrc = '';
let proxyConfig = '';
let bridgeConfig = '';
const countryOptions = view.extend({
  load: function(){
    return Promise.all([
      L.resolveDefault(fs.read_direct('/etc/tor/geoip')).then(function(fileContent) {
        if (fileContent === 'ExcludeExitNodes {AU},{CA},{NZ},{UK},{US}\n') {
          formData.geoip.mode = 'five-eyes';
        } else if (fileContent && fileContent.startsWith('ExcludeExitNodes ')) {
          formData.geoip.mode = 'blacklist';
          formData.geoip.countries = fileContent.substring(17).trim().replace(/[{}]/g,'').split(',');
        } else if (fileContent && fileContent.startsWith('ExitNodes ')) {
          formData.geoip.mode = 'whitelist';
          formData.geoip.countries = fileContent.substring(10).trim().replace(/[{}]/g,'').split(',');
        }
      }),
      L.resolveDefault(fs.read_direct('/rom/etc/tor/torrc')),
      L.resolveDefault(fs.read_direct('/etc/tor/proxy')),
      L.resolveDefault(fs.read_direct('/etc/tor/bridges'))
    ]);
  },
  render: function(torConfigs) {
    romTorrc = torConfigs[1] || '';
    proxyConfig = torConfigs[2] || '';
    bridgeConfig = torConfigs[3] || '';
    let m, s, o;
    m = new form.JSONMap(formData);
    s = m.section(form.NamedSection, 'geoip', 'geoip', 'Country Options');

    o = s.option(form.ListValue, 'mode', 'Mode');
    o.value('any', 'Use any exit node (default)');
    o.value('five-eyes', 'Exclude "Five Eyes" countries');
    o.value('blacklist', 'Do not use countries selected below');
    o.value('whitelist', 'Allow only countries selected below');

    o = s.option(form.MultiValue, 'countries', 'Countries');
    o.depends('mode', 'blacklist');
    o.depends('mode', 'whitelist');
    o.value('A1', 'Anonymous Proxies');
    o.value('AR', 'Argentina');
    o.value('AP', 'Asia/Pacific Region');
    o.value('AU', 'Australia');
    o.value('AT', 'Austria');
    o.value('BY', 'Belarus');
    o.value('BE', 'Belgium');
    o.value('BR', 'Brazil');
    o.value('BG', 'Bulgaria');
    o.value('KH', 'Cambodia');
    o.value('CA', 'Canada');
    o.value('CL', 'Chile');
    o.value('CO', 'Colombia');
    o.value('CR', 'Costa Rica');
    o.value('HR', 'Croatia');
    o.value('CY', 'Cyprus');
    o.value('CZ', 'Czech Republic');
    o.value('DK', 'Denmark');
    o.value('EG', 'Egypt');
    o.value('EE', 'Estonia');
    o.value('EU', 'Europe');
    o.value('FI', 'Finland');
    o.value('FR', 'France');
    o.value('GE', 'Georgia');
    o.value('DE', 'Germany');
    o.value('GR', 'Greece');
    o.value('GT', 'Guatemala');
    o.value('GG', 'Guernsey');
    o.value('HK', 'Hong Kong');
    o.value('HU', 'Hungary');
    o.value('IS', 'Iceland');
    o.value('IN', 'India');
    o.value('ID', 'Indonesia');
    o.value('IE', 'Ireland');
    o.value('IL', 'Israel');
    o.value('IT', 'Italy');
    o.value('JP', 'Japan');
    o.value('KZ', 'Kazakhstan');
    o.value('KE', 'Kenya');
    o.value('KR', 'Korea","Republic of');
    o.value('LV', 'Latvia');
    o.value('LI', 'Liechtenstein');
    o.value('LT', 'Lithuania');
    o.value('LU', 'Luxembourg');
    o.value('MK', 'North Macedonia');
    o.value('MY', 'Malaysia');
    o.value('MT', 'Malta');
    o.value('MX', 'Mexico');
    o.value('MD', 'Moldova","Republic of');
    o.value('MA', 'Morocco');
    o.value('NA', 'Namibia');
    o.value('NL', 'Netherlands');
    o.value('NZ', 'New Zealand');
    o.value('NG', 'Nigeria');
    o.value('NO', 'Norway');
    o.value('PK', 'Pakistan');
    o.value('PA', 'Panama');
    o.value('PL', 'Poland');
    o.value('PT', 'Portugal');
    o.value('QA', 'Qatar');
    o.value('RO', 'Romania');
    o.value('RU', 'Russia');
    o.value('A2', 'Satellite Provider');
    o.value('SA', 'Saudi Arabia');
    o.value('RS', 'Serbia');
    o.value('SC', 'Seychelles');
    o.value('SG', 'Singapore');
    o.value('SK', 'Slovakia');
    o.value('SI', 'Slovenia');
    o.value('ZA', 'South Africa');
    o.value('ES', 'Spain');
    o.value('SE', 'Sweden');
    o.value('CH', 'Switzerland');
    o.value('TW', 'Taiwan');
    o.value('TH', 'Thailand');
    o.value('TR', 'Turkey');
    o.value('UA', 'Ukraine');
    o.value('GB', 'United Kingdom');
    o.value('US', 'United States');
    o.value('VE', 'Venezuela');
    o.value('VN', 'Vietnam');

    return m.render();
  },
  handleSave: function() {
    return dom.callClassMethod(document.querySelector('.cbi-map'), 'save').then(function() {
      let geoipConfig = '';
      const mode = formData.geoip.mode;
      const countries = formData.geoip.countries;
      if ((mode === 'blacklist' || mode === 'whitelist') && (!countries || countries.length < 1)) {
        return ui.addNotification(null, E('p', 'Please select at least one country.'), 'danger');
      }
      if (mode ==='five-eyes') {
        geoipConfig = 'ExcludeExitNodes {AU},{CA},{NZ},{UK},{US}\n';
      } else if (mode ==='blacklist') {
        geoipConfig = 'ExcludeExitNodes ';
        countries.map(function(country){ geoipConfig += '{' + country + '},'; });
        geoipConfig = geoipConfig.slice(0, -1);
        geoipConfig += '\n';
      } else if (mode ==='whitelist') {
        geoipConfig = 'ExitNodes ';
        countries.map(function(country){ geoipConfig += '{' + country + '},'; });
        geoipConfig = geoipConfig.slice(0, -1);
        geoipConfig += '\n';
      }
      function displayError() {
        L.ui.addNotification(null, E('p', 'Something went wrong when updating your country options…'), 'danger');
      }
      return fs.write('/etc/tor/geoip', geoipConfig).then(function () {
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
return countryOptions;
