# WebExtensions Architecture Design

**Status:** Proposed
**Date:** 2025-10-16

## 1. Overview

This document outlines the proposed architecture for integrating a WebExtensions runtime into the Flow browser. The goal is to support modern browser extensions, providing users with powerful customization and functionality.

Our strategy is to be pragmatic and phased:

1.  **MV3-First:** Prioritize support for Manifest V3 extensions. This aligns with the modern direction of the extension ecosystem and leverages native WebKit features for better performance and security.
2.  **Architect for the Future:** Design the system with clear abstraction layers that leave room to implement Manifest V2 features later, without requiring a full rewrite.

The primary technical challenge is that Apple's WebKit engine does not natively support the WebExtensions APIs (`browser.*` or `chrome.*`). Therefore, we must build a runtime environment that simulates these APIs and bridges communication between an extension's JavaScript code and the browser's native Swift code.

## 2. Guiding Principles

*   **Protocol-Oriented:** We will use Swift's protocols to define abstract interfaces for core components. This decouples our browser's logic from the concrete implementation details of any specific manifest version.
*   **Modularity:** Components, especially the complex networking handlers, will be self-contained and swappable. This allows us to plug in an MV3-style network handler now and potentially an MV2-style handler later.
*   **Clear Separation of Concerns:** The logic for managing extensions, running APIs, and handling networking will be clearly separated.

## 3. High-Level Architecture

The following diagram illustrates the flow of control and the primary components of the system.

```
 [ UI (WebView) ] <-----------------------> [ WKNavigationDelegate ]
        |                                              |
        | (JS API Call via WKScriptMessageHandler)     | (Navigation Events)
        v                                              |
+------------------------------------------------------+
|                  ExtensionManager                      |
| (Central Orchestrator, Extension Factory, API Router)|
+------------------------------------------------------+
        | (Delegates to specific extension)
        v
+------------------------------------------------------+
|                    any Extension (Protocol)            |
| (Abstract representation of one loaded extension)    |
+------------------------------------------------------+
        |                                      ^
        | (Concrete Implementations)           |
        |                                      |
+------------------+                  +--------------------+
|   MV3Extension   |                  |  MV2Extension      |
|     (Class)      |                  |  (Class, Future)   |
+------------------+                  +--------------------+
        |                                      |
        v                                      v
+------------------+                  +--------------------+
|  MV3APIRuntime   |                  |  MV2APIRuntime     |
+------------------+                  +--------------------+
        |                                      |
        v (Holds a reference to...)            v (Holds a reference to...)
+------------------------------------------------------+
|                  any NetworkHandler (Protocol)         |
+------------------------------------------------------+
        |                                      ^
        | (Concrete Implementations)           |
        |                                      |
+------------------+                  +--------------------+
| DeclarativeNet...|                  | WebRequestAPI...   |
| (MV3 Handler)    |                  | (MV2 Handler, Future)|
+------------------+                  +--------------------+
```

## 4. Core Components

### 4.1. `ExtensionManager`
A singleton-like class that serves as the central point of control.

*   **Role:** Orchestrator and Factory.
*   **Responsibilities:**
    *   Loads, unloads, installs, and uninstalls extensions.
    *   Parses `manifest.json` to determine the extension type (`MV2` or `MV3`).
    *   Instantiates the correct concrete `Extension` object (`MV3Extension` or `MV2Extension`).
    *   Acts as the single `WKScriptMessageHandler` for all extension API calls, routing incoming messages to the appropriate `Extension` instance.

### 4.2. `Extension` (Protocol)
An abstract interface representing a single loaded extension.

```swift
protocol Extension {
    var id: String { get }
    var manifest: Manifest { get }
    var runtime: APIRuntime { get }

    func start()
    func stop()
    func handleAPICall(from webView: WKWebView, message: WKScriptMessage)
}
```

### 4.3. `APIRuntime` (Protocol)
An abstract interface for the collection of `browser.*` APIs available to an extension.

*   **Role:** Provides the API surface to an extension's JavaScript contexts.
*   **Details:** This will delegate calls to more specific handlers (e.g., `TabsAPI`, `StorageAPI`). Crucially, it holds a reference to the appropriate `NetworkHandler`.

