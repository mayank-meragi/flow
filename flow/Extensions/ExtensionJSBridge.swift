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
        __flowCall({ api: 'tabs', method: 'create', params: createProperties || {} })
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

