import Foundation
import WebKit

class DeclarativeNetRequestHandler: NetworkHandler {
    func getContentRuleLists() -> [WKContentRuleList] {
        return []
    }

    func shouldProcessRequest(
        _ request: URLRequest, completion: @escaping (RequestDecision) -> Void
    ) {
        completion(.allow)
    }
}
