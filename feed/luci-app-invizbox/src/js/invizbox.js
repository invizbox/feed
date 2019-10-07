(function ($) {

  /**
   * VPN Menu
   */

  $(document).ready(function () {
    $(function () {
      var cityInput = $('#vpncity');
      var options = cityInput.html();
      $('#vpncountry').change(function (e) {
        var text = $('#vpncountry :selected').val();
        cityInput.html(options);
        $('#vpncity option[filtercountry!="' + text + '"]').remove();
      });
      var selcity = $('#vpncity option:selected').attr('filtercountry');
      $('#vpncountry option[value*="' + selcity + '"]').prop('selected', 'selected').change();
      cityInput.val($('#activevpn').val()).change();
    })
  });

  window.onload = function () {
    showChangesAppliedSuccess();
  };
  $(window).ready(function () {
    $('#vpncity').val($('#activevpn').val()).change();
    var selcity = $('#vpncity option:selected').attr('filtercountry');
    $('#vpncountry option[value*="' + selcity + '"]').prop('selected', 'selected').change();
  });

  function showChangesAppliedSuccess() {
    var pageHeading = document.getElementsByName('content')[0];
    var href = window.location.href;
    if (href.endsWith('?success=true') && !href.includes('/wizard/complete?success=true') && pageHeading) {
      var link = window.location.origin + '/cgi-bin/luci/';
      var changesApplied = '<div class="changes-applied-success"><strong>Changes applied successfully.</strong><a class="a-to-btn" href="' + link + '"><input class="cbi-button" value="Return to Status page" type="button"></a></div>';
      pageHeading.insertAdjacentHTML('afterend', changesApplied);
    }
  }

})(jQuery);

function stopTor() {
  var endpoint = '/cgi-bin/luci/admin/system/flashops/stop_tor';
  var xhr;
  if (window.XMLHttpRequest) {
    xhr = new XMLHttpRequest();
  }
  else if (window.ActiveXObject) {
    xhr = new ActiveXObject('Microsoft.XMLHTTP');
  }
  else {
    alert('xhr.js: XMLHttpRequest is not supported by this browser!');
  }
  var url = window.location.protocol + '//' + window.location.host + endpoint;
  xhr.open('GET', url, false);
  xhr.send(null);
  return true;
}

function pollForConnectivity(callback, interval) {
  var poll = window.setInterval(function () {
    var img = new Image();
    img.onload = function () {
      window.clearInterval(poll);
      callback();
    };
    img.src = window.location.origin + '/luci-static/resources/icons/loading.gif?' + Math.random();
  }, interval);
}

var shouldAddRequiredError = true;
function validatePasswordFieldChanges() {
  var [pw1, pw2] = document.getElementsByClassName('form-control cbi-input-password');
  var saveButton = document.getElementsByClassName('cbi-button cbi-button-apply')[0];
  var minLength = pw1.getAttribute('data-minlength');
  var maxLength = pw1.getAttribute('maxlength');
  if ((pw1.value !== pw2.value) ||
    (minLength && (pw1.value.length < minLength || pw2.value.length < minLength)) ||
    (maxLength && (pw1.value.length >   maxLength || pw2.value.length >  maxLength))
  ) {
    saveButton.setAttribute('disabled', "");
  } else {
    saveButton.removeAttribute('disabled');
  }
  if (pw2.value === '' && shouldAddRequiredError) {
    var errorList = pw2.parentElement.getElementsByClassName('help-block with-errors')[0];
    errorList.style.opacity = '1';
    var fieldRequiredError = document.createElement('li');
    fieldRequiredError.innerText = 'Please fill out this field';
    fieldRequiredError.style.color = '#ff3b30';
    fieldRequiredError.id = 'confirm-password-required-error';
    errorList.appendChild(fieldRequiredError);
    shouldAddRequiredError = false;
  } else if (pw2.value !== '') {
    var confirmPasswordRequiredError = document.getElementById('confirm-password-required-error');
    if (confirmPasswordRequiredError) {
      confirmPasswordRequiredError.remove();
    }
    shouldAddRequiredError = false;
  }
}

if (document.getElementById('cbid.wireless.wan.wifi-networks')) {
  wifiScan();
}

