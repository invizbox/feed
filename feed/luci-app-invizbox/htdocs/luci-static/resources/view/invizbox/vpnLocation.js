'use strict';
'require view';
'require fs';
'require ui';
'require rpc';
'require uci';
'require form';

const COUNTRY_NAMES = {
  AF: 'Afghanistan', AX: 'Aland Islands', AL: 'Albania', DZ: 'Algeria', AS: 'American Samoa', AD: 'Andorra',
  AO: 'Angola', AI: 'Anguilla', AQ: 'Antarctica', AG: 'Antigua And Barbuda', AR: 'Argentina', AM: 'Armenia',
  AW: 'Aruba', AU: 'Australia', AT: 'Austria', AZ: 'Azerbaijan', BS: 'Bahamas', BH: 'Bahrain', BD: 'Bangladesh',
  BB: 'Barbados', BY: 'Belarus', BE: 'Belgium', BZ: 'Belize', BJ: 'Benin', BM: 'Bermuda', BT: 'Bhutan', BO: 'Bolivia',
  BA: 'Bosnia And Herzegovina', BW: 'Botswana', BV: 'Bouvet Island', BR: 'Brazil', IO: 'British Indian Ocean Territory',
  BN: 'Brunei Darussalam', BG: 'Bulgaria', BF: 'Burkina Faso', BI: 'Burundi', KH: 'Cambodia', CM: 'Cameroon',
  CA: 'Canada', CV: 'Cape Verde', KY: 'Cayman Islands', CF: 'Central African Republic', TD: 'Chad', CL: 'Chile',
  CN: 'China', CX: 'Christmas Island', CC: 'Cocos (Keeling) Islands', CO: 'Colombia', KM: 'Comoros', CG: 'Congo',
  CD: 'Congo Democratic Republic', CK: 'Cook Islands', CR: 'Costa Rica', CI: 'Cote D\'Ivoire', HR: 'Croatia',
  CU: 'Cuba', CY: 'Cyprus', CZ: 'Czech Republic', DK: 'Denmark', DJ: 'Djibouti', DM: 'Dominica',
  DO: 'Dominican Republic', EC: 'Ecuador', EG: 'Egypt', SV: 'El Salvador', GQ: 'Equatorial Guinea', ER: 'Eritrea',
  EE: 'Estonia', ET: 'Ethiopia', FK: 'Falkland Islands (Malvinas)', FO: 'Faroe Islands', FJ: 'Fiji', FI: 'Finland',
  FR: 'France', GF: 'French Guiana', PF: 'French Polynesia', TF: 'French Southern Territories', GA: 'Gabon',
  GM: 'Gambia', GE: 'Georgia', DE: 'Germany', GH: 'Ghana', GI: 'Gibraltar', GR: 'Greece', GL: 'Greenland',
  GD: 'Grenada', GP: 'Guadeloupe', GU: 'Guam', GT: 'Guatemala', GG: 'Guernsey', GN: 'Guinea', GW: 'Guinea-Bissau',
  GY: 'Guyana', HT: 'Haiti', HM: 'Heard Island & Mcdonald Islands', VA: 'Holy See (Vatican City State)',
  HN: 'Honduras', HK: 'Hong Kong', HU: 'Hungary', IS: 'Iceland', IN: 'India', ID: 'Indonesia',
  IR: 'Iran Islamic Republic Of', IQ: 'Iraq', IE: 'Ireland', IM: 'Isle Of Man', IL: 'Israel', IT: 'Italy',
  JM: 'Jamaica', JP: 'Japan', JE: 'Jersey', JO: 'Jordan', KZ: 'Kazakhstan', KE: 'Kenya', KI: 'Kiribati',
  KR: 'Korea', KW: 'Kuwait', KG: 'Kyrgyzstan', LA: 'Lao People\'s Democratic Republic', LV: 'Latvia', LB: 'Lebanon',
  LS: 'Lesotho', LR: 'Liberia', LY: 'Libyan Arab Jamahiriya', LI: 'Liechtenstein', LT: 'Lithuania', LU: 'Luxembourg',
  MO: 'Macao', MK: 'North Macedonia', MG: 'Madagascar', MW: 'Malawi', MY: 'Malaysia', MV: 'Maldives', ML: 'Mali',
  MT: 'Malta', MH: 'Marshall Islands', MQ: 'Martinique', MR: 'Mauritania', MU: 'Mauritius', YT: 'Mayotte',
  MX: 'Mexico', FM: 'Micronesia Federated States Of', MD: 'Moldova', MC: 'Monaco', MN: 'Mongolia', ME: 'Montenegro',
  MS: 'Montserrat', MA: 'Morocco', MZ: 'Mozambique', MM: 'Myanmar', NA: 'Namibia', NR: 'Nauru', NP: 'Nepal',
  NL: 'Netherlands', AN: 'Netherlands Antilles', NC: 'New Caledonia', NZ: 'New Zealand', NI: 'Nicaragua', NE: 'Niger',
  NG: 'Nigeria', NU: 'Niue', NF: 'Norfolk Island', MP: 'Northern Mariana Islands', NO: 'Norway', OM: 'Oman',
  PK: 'Pakistan', PW: 'Palau', PS: 'Palestinian Territory Occupied', PA: 'Panama', PG: 'Papua New Guinea',
  PY: 'Paraguay', PE: 'Peru', PH: 'Philippines', PN: 'Pitcairn', PL: 'Poland', PT: 'Portugal', PR: 'Puerto Rico',
  QA: 'Qatar', RE: 'Reunion', RO: 'Romania', RU: 'Russia', RW: 'Rwanda', BL: 'Saint Barthelemy', SH: 'Saint Helena',
  KN: 'Saint Kitts And Nevis', LC: 'Saint Lucia', MF: 'Saint Martin', PM: 'Saint Pierre And Miquelon',
  VC: 'Saint Vincent And Grenadines', WS: 'Samoa', SM: 'San Marino', ST: 'Sao Tome And Principe', SA: 'Saudi Arabia',
  SN: 'Senegal', RS: 'Serbia', SC: 'Seychelles', SL: 'Sierra Leone', SG: 'Singapore', SK: 'Slovakia', SI: 'Slovenia',
  SB: 'Solomon Islands', SO: 'Somalia', ZA: 'South Africa', GS: 'South Georgia And Sandwich Isl.', ES: 'Spain',
  LK: 'Sri Lanka', SD: 'Sudan', SR: 'Suriname', SJ: 'Svalbard And Jan Mayen', SZ: 'Swaziland', SE: 'Sweden',
  CH: 'Switzerland', SY: 'Syrian Arab Republic', TW: 'Taiwan', TJ: 'Tajikistan', TZ: 'Tanzania', TH: 'Thailand',
  TL: 'Timor-Leste', TG: 'Togo', TK: 'Tokelau', TO: 'Tonga', TT: 'Trinidad And Tobago', TN: 'Tunisia', TR: 'Turkey',
  TM: 'Turkmenistan', TC: 'Turks And Caicos Islands', TV: 'Tuvalu', UG: 'Uganda', UA: 'Ukraine',
  AE: 'United Arab Emirates', GB: 'UK', UK: 'UK', US: 'US', UM: 'US Minor Outlying Islands', UY: 'Uruguay',
  UZ: 'Uzbekistan', VU: 'Vanuatu', VE: 'Venezuela', VN: 'Vietnam', VG: 'Virgin Islands British',
  VI: 'Virgin Islands U.S.', WF: 'Wallis And Futuna', EH: 'Western Sahara', YE: 'Yemen', ZM: 'Zambia', ZW: 'Zimbabwe'
};

