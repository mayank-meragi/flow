import Foundation
import WebKit

// Aggregates NetworkHandler decisions across all loaded extensions.
// Current scope: top-level/frame navigations via WKNavigationDelegate.
// If any handler requests block, we block the navigation.
enum NetworkInterception {
    static func shouldAllow(navigationAction: WKNavigationAction,
                             extensionManager: ExtensionManager?,
                             completion: @escaping (Bool) -> Void) {
        guard let mgr = extensionManager,
              let request = navigationAction.request as URLRequest? else {
            completion(true); return
        }
        // Only HTTP(S) navigations are considered; others allowed
        if let scheme = request.url?.scheme?.lowercased(), !(scheme == "http" || scheme == "https") {
            completion(true); return
        }
        let handlers: [NetworkHandler] = mgr.extensions.values.map { $0.runtime.networkHandler }
        if handlers.isEmpty { completion(true); return }

        let group = DispatchGroup()
        var shouldBlock = false
        let lock = NSLock()

        for h in handlers {
            group.enter()
            h.shouldProcessRequest(request) { decision in
                if case .block = decision {
                    lock.lock(); shouldBlock = true; lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(!shouldBlock)
        }
    }
}

