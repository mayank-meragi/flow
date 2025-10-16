# Extension Implementation Checklist

This document breaks down the work required to implement WebExtensions support, based on our architecture design. The work is grouped into phases: Proof of Concept (POC), Minimum Viable Product (MVP), and Future Work.

## Proof of Concept (POC): Load and Display a Simple MV3 Extension

The goal of this phase is to get a basic, non-interactive MV3 extension with a popup action to load and be displayed in the UI.

### 1. Core Architecture & Protocols
- [x] Create `Extension.swift` with the `Extension` protocol.
- [x] Create `APIRuntime.swift` with the `APIRuntime` protocol.
- [x] Create `NetworkHandler.swift` with the `NetworkHandler` protocol.
- [x] Create placeholder classes `MV3Extension` and `MV2Extension` that conform to the `Extension` protocol.
- [x] Create placeholder classes `MV3APIRuntime` and `MV2APIRuntime` that conform to the `APIRuntime` protocol.

### 2. Manifest Parsing & Extension Loading
- [x] Create `Manifest.swift` to contain all `Codable` models for `manifest.json`.
- [x] Define a `ManifestV3` struct in `Manifest.swift` for keys: `name`, `version`, `manifest_version`, `action`, `description`, `icons`.
- [x] Create `ExtensionManager.swift`.
- [x] Implement logic in `ExtensionManager` to find and read extension files from a designated directory.
- [x] Implement JSON parsing of `manifest.json` in `ExtensionManager`.
- [x] Implement factory logic in `ExtensionManager` to instantiate an `MV3Extension` when `manifest_version` is `3`.

### 3. Extension Management & UI
- [x] **Extension Dashboard (Right Panel):**
    - [x] Create `ExtensionsPanelView.swift` to act as the main dashboard.
    - [x] Integrate `ExtensionsPanelView` into the `RightPanelView` controlled by `AppState`.
    - [x] Add a "Developer mode" toggle.
    - [x] Implement a "Load unpacked" button for loading extensions from a local folder (requires Developer mode).
    - [x] List installed extensions with their name, icon, and version.
    - [x] Add an enable/disable toggle for each extension.
    - [x] Add a button to remove (uninstall) an extension.
- [x] **Action Popup:**
    - [x] Create `ExtensionToolbarView.swift` to display icons for enabled extensions.
    - [x] Render icons from the `action.default_icon` manifest key.
    - [x] Implement `action.onClicked` handling to open the `action.default_popup` HTML file in a popover.

## Minimum Viable Product (MVP): A Fully Functional Extension

The goal of this phase is to support a truly functional extension that can interact with the browser, manage its state, and respond to user actions.

### 1. Advanced UI & Developer Features
- [ ] **Enhanced Developer Mode:**
    - [ ] In the dashboard, display extension IDs and other metadata for developers.
- [ ] **Options Page Support:**
    - [ ] Parse `options_page` and `options_ui` from the manifest.
    - [ ] Add a button to the dashboard to open the options page.
- [ ] **Toolbar Icon Context Menu:**
    - [ ] Implement a right-click context menu on extension action icons.
    - [ ] Include items like "Options", "Manage extension", and "Remove extension".

### 2. Background Logic & Service Workers (MV3)
- [ ] Implement a mechanism to run the extension's service worker script in a background `WKWebView` or `JSContext`.
- [ ] Manage the service worker's lifecycle (startup on event, shutdown when idle).
- [ ] Wire up events (`runtime.onInstalled`, `alarms.onAlarm`, etc.) to wake the service worker.

### 3. Core APIs & Permissions
- [ ] **Permissions API:**
    - [ ] Parse `permissions` and `host_permissions` keys in the manifest.
    - [ ] Create a UI for prompting the user to grant permissions.
    - [ ] Implement `permissions.request`, `permissions.contains`, and `permissions.getAll`.
- [ ] **Storage API:**
    - [ ] Implement `storage.local` and `storage.session`.
    - [ ] Implement the `storage.onChanged` event.
- [ ] **Alarms API:**
    - [ ] Implement `alarms.create`, `alarms.get`, `alarms.getAll`, `alarms.clear`.
    - [ ] Use a system timer (`Timer` in Swift) to trigger `alarms.onAlarm` events.
- [ ] **Internationalization (i18n) API:**
    - [ ] Implement `i18n.getMessage` to support localized strings from the `_locales` folder.

### 4. Browser Interaction APIs
- [ ] **Tabs API:**
    - [ ] Implement `tabs.query`, `tabs.create`, `tabs.update`, and `tabs.remove`.
    - [ ] Implement `tabs.onCreated`, `tabs.onUpdated`, and `tabs.onRemoved` events.
- [ ] **Windows API:**
    - [ ] Implement `windows.get`, `windows.getCurrent`, `windows.getAll`.
    - [ ] Implement basic `windows.create` and `windows.remove`.
- [ ] **Context Menus API (`contextMenus`):**
    - [ ] Implement `contextMenus.create`, `contextMenus.update`, `contextMenus.remove`.
    - [ ] Add created menu items to the web view's right-click context menu.
- [ ] **Commands API (`commands`):**
    - [ ] Parse the `commands` key from the manifest and listen for shortcuts.
    - [ ] Trigger `commands.onCommand` event.
- [ ] **Omnibox API (`omnibox`):**
    - [ ] Parse the `omnibox` key from the manifest to register a keyword.
    - [ ] Fire `omnibox.onInputStarted`, `onInputChanged`, and `onInputEntered` events.
- [ ] **Notifications API (`notifications`):**
    - [ ] Implement `notifications.create` to display system notifications.
    - [ ] Handle notification events like `onClicked` and `onClosed`.

### 5. Scripting & Page Interaction
- [ ] **Content Scripts:**
    - [ ] Parse the `content_scripts` array and inject scripts via `WKUserScript`.
- [ ] **Scripting API (MV3+):**
    - [ ] Implement `scripting.executeScript`, `scripting.insertCSS`, and `scripting.removeCSS`.

### 6. Networking
- [ ] **declarativeNetRequest:**
    - [ ] Parse `rule_resources` and compile them using `WKContentRuleListStore`.

## Future Work

This includes full MV2 compatibility and expanding the API surface to cover more specialized extension functionalities.

- [ ] **MV2 Support:**
    - [ ] Design and implement `WebRequestAPIHandler.swift` for the blocking `webRequest` API.
    - [ ] Implement the persistent MV2 background page environment.
- [ ] **Developer Tools Integration:**
    - [ ] Implement `devtools_page` manifest key support.
    - [ ] Allow extensions to create custom panels in the browser's developer tools.
- [ ] **Expanded API Surface:**
    - [ ] `storage.sync` (requires backend infrastructure)
    - [ ] `downloads`
    - [ ] `history`
    - [ ] `bookmarks`
    - [ ] `identity`
    - [ ] `proxy`