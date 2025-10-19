import Foundation

// JavaScript shim injected into the background worker WKWebView.
// Provides a minimal chrome-like surface and a message bridge to Swift via
// window.webkit.messageHandlers.flowExtension.
struct BackgroundJSBridge {
    static let script: String = """
    (function(){
      if (window.__flowBackgroundBridgeInstalled) return;
      window.__flowBackgroundBridgeInstalled = true;

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

      // Minimal events registry used by native broadcast helpers
      window.flowBrowser = window.flowBrowser || { runtime: {
        _listeners: new Map(),
        getEventListeners: function(name) { return this._listeners.get(name) || []; },
        _add: function(name, fn) {
          var arr = this._listeners.get(name) || [];
          arr.push(fn);
          this._listeners.set(name, arr);
        }
      }};

      // Minimal chrome.* surface for background
      var chrome = window.chrome = window.chrome || {};

      // runtime
      chrome.runtime = chrome.runtime || {};
      chrome.runtime.onStartup = chrome.runtime.onStartup || { addListener: function(fn){ window.flowBrowser.runtime._add('runtime.onStartup', fn); }, removeListener: function(fn){} };
      chrome.runtime.onMessage = chrome.runtime.onMessage || { addListener: function(fn){
        try { window.__flowBgOnMessageCount = (window.__flowBgOnMessageCount||0) + 1; } catch(e){}
        window.flowBrowser.runtime._add('runtime.onMessage', fn);
        try { if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.flowExtension) { window.webkit.messageHandlers.flowExtension.postMessage({ api: 'debug', method: 'onMessageAdded', count: window.__flowBgOnMessageCount }); } } catch(e){}
      } };

      // Diagnostics to verify background world visibility of chrome/runtime
      try {
        function __flowDiag(label){
          try {
            var count = 0;
            try { var ls = (window.flowBrowser && window.flowBrowser.runtime && window.flowBrowser.runtime.getEventListeners) ? window.flowBrowser.runtime.getEventListeners('runtime.onMessage') : null; count = (ls && ls.length) || 0; } catch (e) {}
            var types = {
              chrome: typeof chrome,
              runtime: typeof (chrome && chrome.runtime),
              onMessage: typeof (chrome && chrome.runtime && chrome.runtime.onMessage),
              addListener: typeof (chrome && chrome.runtime && chrome.runtime.onMessage && chrome.runtime.onMessage.addListener),
              listenerCount: count,
              href: (document && document.location && document.location.href) || ''
            };
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.flowExtension) {
              window.webkit.messageHandlers.flowExtension.postMessage({ api:'debug', method:'diag', label: String(label||''), types: types });
            }
          } catch (e) {}
        }
        // Run a few staged diagnostics during startup
        __flowDiag('bridge-init');
        setTimeout(function(){ __flowDiag('t+100'); }, 100);
        setTimeout(function(){ __flowDiag('t+500'); }, 500);
        setTimeout(function(){ __flowDiag('t+1500'); }, 1500);
      } catch (e) {}
      chrome.runtime.onConnect = chrome.runtime.onConnect || { addListener: function(fn){ window.flowBrowser.runtime._add('runtime.onConnect', fn); } };
      chrome.runtime.getURL = chrome.runtime.getURL || function(path){
        try {
          var base = document.baseURI || location.href;
          var p = String(path || '');
          if (p.startsWith('/')) p = p.slice(1);
          return new URL(p, base).toString();
        } catch (e) { return String(path || ''); }
      };
      chrome.runtime.lastError = null;

      // i18n
      chrome.i18n = chrome.i18n || {};
      chrome.i18n.getMessage = function(key, substitutions){
        return __flowCall({ api: 'i18n', method: 'getMessage', params: { key: key, substitutions: substitutions || null } });
      };

      // storage
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
      chrome.storage = chrome.storage || {};
      chrome.storage.local = chrome.storage.local || makeStorageArea('local');
      chrome.storage.session = chrome.storage.session || makeStorageArea('session');
      // Provide a minimal sync shim to avoid immediate crashes during init
      chrome.storage.sync = chrome.storage.sync || Object.assign(makeStorageArea('sync'), { QUOTA_BYTES_PER_ITEM: 8192 });

      // alarms
      chrome.alarms = chrome.alarms || {};
      chrome.alarms.create = function(name, alarmInfo, callback){
        __flowCall({ api: 'alarms', method: 'create', params: { name: name || '', alarmInfo: alarmInfo || {} } })
          .then(function(){ if (callback) try { callback(); } catch(e) {} });
      };
      chrome.alarms.get = function(name, callback){
        __flowCall({ api: 'alarms', method: 'get', params: { name: name || '' } })
          .then(function(res){ if (callback) try { callback(res || null); } catch(e) {} });
      };
      chrome.alarms.getAll = function(callback){
        __flowCall({ api: 'alarms', method: 'getAll', params: {} })
          .then(function(res){ if (callback) try { callback(res || []); } catch(e) {} });
      };
      chrome.alarms.clear = function(name, callback){
        __flowCall({ api: 'alarms', method: 'clear', params: { name: name } })
          .then(function(res){ if (callback) try { callback(res); } catch(e) {} });
      };
      chrome.alarms.clearAll = function(callback){
        __flowCall({ api: 'alarms', method: 'clearAll', params: {} })
          .then(function(res){ if (callback) try { callback(res); } catch(e) {} });
      };
      chrome.alarms.onAlarm = { addListener: function(fn){ window.flowBrowser.runtime._add('alarms.onAlarm', fn); } };

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
      chrome.runtime.sendMessage = function(message, responseCallback){
        __flowCall({ api: 'runtime', method: 'sendMessage', params: { message: message } })
          .then(function(res){ if (responseCallback) try { responseCallback(res); } catch(e){} });
      };
      chrome.runtime.connect = function(connectInfo){
        var name = connectInfo && connectInfo.name || '';
        var id = String(Math.floor(Math.random()*1e9)) + String(Date.now());
        __flowCall({ api: 'runtime', method: 'connect', params: { name: name, portId: id } });
        return window.__flowCreatePort(id, name);
      };

      // Placeholders for APIs referenced by Dark Reader during init
      chrome.action = chrome.action || { setIcon: function(){}, setBadgeText: function(){}, setBadgeBackgroundColor: function(){} };
      chrome.commands = chrome.commands || { getAll: function(cb){ if (cb) try { cb([]); } catch(e) {} }, onCommand: { addListener: function(fn){ window.flowBrowser.runtime._add('commands.onCommand', fn); } } };
      chrome.contextMenus = chrome.contextMenus || {};
      chrome.contextMenus.onClicked = chrome.contextMenus.onClicked || { addListener: function(fn){ window.flowBrowser.runtime._add('contextMenus.onClicked', fn); } };
      chrome.contextMenus.create = function(createProperties, callback){
        return __flowCall({ api: 'contextMenus', method: 'create', params: { createProperties: createProperties || {} } })
          .then(function(id){ if (callback) try { callback(id); } catch(e){}; return id; });
      };
      chrome.contextMenus.removeAll = function(callback){
        return __flowCall({ api: 'contextMenus', method: 'removeAll', params: {} })
          .then(function(){ if (callback) try { callback(); } catch(e){}; });
      };
      chrome.contextMenus.remove = function(menuItemId, callback){
        return __flowCall({ api: 'contextMenus', method: 'remove', params: { menuItemId: menuItemId } })
          .then(function(){ if (callback) try { callback(); } catch(e){}; });
      };
      chrome.scripting = chrome.scripting || {};
      chrome.scripting.executeScript = function(options, callback){
        var target = options && options.target || {};
        var payload = { api: 'scripting', method: 'executeScript', params: { target: target } };
        if (options && options.world) payload.world = options.world;
        if (options && options.injectImmediately != null) payload.injectImmediately = !!options.injectImmediately;
        if (options && Array.isArray(options.files)) {
          payload.files = options.files.slice();
        } else if (options && typeof options.func === 'function') {
          try {
            payload.func = String(options.func);
            if (Array.isArray(options.args)) payload.args = options.args.slice();
          } catch (e) {
            // ignore
          }
        }
        return __flowCall(payload).then(function(res){ if (callback) try { callback(res); } catch(e){}; return res; });
      };
      chrome.scripting.registerContentScripts = chrome.scripting.registerContentScripts || function(){};
      chrome.scripting.unregisterContentScripts = chrome.scripting.unregisterContentScripts || function(){};
      chrome.scripting.getRegisteredContentScripts = chrome.scripting.getRegisteredContentScripts || function(cb){ if (cb) try { cb([]); } catch(e) {} };
      // fontSettings (optional in background)
      chrome.fontSettings = chrome.fontSettings || {};
      chrome.fontSettings.getFontList = function(callback){
        return __flowCall({ api: 'fontSettings', method: 'getFontList', params: {} })
          .then(function(list){ if (callback) try { callback(Array.isArray(list) ? list : []); } catch(e){}; return list; });
      };
      // notifications API (minimal)
      chrome.notifications = chrome.notifications || {};
      chrome.notifications.onClicked = chrome.notifications.onClicked || { addListener: function(fn){ window.flowBrowser.runtime._add('notifications.onClicked', fn); } };
      chrome.notifications.onClosed = chrome.notifications.onClosed || { addListener: function(fn){ window.flowBrowser.runtime._add('notifications.onClosed', fn); } };
      chrome.notifications.create = function(idOrOptions, optionsOrCb, cb){
        var nid = null, opts = null, callback = null;
        if (typeof idOrOptions === 'string') { nid = idOrOptions; opts = optionsOrCb || {}; callback = cb; }
        else { opts = idOrOptions || {}; callback = optionsOrCb; }
        return __flowCall({ api: 'notifications', method: 'create', params: { notificationId: nid, options: opts } }).then(function(id){ if (callback) try { callback(String(id || '')); } catch(e){}; return id; });
      };
      // Network shims for background contexts (MV2 background page or MV3 worker shell)
      try {
        // fetch shim: route through native to enforce host permissions and bypass CORS
        var __origFetch = window.fetch;
        window.fetch = function(input, init){
          var url = (typeof input === 'string') ? input : (input && input.url) || String(input || '');
          var o = init || {};
          var hdrs = {};
          try {
            if (o.headers) {
              if (o.headers instanceof Headers) { o.headers.forEach(function(v,k){ hdrs[k] = v; }); }
              else if (Array.isArray(o.headers)) { o.headers.forEach(function(pair){ if (pair && pair.length === 2) hdrs[pair[0]] = pair[1]; }); }
              else if (typeof o.headers === 'object') { hdrs = Object.assign({}, o.headers); }
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
          XHRShim.prototype.setRequestHeader = function(name, value){ this._headers[String(name)] = String(value); };
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
      } catch (e) {}
      chrome.tabs = chrome.tabs || {};
      chrome.tabs.onCreated = chrome.tabs.onCreated || { addListener: function(fn){ window.flowBrowser.runtime._add('tabs.onCreated', fn); } };
      chrome.tabs.onUpdated = chrome.tabs.onUpdated || { addListener: function(fn){ window.flowBrowser.runtime._add('tabs.onUpdated', fn); } };
      chrome.tabs.onRemoved = chrome.tabs.onRemoved || { addListener: function(fn){ window.flowBrowser.runtime._add('tabs.onRemoved', fn); } };
      chrome.tabs.query = chrome.tabs.query || function(q, cb){ __flowCall({ api: 'tabs', method: 'query', params: q || {} }).then(function(res){ if (cb) try { cb(res || []); } catch(e) {} }); };
      chrome.tabs.get = chrome.tabs.get || function(id, cb){ __flowCall({ api: 'tabs', method: 'get', params: { tabId: id } }).then(function(res){ if (cb) try { cb(res || null); } catch(e) {} }); };
      chrome.tabs.sendMessage = chrome.tabs.sendMessage || function(tabId, message, options, callback){
        if (typeof options === 'function') { callback = options; options = {}; }
        var params = { tabId: String(tabId), message: message || {}, options: options || {} };
        return __flowCall({ api: 'tabs', method: 'sendMessage', params: params }).then(function(res){ if (callback) try { callback(res); } catch(e){}; return res; });
      };
      chrome.permissions = chrome.permissions || { onRemoved: { addListener: function(fn){ window.flowBrowser.runtime._add('permissions.onRemoved', fn); } }, contains: function(p, cb){ __flowCall({ api: 'permissions', method: 'contains', params: { permissions: p && p.permissions || [] } }).then(function(res){ if (cb) try { cb(!!res); } catch(e) {} }); } };

      // Extra diagnostics: patch Messenger once available to trace GET_DATA path
      try {
        (function(){
          function post(msg){ try { window.webkit.messageHandlers.flowExtension.postMessage(msg); } catch(e){} }
          var attempts = 100;
          var int = setInterval(function(){
            try {
              if (typeof Messenger !== 'undefined' && Messenger && !Messenger.__flowDiagPatched) {
                // Wrap messageListener to log sender/allowed check
                if (typeof Messenger.messageListener === 'function') {
                  var orig = Messenger.messageListener;
                  Messenger.messageListener = function(message, sender, sendResponse){
                    try {
                      var allowed = [
                        chrome.runtime.getURL('/ui/popup/index.html'),
                        chrome.runtime.getURL('/ui/devtools/index.html'),
                        chrome.runtime.getURL('/ui/options/index.html'),
                        chrome.runtime.getURL('/ui/stylesheet-editor/index.html')
                      ];
                      post({ api:'debug', method:'messengerMessage', msgType: (message&&message.type)||'', senderUrl: (sender&&sender.url)||'', allowed0: allowed[0] });
                    } catch (e) {}
                    return orig.apply(this, arguments);
                  };
                }
                // Wrap adapter.collect to see if GET_DATA resolves/rejects
                if (Messenger.adapter && typeof Messenger.adapter.collect === 'function') {
                  var origCollect = Messenger.adapter.collect;
                  Messenger.adapter.collect = function(){
                    post({ api:'debug', method:'collectStart' });
                    try {
                      var p = origCollect.apply(this, arguments);
                      if (p && typeof p.then === 'function') {
                        return p.then(function(r){ post({ api:'debug', method:'collectDone' }); return r; })
                                .catch(function(err){ post({ api:'debug', method:'collectError', error: String(err) }); throw err; });
                      }
                      post({ api:'debug', method:'collectSync' });
                      return p;
                    } catch (e) {
                      post({ api:'debug', method:'collectThrow', error: String(e) });
                      throw e;
                    }
                  };
                }
                Messenger.__flowDiagPatched = true;
                post({ api:'debug', method:'messengerPatched' });
                clearInterval(int);
              }
            } catch (e) {}
            if (--attempts <= 0) { clearInterval(int); }
          }, 50);
        })();
      } catch (e) {}
    })();
    """
}