function createRefreshButton() {
  var refreshButton = document.createElement('a');
  refreshButton.setAttribute('id', 'choose-network-refresh-button');
  refreshButton.setAttribute('href', '#');
  refreshButton.setAttribute('onclick', 'wifiScan(true);');
  var refreshIcon = document.createElement('i');
  refreshIcon.setAttribute('id', 'repeat-scan');
  refreshIcon.setAttribute('class', 'fa fa-refresh fa-lg');
  refreshIcon.setAttribute('title', 'Rescan Network');
  refreshIcon.style.marginLeft = '1rem';
  refreshButton.appendChild(refreshIcon);
  return refreshButton;
}

function addWifiNetworksToSelectInput(networks) {

  var form = document.getElementById('cbi-wireless-wan');
  form.style.display = 'inline-block';

  var networkSelectInput = document.getElementById('cbid.wireless.wan.wifi-networks');
  var encryptionSelectInput = document.getElementById('cbid.wireless.wan.encryption');
  networkSelectInput.innerHTML = '';
  networks.forEach(function(network) {
    var quality = network.quality;
    var security = network.encryption !== 'none' ? 'Secure' : 'Open';
    var networkOption = document.createElement('option');
    networkOption.setAttribute('value', network.ssid);
    networkOption.innerText = quality + '% - ' + network.ssid + ' (' + security + ')';
    networkSelectInput.appendChild(networkOption);
    if (!document.getElementById(network.ssid + '.encryption')) {
      var encryptionOption = document.createElement('option');
      encryptionOption.setAttribute('value', network.encryption);
      encryptionOption.setAttribute('id', network.ssid + '.encryption');
      encryptionOption.setAttribute('hidden', '');
      encryptionOption.setAttribute('disabled', '');
      encryptionSelectInput.appendChild(encryptionOption);
    }
  });
  var hiddenNetworkOption = document.createElement('option');
  hiddenNetworkOption.setAttribute('value', 'invizbox.hidden-network');
  hiddenNetworkOption.innerText = 'Connect to Hidden Network';
  networkSelectInput.appendChild(hiddenNetworkOption);

  networkSelectInput.onchange = function onNetworkSelectChange(networkSelectChange) {
    var network = networkSelectChange.target.value;
    if (network === 'invizbox.hidden-network') {
      document.getElementById('cbi-wireless-wan-ssid').style.display = 'inline-block';
      document.getElementById('cbi-wireless-wan-encryption').style.display = 'inline-block';
      document.getElementById('cbi-wireless-wan-key').style.display = 'block';
      document.getElementById('cbid.wireless.wan.ssid').value = '';
      document.getElementById('cbid.wireless.wan.key').value = '';
      document.getElementById('cbid.wireless.wan.hidden_network').checked = true;
      encryptionSelectInput.selectedIndex = 0;
    } else {
      document.getElementById('cbi-wireless-wan-encryption').style.display = 'none';
      document.getElementById('cbi-wireless-wan-ssid').style.display = 'none';
      document.getElementById('cbid.wireless.wan.ssid').value = network;
      document.getElementById('cbid.wireless.wan.hidden_network').checked = false;
      encryptionSelectInput.value = document.getElementById(network + '.encryption').value;
      if (networks[networkSelectInput.selectedIndex].encryption === 'none') {
        document.getElementById('cbi-wireless-wan-key').style.display = 'none';
        document.getElementById('cbid.wireless.wan.key').value = '';
      } else {
        document.getElementById('cbi-wireless-wan-key').style.display = 'block';
      }
    }
  };

  encryptionSelectInput.onchange = function onEncryptionSelectChange(encryptionSelectChange) {
    if (encryptionSelectChange.target.value === 'none') {
      document.getElementById('cbi-wireless-wan-key').style.display = 'none';
      document.getElementById('cbid.wireless.wan.key').value = '';
    } else {
      document.getElementById('cbi-wireless-wan-key').style.display = 'block';
    }
  };

  var refreshButton = document.getElementById('choose-network-refresh-button');
  if (!refreshButton) {
    refreshButton = createRefreshButton();
    networkSelectInput.parentElement.appendChild(refreshButton);
  }

  if (document.getElementById('cbid.wireless.wan.hidden_network').checked) {
    networkSelectInput.value = 'invizbox.hidden-network';
  } else {
    var currentSSID = document.getElementById('currentssid');
    var currentSSIDFound = false;
    networks.forEach(function(network) {
      if (currentSSID && network.ssid === currentSSID.value) {
        networkSelectInput.value = network.ssid;
        currentSSIDFound = true;
      }
    });
    if (!currentSSIDFound) {
      document.getElementById('cbid.wireless.wan.key').value = '';
    }
    document.getElementById('cbid.wireless.wan.ssid').value = networkSelectInput.value;
    document.getElementById('cbi-wireless-wan-ssid').style.display = 'none';
    document.getElementById('cbi-wireless-wan-encryption').style.display = 'none';
    encryptionSelectInput.value = document.getElementById(networkSelectInput.value + '.encryption').value;
    if (encryptionSelectInput.value === 'none') {
      document.getElementById('cbi-wireless-wan-key').style.display = 'none';
    }
  }
  networkSelectInput.removeAttribute('name');
}

