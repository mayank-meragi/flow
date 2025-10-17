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

      // Skeleton for events used by native broadcast helpers (optional)
      window.flowBrowser = window.flowBrowser || { runtime: {
        _listeners: new Map(),
        getEventListeners: function(name) { return this._listeners.get(name) || []; },
        onMessage: { addListener: function(fn){
          var arr = window.flowBrowser.runtime._listeners.get('runtime.onMessage') || [];
          arr.push(fn);
          window.flowBrowser.runtime._listeners.set('runtime.onMessage', arr);
        }}
      }};
    })();
    """
}