function getProtocols(uci){
  const protocols = {};
  uci.sections('vpn', 'protocol', function(section){
    protocols[section['.name']] = section.default === 'true' ? section['name'] + ' (Default)' : section['name'];
  });
  protocols['filename'] = 'From OVPN';
  return protocols;
}

function getCountries(uci){
  const countries = {};
  const protocols = getProtocols(uci);
  const currentServer = uci.get('vpn', 'active', 'vpn_1');
  uci.sections('vpn', 'server', function(section){
    const countryName = COUNTRY_NAMES[section['country']] || section['country'];
    if (Object.keys(countries).indexOf(countryName) === -1) {
      countries[countryName] = { servers: {} };
    }
    const server = { display: section['city'] + ' - ' + section['name'], protocols: {} };
    if (section['protocol_id']) {
      section['protocol_id'].map(function(protocol_id){
        if (protocols[protocol_id]) {
          server['protocols'][protocol_id] = protocols[protocol_id];
        }
      });
    } else if (section.filename) {
      server['protocols']['filename'] = protocols['filename'];
    }
    countries[countryName]['servers'][section['.name']] = server;
    if (section['.name'] === currentServer) {
      countries.default = countryName;
    }
  });
  return countries;
}

function selectRandom(arr){
  const randomIndex = Math.floor(Math.random() * arr.length);
  return arr[randomIndex];
}

