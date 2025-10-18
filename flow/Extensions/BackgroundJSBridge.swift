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
      chrome.runtime.onMessage = chrome.runtime.onMessage || { addListener: function(fn){ window.flowBrowser.runtime._add('runtime.onMessage', fn); } };
      chrome.runtime.onConnect = chrome.runtime.onConnect || { addListener: function(fn){ window.flowBrowser.runtime._add('runtime.onConnect', fn); } };
      chrome.runtime.getURL = chrome.runtime.getURL || function(path){ try { return new URL(path || '', document.baseURI || location.href).toString(); } catch (e) { return String(path || ''); } };
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
      chrome.contextMenus = chrome.contextMenus || { create: function(){}, removeAll: function(cb){ if (cb) try { cb(); } catch(e) {} }, onClicked: { addListener: function(fn){ window.flowBrowser.runtime._add('contextMenus.onClicked', fn); } } };
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
      chrome.tabs = chrome.tabs || {};
      chrome.tabs.onRemoved = chrome.tabs.onRemoved || { addListener: function(fn){ window.flowBrowser.runtime._add('tabs.onRemoved', fn); } };
      chrome.tabs.query = chrome.tabs.query || function(q, cb){ __flowCall({ api: 'tabs', method: 'query', params: q || {} }).then(function(res){ if (cb) try { cb(res || []); } catch(e) {} }); };
      chrome.tabs.get = chrome.tabs.get || function(id, cb){ __flowCall({ api: 'tabs', method: 'get', params: { tabId: id } }).then(function(res){ if (cb) try { cb(res || null); } catch(e) {} }); };
      chrome.tabs.sendMessage = chrome.tabs.sendMessage || function(tabId, message, options, callback){
        if (typeof options === 'function') { callback = options; options = {}; }
        var params = { tabId: String(tabId), message: message || {}, options: options || {} };
        return __flowCall({ api: 'tabs', method: 'sendMessage', params: params }).then(function(res){ if (callback) try { callback(res); } catch(e){}; return res; });
      };
      chrome.permissions = chrome.permissions || { onRemoved: { addListener: function(fn){ window.flowBrowser.runtime._add('permissions.onRemoved', fn); } }, contains: function(p, cb){ __flowCall({ api: 'permissions', method: 'contains', params: { permissions: p && p.permissions || [] } }).then(function(res){ if (cb) try { cb(!!res); } catch(e) {} }); } };
    })();
    """
}