### 4.4. `NetworkHandler` (Protocol)
The critical architectural seam that isolates network interception logic. This allows us to support MV3's declarative model and MV2's blocking model without changing the core browser code.

```swift
protocol NetworkHandler {
    // For MV3: Provides rules to be compiled by WebKit.
    func getContentRuleLists() -> [WKContentRuleList]

    // For MV2 (Future): Intercepts a request to decide its fate.
    func shouldProcessRequest(_ request: URLRequest, completion: @escaping (RequestDecision) -> Void)
}
```

#### Concrete Implementations:
*   **`DeclarativeNetRequestHandler`**: The initial implementation for MV3. It parses `declarativeNetRequest` rules from the manifest and uses `WKContentRuleListStore` to compile them. Its `shouldProcessRequest` method will do nothing and immediately allow the request.
*   **`WebRequestAPIHandler`**: A future implementation for MV2. It would contain the complex logic for the blocking `webRequest` API, likely involving a local proxy or other advanced networking techniques. Its `getContentRuleLists` method would return an empty array.

## 5. User Interface Integration

The user interface for managing and interacting with extensions will be integrated into the existing browser chrome as follows.

### 5.1. Sidebar Icon Display

*   **Component:** `ExtensionToolbarView.swift`
*   **Purpose:** Displays a list of icons for all enabled extensions. For the initial implementation, this will be a static list of placeholder icons.
*   **Location:** This view will be instantiated within `SidebarView.swift`, positioned directly below the `URLBarView`.

### 5.2. Extension Management Panel

*   **Component:** `ExtensionsPanelView.swift`
*   **Purpose:** Provides a detailed view for managing all installed extensions (enabling, disabling, removing, configuring). This is analogous to Chrome's `chrome://extensions` page.
*   **Location:** This view is displayed within the app's right-hand panel, managed by `ContentView.swift`.

### 5.3. State and Activation

*   **State Enum:** The `RightPanelContent` enum in `AppState.swift` is extended with an `extensions` case to represent when the management panel should be visible.
*   **Activation:** A new `Button` is added to the main toolbar in `SidebarView.swift` (using the `puzzlepiece.extension` icon). Tapping this button sets the `appState.rightPanelItem` to `.extensions`, causing the `RightPanelView` to render the `ExtensionsPanelView`.

## 6. Initial Implementation Plan (MV3-First)

1.  **Define Protocols:** Create the Swift files for `Extension`, `APIRuntime`, and `NetworkHandler`.
2.  **Implement Manifest Models:** Create `Codable` structs for `ManifestV3` and any shared manifest structures.
3.  **Build `DeclarativeNetRequestHandler`**: Implement the logic to parse manifest rules and use `WKContentRuleListStore.compileContentRuleList` to provide rules to WebKit.
4.  **Build MV3 Components**: Implement the `MV3APIRuntime` and `MV3Extension` classes.
5.  **Build `ExtensionManager`**: Implement the core logic to load extensions. Initially, it will only instantiate `MV3Extension` objects when `manifest_version == 3`.
6.  **Wire into WebView**:
    *   Configure `WKWebView` to use the `WKContentRuleList` objects provided by the `DeclarativeNetRequestHandler`.
    *   Set up the `WKScriptMessageHandler` on the `WKUserContentController` to route all API calls to the `ExtensionManager`.

## 7. Future MV2 Integration Path

This architecture makes adding MV2 support a modular task, albeit a large one.

1.  **Implement `WebRequestAPIHandler`**: This is the most significant engineering challenge. It involves building the entire blocking request interception system.
2.  **Implement MV2 Components**: Build the `MV2APIRuntime` and `MV2Extension` classes.
3.  **Update `ExtensionManager`**: Extend the factory logic to recognize `manifest_version: 2` and instantiate `MV2Extension` objects.

Because the `WKNavigationDelegate` only interacts with the abstract `NetworkHandler` protocol, it will not need to be changed. It will seamlessly start using the new `WebRequestAPIHandler` for MV2 extensions, while continuing to use the `DeclarativeNetRequestHandler` for MV3 extensions.
