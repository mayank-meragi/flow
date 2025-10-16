import Foundation
import WebKit

enum RequestDecision {
    case allow
    case block
}

protocol NetworkHandler {
    func getContentRuleLists() -> [WKContentRuleList]
    func shouldProcessRequest(
        _ request: URLRequest, completion: @escaping (RequestDecision) -> Void)
}