function updateServerOptions(countries, node){
  const dom = node || document;
  const country = dom.getElementsByTagName('select')[0].value;
  const newServers = countries[country].servers;
  const serverInput = dom.getElementsByTagName('select')[1];
  const newValue = newServers[serverInput.value] ? serverInput.value : selectRandom(Object.keys(newServers));
  serverInput.innerHTML = null;
  Object.keys(newServers).map(function(serverId){
    const option = document.createElement('option');
    option.value = serverId;
    option.innerHTML = newServers[serverId].display;
    serverInput.appendChild(option);
  });
  serverInput.value = newValue;
  updateProtocolOptions(countries, node);
}

function updateProtocolOptions(countries, node){
  const dom = node || document;
  const country = dom.getElementsByTagName('select')[0].value;
  const serverId = dom.getElementsByTagName('select')[1].value;
  const newProtocols = countries[country].servers[serverId].protocols;
  const protocolInput = dom.getElementsByTagName('select')[2];
  const newValue = newProtocols[protocolInput.value] ? protocolInput.value : Object.keys(newProtocols)[0];
  protocolInput.innerHTML = null;
  Object.keys(newProtocols).map(function(protocolId){
    const option = document.createElement('option');
    option.value = protocolId;
    option.innerHTML = newProtocols[protocolId];
    protocolInput.appendChild(option);
  });
  protocolInput.value = newValue;
}

const vpnLocation = view.extend({
  load: function(){ return Promise.all([uci.changes(), uci.load('vpn')]); },
  render: function(){
    let m, s, o;
    const countries = getCountries(uci);

    m = new form.Map('vpn');
    m.chain('ipsec');
    m.chain('openvpn');

    s = m.section(form.NamedSection, 'active', 'vpn', 'VPN configuration');
    s.anonymous = true;

    o = s.option(form.ListValue, '_country', 'Country');
    Object.keys(countries).sort().map(function(country){
      if (country !== 'default') {
        o.value(country, country);
      }
    });
    o.default = countries.default;
    o.onchange = function(){ updateServerOptions(countries); };
    o.write = function(){};

    o = s.option(form.ListValue, 'vpn_1', 'Server');
    o.value(uci.get('vpn', 'active', 'vpn_1'));
    o.onchange = function(){ updateProtocolOptions(countries); };

    o = s.option(form.Button, '_random_server', ' ');
    o.titleFn = function(){ return 'Random Server'; };
    o.onclick = function(){
      const country = document.getElementsByTagName('select')[0].value;
      const servers = countries[country].servers;
      document.getElementsByTagName('select')[1].value = selectRandom(Object.keys(servers));
    };

    o = s.option(form.ListValue, 'protocol_id', 'Protocol');
    o.value(uci.get('vpn', 'active', 'protocol_id'));

    return m.render().then(function(node){
      updateServerOptions(countries, node);
      const selectInputs = node.getElementsByTagName('select');
      selectInputs[1].click();
      selectInputs[2].click();
      return node;
    });
  },
  handleSaveApply: function(ev, mode) {
    const currentProtocolId = document.getElementById('widget.cbid.vpn.active.protocol_id').value;
    const currentProtocol = currentProtocolId && uci.get('vpn', currentProtocolId, 'vpn_protocol') || '';
    return this.handleSave(ev).then(function() {
      if (currentProtocol === 'IKEv2') {
        uci.set('ipsec', 'general', 'enabled', '1');
      } else {
        uci.set('ipsec', 'general', 'enabled', '0');
      }
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
return vpnLocation;
