import Foundation

// Provides the JavaScript shim injected into extension pages (popup/options)
// to expose a minimal Chrome-like API and a message bridge to Swift via
// window.webkit.messageHandlers.flowExtension.
struct ExtensionJSBridge {
    static let script: String = """
    (function(){
      if (window.__flowExtensionBridgeInstalled) return;
      window.__flowExtensionBridgeInstalled = true;

      // Callback table for async replies from native code
      window.flowExtensionCallbacks = window.flowExtensionCallbacks || {};
      window.__flowCbSeq = window.__flowCbSeq || 1;

      function __flowCall(payload) {
        return new Promise(function(resolve, reject) {
          var id = window.__flowCbSeq++;
          window.flowExtensionCallbacks[id] = function(result) {
            try { resolve(result); } catch (e) {}
          };
          try {
            var msg = Object.assign({}, payload, { callbackId: id });
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.flowExtension) {
              window.webkit.messageHandlers.flowExtension.postMessage(msg);
            } else {
              reject('flowExtension handler missing');
            }
          } catch (e) {
            reject(e);
          }
        });
      }

      // Minimal chrome.* surface
      window.chrome = window.chrome || {};
      window.chrome.tabs = window.chrome.tabs || {};
      window.chrome.tabs.create = function(createProperties, callback) {
        try { console.log('[chrome.tabs.create] props=', createProperties); } catch(e) {}
        __flowCall({ api: 'tabs', method: 'create', params: createProperties || {} })
          .then(function(res){ if (callback) try { callback(res); } catch(e) {} });
      };
      window.chrome.tabs.query = function(queryInfo, callback) {
        try { console.log('[chrome.tabs.query] info=', queryInfo); } catch(e) {}
        __flowCall({ api: 'tabs', method: 'query', params: queryInfo || {} })
          .then(function(res){ if (callback) try { callback(res); } catch(e) {} });
      };
      window.chrome.tabs.update = function(tabIdOrProps, updateProperties, callback) {
        var tabId, props, cb = callback;
        if (typeof tabIdOrProps === 'number' || typeof tabIdOrProps === 'string') {
          tabId = String(tabIdOrProps);
          props = updateProperties || {};
        } else {
          props = updateProperties || tabIdOrProps || {};
        }
        try { console.log('[chrome.tabs.update] tabId=', tabId, 'props=', props); } catch(e) {}
        __flowCall({ api: 'tabs', method: 'update', params: { tabId: tabId, updateProperties: props } })
          .then(function(res){ if (cb) try { cb(res); } catch(e) {} });
      };
      window.chrome.tabs.remove = function(tabIds, callback) {
        var params = Array.isArray(tabIds) ? { tabIds: tabIds } : { tabId: tabIds };
        __flowCall({ api: 'tabs', method: 'remove', params: params })
          .then(function(res){ if (callback) try { callback(res); } catch(e) {} });
      };
      window.chrome.tabs.group = function(groupOptions, callback) {
        try { console.log('[chrome.tabs.group] options=', groupOptions); } catch(e) {}
        __flowCall({ api: 'tabs', method: 'group', params: groupOptions || {} })
          .then(function(res){ if (callback) try { callback(res); } catch(e) {} });
      };
      window.chrome.tabs.ungroup = function(tabIds, callback) {
        var params = Array.isArray(tabIds) ? { tabIds: tabIds } : { tabId: tabIds };
        try { console.log('[chrome.tabs.ungroup] params=', params); } catch(e) {}
        __flowCall({ api: 'tabs', method: 'ungroup', params: params })
          .then(function(res){ if (callback) try { callback(res); } catch(e) {} });
      };
      window.chrome.tabs.reload = function(tabId, reloadProperties, callback) {
        var tId = (typeof tabId === 'number' || typeof tabId === 'string') ? String(tabId) : undefined;
        var props = (typeof tabId === 'object' && tabId !== null) ? tabId : (reloadProperties || {});
        var cb = (typeof reloadProperties === 'function') ? reloadProperties : callback;
        try { console.log('[chrome.tabs.reload] tabId=', tId, 'props=', props); } catch(e) {}
        __flowCall({ api: 'tabs', method: 'reload', params: { tabId: tId, reloadProperties: props } })
          .then(function(res){ if (cb) try { cb(res); } catch(e) {} });
      };
      window.chrome.tabs.get = function(tabId, callback) {
        try { console.log('[chrome.tabs.get] tabId=', tabId); } catch(e) {}
        __flowCall({ api: 'tabs', method: 'get', params: { tabId: tabId } })
          .then(function(res){ if (callback) try { callback(res); } catch(e) {} });
      };
      window.chrome.tabs.getCurrent = function(callback) {
        try { console.log('[chrome.tabs.getCurrent]'); } catch(e) {}
        __flowCall({ api: 'tabs', method: 'getCurrent', params: {} })
          .then(function(res){ if (callback) try { callback(res); } catch(e) {} });
      };
      window.chrome.tabs.duplicate = function(tabId, callback) {
        try { console.log('[chrome.tabs.duplicate] tabId=', tabId); } catch(e) {}
        __flowCall({ api: 'tabs', method: 'duplicate', params: { tabId: tabId } })
          .then(function(res){ if (callback) try { callback(res); } catch(e) {} });
      };
      window.chrome.tabs.sendMessage = function(tabId, message, options, callback) {
        if (typeof options === 'function') { callback = options; options = {}; }
        var params = { tabId: String(tabId), message: message || {}, options: options || {} };
        __flowCall({ api: 'tabs', method: 'sendMessage', params: params })
          .then(function(res){ if (callback) try { callback(res); } catch(e){} });
      };

      // chrome.tabGroups namespace
      window.chrome.tabGroups = window.chrome.tabGroups || {};
      window.chrome.tabGroups.query = function(queryInfo, callback) {
        try { console.log('[chrome.tabGroups.query] info=', queryInfo); } catch(e) {}
        __flowCall({ api: 'tabGroups', method: 'query', params: queryInfo || {} })
          .then(function(res){ if (callback) try { callback(res); } catch(e) {} });
      };
      window.chrome.tabGroups.update = function(groupId, updateProperties, callback) {
        try { console.log('[chrome.tabGroups.update] groupId=', groupId, 'props=', updateProperties); } catch(e) {}
        __flowCall({ api: 'tabGroups', method: 'update', params: { groupId: groupId, updateProperties: updateProperties || {} } })
          .then(function(res){ if (callback) try { callback(res); } catch(e) {} });
      };
      window.chrome.tabGroups.get = function(groupId, callback) {
        try { console.log('[chrome.tabGroups.get] groupId=', groupId); } catch(e) {}
        __flowCall({ api: 'tabGroups', method: 'get', params: { groupId: groupId } })
          .then(function(res){ if (callback) try { callback(res); } catch(e) {} });
      };

      // Skeleton for events used by native broadcast helpers (optional)
      window.flowBrowser = window.flowBrowser || { runtime: {
        _listeners: new Map(),
        getEventListeners: function(name) { return this._listeners.get(name) || []; },
        _add: function(name, fn) {
          var arr = this._listeners.get(name) || [];
          arr.push(fn);
          this._listeners.set(name, arr);
        },
        onMessage: { addListener: function(fn){
          var arr = window.flowBrowser.runtime._listeners.get('runtime.onMessage') || [];
          arr.push(fn);
          window.flowBrowser.runtime._listeners.set('runtime.onMessage', arr);
        }},
        onConnect: { addListener: function(fn){
          var arr = window.flowBrowser.runtime._listeners.get('runtime.onConnect') || [];
          arr.push(fn);
          window.flowBrowser.runtime._listeners.set('runtime.onConnect', arr);
        }}
      }};

      // Bridge CustomEvent from native/main-world into this world
      try {
        document.addEventListener('__flowRuntimeMessage', function(ev){
          try {
            var msg = ev && ev.detail;
            var ls = window.flowBrowser.runtime.getEventListeners('runtime.onMessage');
            (ls || []).forEach(function(fn){ try { fn(msg); } catch(e){} });
          } catch(e) {}
        });
      } catch (e) {}

      // Ports registry and helpers used by native to dispatch messages
      window.__flowPorts = window.__flowPorts || new Map();
      window.__flowCreatePort = window.__flowCreatePort || function(id, name){
        var listeners = [];
        var port = {
          name: name || '',
          onMessage: { addListener: function(fn){ listeners.push(fn); } },
          postMessage: function(msg){
            __flowCall({ api: 'runtime', method: 'postPortMessage', params: { portId: id, message: msg } });
          },
          disconnect: function(){ __flowCall({ api: 'runtime', method: 'disconnectPort', params: { portId: id } }); }
        };
        port._listeners = listeners;
        window.__flowPorts.set(id, port);
        return port;
      };
      window.__flowDispatchPortMessage = window.__flowDispatchPortMessage || function(id, msg){
        var p = window.__flowPorts.get(id);
        if (!p) return;
        var ls = p._listeners || [];
        ls.forEach(function(fn){ try { fn(msg); } catch(e){} });
      };

      // runtime messaging API
      window.chrome.runtime = window.chrome.runtime || {};
      // Event surfaces to mirror background behavior
      window.chrome.runtime.onMessage = window.chrome.runtime.onMessage || { addListener: function(fn){ window.flowBrowser.runtime._add('runtime.onMessage', fn); } };
      window.chrome.runtime.onConnect = window.chrome.runtime.onConnect || { addListener: function(fn){ window.flowBrowser.runtime._add('runtime.onConnect', fn); } };
      // Align with background: resolve extension-relative URLs
      window.chrome.runtime.getURL = window.chrome.runtime.getURL || function(path){
        try {
          var base = document.baseURI || location.href;
          var p = String(path || '');
          // For file:// base, treat absolute-like paths as relative to extension root
          if (p.startsWith('/')) p = p.slice(1);
          return new URL(p, base).toString();
        } catch (e) { return String(path || ''); }
      };
      window.chrome.runtime.sendMessage = function(message, responseCallback){
        __flowCall({ api: 'runtime', method: 'sendMessage', params: { message: message } })
          .then(function(res){ if (responseCallback) try { responseCallback(res); } catch(e){} });
      };
      window.chrome.runtime.connect = function(connectInfo){
        var name = connectInfo && connectInfo.name || '';
        var id = String(Math.floor(Math.random()*1e9)) + String(Date.now());
        __flowCall({ api: 'runtime', method: 'connect', params: { name: name, portId: id } });
        return window.__flowCreatePort(id, name);
      };

      // i18n API (synchronous-friendly shim for getMessage)
      window.chrome.i18n = window.chrome.i18n || {};
      window.__flowI18nCache = window.__flowI18nCache || {};
      window.chrome.i18n.getMessage = function(key, substitutions){
        // Return cached or empty string immediately to avoid crashes; fetch async to warm cache.
        try {
          __flowCall({ api: 'i18n', method: 'getMessage', params: { key: key, substitutions: substitutions || null } })
            .then(function(res){ try { window.__flowI18nCache[key] = res || ''; } catch(e){} });
        } catch (e) {}
        if (window.__flowI18nCache && (key in window.__flowI18nCache)) return window.__flowI18nCache[key] || '';
        return '';
      };
      window.chrome.i18n.getUILanguage = window.chrome.i18n.getUILanguage || function(){
        try { return (navigator.language || navigator.userLanguage || 'en') || 'en'; } catch (e) { return 'en'; }
      };

      // storage API (local and session)
      function makeStorageArea(areaName){
        var area = {};
        area.get = function(keys, callback){
          var arr = Array.isArray(keys) ? keys : (keys ? [keys] : []);
          __flowCall({ api: 'storage', area: areaName, method: 'get', params: { keys: arr } })
            .then(function(res){ if (callback) try { callback(res || {}); } catch(e) {} });
        };
        area.set = function(items, callback){
          __flowCall({ api: 'storage', area: areaName, method: 'set', params: { items: items || {} } })
            .then(function(){ if (callback) try { callback(); } catch(e) {} });
        };
        area.remove = function(keys, callback){
          var arr = Array.isArray(keys) ? keys : (keys ? [keys] : []);
          __flowCall({ api: 'storage', area: areaName, method: 'remove', params: { keys: arr } })
            .then(function(){ if (callback) try { callback(); } catch(e) {} });
        };
        area.clear = function(callback){
          __flowCall({ api: 'storage', area: areaName, method: 'clear', params: {} })
            .then(function(){ if (callback) try { callback(); } catch(e) {} });
        };
        area.onChanged = { addListener: function(fn){ window.flowBrowser.runtime._add('storage.onChanged', fn); } };
        return area;
      }
      window.chrome.storage = window.chrome.storage || {};
      window.chrome.storage.local = window.chrome.storage.local || makeStorageArea('local');
      window.chrome.storage.session = window.chrome.storage.session || makeStorageArea('session');

      // windows API (minimal)
      window.chrome.windows = window.chrome.windows || {};
      window.chrome.windows.getAll = function(getInfo, callback){
        __flowCall({ api: 'windows', method: 'getAll', params: getInfo || {} })
          .then(function(res){ if (callback) try { callback(res || []); } catch(e){} });
      };
      window.chrome.windows.update = function(windowId, updateInfo, callback){
        __flowCall({ api: 'windows', method: 'update', params: { windowId: windowId, updateInfo: updateInfo || {} } })
          .then(function(res){ if (callback) try { callback(res || null); } catch(e){} });
      };
      window.chrome.windows.create = function(createData, callback){
        __flowCall({ api: 'windows', method: 'create', params: createData || {} })
          .then(function(res){ if (callback) try { callback(res || null); } catch(e){} });
      };

      // fontSettings API (native-backed)
      window.chrome.fontSettings = window.chrome.fontSettings || {};
      window.chrome.fontSettings.getFontList = function(callback){
        __flowCall({ api: 'fontSettings', method: 'getFontList', params: {} })
          .then(function(list){ if (callback) try { callback(Array.isArray(list) ? list : []); } catch(e){} });
      };

      // notifications API (minimal; mainly used by background, but expose here for parity)
      window.chrome.notifications = window.chrome.notifications || {};
      window.chrome.notifications.onClicked = window.chrome.notifications.onClicked || { addListener: function(fn){ window.flowBrowser.runtime._add('notifications.onClicked', fn); } };
      window.chrome.notifications.onClosed = window.chrome.notifications.onClosed || { addListener: function(fn){ window.flowBrowser.runtime._add('notifications.onClosed', fn); } };
      window.chrome.notifications.create = function(idOrOptions, optionsOrCb, cb){
        var nid = null, opts = null, callback = null;
        if (typeof idOrOptions === 'string') { nid = idOrOptions; opts = optionsOrCb || {}; callback = cb; }
        else { opts = idOrOptions || {}; callback = optionsOrCb; }
        __flowCall({ api: 'notifications', method: 'create', params: { notificationId: nid, options: opts } })
          .then(function(id){ if (callback) try { callback(String(id || '')); } catch(e){} });
      };

      // Network shims for MV2 Extension Pages only
      try {
        if (window.__flowExtensionPage) {
          // fetch shim: route through native to enforce host permissions and bypass CORS
          var __origFetch = window.fetch;
          window.fetch = function(input, init){
            var url = (typeof input === 'string') ? input : (input && input.url) || String(input || '');
            var o = init || {};
            var hdrs = {};
            try {
              if (o.headers) {
                if (o.headers instanceof Headers) {
                  o.headers.forEach(function(v,k){ hdrs[k] = v; });
                } else if (Array.isArray(o.headers)) {
                  o.headers.forEach(function(pair){ if (pair && pair.length === 2) hdrs[pair[0]] = pair[1]; });
                } else if (typeof o.headers === 'object') {
                  hdrs = Object.assign({}, o.headers);
                }
              }
            } catch (e) {}
            var body = (typeof o.body === 'string') ? o.body : null;
            return __flowCall({ api: 'network', method: 'fetch', params: { url: url, options: { method: (o.method || 'GET'), headers: hdrs, body: body } } })
              .then(function(res){
                if (!res || res._error) { throw new TypeError(res && res._error || 'Network error'); }
                var h = new Headers(res.headers || {});
                var bodyText = (res.bodyText != null) ? String(res.bodyText) : '';
                return new Response(bodyText, { status: res.status || 0, statusText: res.statusText || '', headers: h });
              });
          };

          // Minimal XMLHttpRequest shim over network.fetch (async only)
          (function(){
            function XHRShim(){
              this.readyState = 0; // UNSENT
              this.responseText = '';
              this.status = 0;
              this.statusText = '';
              this.onreadystatechange = null;
              this.onload = null;
              this.onerror = null;
              this._headers = {};
              this._method = 'GET';
              this._url = '';
            }
            XHRShim.prototype.open = function(method, url, async){
              this._method = String(method || 'GET');
              this._url = String(url || '');
              this.readyState = 1; // OPENED
              if (typeof this.onreadystatechange === 'function') try { this.onreadystatechange(); } catch(e){}
            };
            XHRShim.prototype.setRequestHeader = function(name, value){
              this._headers[String(name)] = String(value);
            };
            XHRShim.prototype.send = function(body){
              var self = this;
              var b = (typeof body === 'string') ? body : null;
              __flowCall({ api: 'network', method: 'fetch', params: { url: self._url, options: { method: self._method, headers: self._headers, body: b } } })
                .then(function(res){
                  if (!res || res._error) { throw new Error(res && res._error || 'Network error'); }
                  self.status = res.status || 0;
                  self.statusText = res.statusText || '';
                  self.responseText = (res.bodyText != null) ? String(res.bodyText) : '';
                  self.readyState = 4; // DONE
                  if (typeof self.onreadystatechange === 'function') try { self.onreadystatechange(); } catch(e){}
                  if (typeof self.onload === 'function') try { self.onload(); } catch(e){}
                })
                .catch(function(){
                  self.status = 0; self.statusText = 'error'; self.readyState = 4;
                  if (typeof self.onreadystatechange === 'function') try { self.onreadystatechange(); } catch(e){}
                  if (typeof self.onerror === 'function') try { self.onerror(); } catch(e){}
                });
            };
            try { window.XMLHttpRequest = XHRShim; } catch (e) {}
          })();
        }
      } catch (e) {}
    })();
    """
}