function createNetworkScanningLoader() {
  var loader = document.createElement('div');
  loader.setAttribute('id', 'choose-network-loader');
  var loadingIcon = document.createElement('img');
  loadingIcon.setAttribute('src', '/luci-static/resources/icons/loading.gif');
  loadingIcon.setAttribute('alt', 'Loading');
  loadingIcon.setAttribute('class', 'loading-spinner');
  loadingIcon.style.marginRight = '1rem';
  var loadingText = document.createElement('span');
  loadingText.textContent = 'Scanning for WiFi networks.';
  loader.appendChild(loadingIcon);
  loader.appendChild(loadingText);
  return loader;
}

function hideChooseNetworkForm() {
  var form = document.getElementById('cbi-wireless-wan');
  form.style.display = 'none';
  form.parentElement.appendChild(createNetworkScanningLoader());
  var finishButton = document.getElementById('Finish');
  if (finishButton) {
    var previousButton = document.getElementById('Previous');
    finishButton.setAttribute('disabled', "");
    previousButton.setAttribute('disabled', "");
  } else {
    var saveButton = document.getElementsByClassName('cbi-button cbi-button-apply')[0];
    saveButton.setAttribute('disabled', "");
  }
}

function revealChooseNetworkForm(networks) {
  document.getElementById('choose-network-loader').remove();
  addWifiNetworksToSelectInput(networks);
  var finishButton = document.getElementById('Finish');
  if (finishButton) {
    var previousButton = document.getElementById('Previous');
    finishButton.removeAttribute('disabled');
    previousButton.removeAttribute('disabled');
  } else {
    var saveButton = document.getElementsByClassName('cbi-button cbi-button-apply')[0];
    saveButton.removeAttribute('disabled');
  }
}

function wifiScan(reload) {
  hideChooseNetworkForm();
  var disconnectTimeout;
  var pollInterval;

  function getWifiNetworks(_reload) {
    var xhr = new XMLHttpRequest();
    xhr.open('GET', window.location.origin + '/cgi-bin/luci/basic/' + (_reload ? 'reload' : 'get') + '_wifi_networks');
    xhr.responseType = 'json';
    xhr.send();

    xhr.onload = function () {
      clearTimeout(disconnectTimeout);
      clearTimeout(pollInterval);
      revealChooseNetworkForm(xhr.response);
    };

    return xhr;
  }

  getWifiNetworks(reload);

  disconnectTimeout = setTimeout(function () {
    getWifiNetworks();
    var secondTimeout = setTimeout(function () {
      clearTimeout(secondTimeout);
      var disconnectAlert = document.createElement('div');
      disconnectAlert.setAttribute('class', 'alert-message warning');
      var disconnectText = document.createElement('p');
      disconnectText.innerHTML = 'Please reconnect to your InvizBox Go WiFi Hotspot.<br/>This page will then reload.';
      var loadingIcon = document.createElement('div');
      loadingIcon.innerHTML = '<img src="/luci-static/resources/icons/loading.gif" alt="Loading" style="vertical-align:middle;height:1.5rem;margin-right:1rem;" />';
      disconnectAlert.appendChild(disconnectText);
      disconnectAlert.appendChild(loadingIcon);
      var chooseNetworkLoader = document.getElementById('choose-network-loader');
      chooseNetworkLoader.innerHTML = disconnectAlert.outerHTML;
      pollInterval = setInterval(getWifiNetworks, 5 * 1000);
    }, 2 * 1000);
  }, 20 * 1000);

}
