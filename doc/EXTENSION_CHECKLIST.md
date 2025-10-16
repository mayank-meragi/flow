# Extension Implementation Checklist

This document breaks down the work required to implement WebExtensions support, based on our architecture design. The work is grouped into phases: Proof of Concept (POC), Minimum Viable Product (MVP), and Future Work.

## Proof of Concept (POC): Load and Display a Simple Extension (MV2 or MV3)

The goal of this phase is to get a basic, non-interactive extension (either MV2 or MV3) with a popup action to load and be displayed in the UI.

### 1. Core Architecture & Protocols
- [x] Create `Extension.swift` with the `Extension` protocol.
- [x] Create `APIRuntime.swift` with the `APIRuntime` protocol.
- [x] Create `NetworkHandler.swift` with the `NetworkHandler` protocol.
- [x] Create placeholder classes `MV3Extension` and `MV2Extension` that conform to the `Extension` protocol.
- [x] Create placeholder classes `MV3APIRuntime` and `MV2APIRuntime` that conform to the `APIRuntime` protocol.

### 2. Manifest Parsing & Extension Loading
- [x] Create `Manifest.swift` to contain all `Codable` models for `manifest.json`.
- [x] Define `Manifest` structs for keys common to MV2 and MV3.
- [x] Create `ExtensionManager.swift`.
- [x] Implement logic in `ExtensionManager` to find and read extension files from a designated directory.
- [x] Implement JSON parsing of `manifest.json` in `ExtensionManager`.
- [x] Implement factory logic in `ExtensionManager` to instantiate `MV3Extension` or `MV2Extension` based on `manifest_version`.

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
    - [x] Render icons from the `action` or `browser_action` manifest keys.
    - [x] Implement popup handling for `action.default_popup` or `browser_action.default_popup`.

## Minimum Viable Product (MVP): Common API Support

The goal of this phase is to support a core set of APIs that are common to both MV2 and MV3, enabling a wide range of functional extensions.

### 1. UI & Developer Features
- [x] **Enhanced Developer Mode:**
    - [x] In the dashboard, display extension IDs and other metadata for developers.
- [x] **Options Page Support:**
    - [x] Parse `options_page` and `options_ui` from the manifest.
    - [x] Add a button to the dashboard to open the options page.
- [x] **Toolbar Icon Context Menu:**
    - [x] Implement a right-click context menu on extension action icons.
    - [x] Include items like "Options", "Manage extension", and "Remove extension".

### 2. Core Functionality APIs
- [x] **Permissions API:**
    - [x] Parse `permissions` and `host_permissions` keys in the manifest.
    - [x] Create a UI for prompting the user to grant permissions.
    - [x] Implement `permissions.request`, `permissions.contains`, and `permissions.getAll`.
- [x] **Storage API:**
    - [x] Implement `storage.local` and `storage.session`.
    - [x] Implement the `storage.onChanged` event.
- [x] **Alarms API:**
    - [x] Implement `alarms.create`, `alarms.get`, `alarms.getAll`, `alarms.clear`.
    - [x] Use a system timer (`Timer` in Swift) to trigger `alarms.onAlarm` events.
- [x] **Internationalization (i18n) API:**
    - [x] Implement `i18n.getMessage` to support localized strings from the `_locales` folder.

### 3. Browser Interaction APIs
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

### 4. Scripting & Page Interaction
- [ ] **Content Scripts:**
    - [ ] Parse the `content_scripts` array and inject scripts via `WKUserScript`.

## Future Work

This includes full support for version-specific features and expanding the API surface.

### 1. Version-Specific Features
- [ ] **MV3 Support:**
    - [ ] Implement background service worker lifecycle.
    - [ ] Implement the `scripting` API (`executeScript`, `insertCSS`, etc.).
    - [ ] Implement `declarativeNetRequest` by parsing `rule_resources` and compiling them using `WKContentRuleListStore`.
- [ ] **MV2 Support:**
    - [ ] Implement the persistent background page environment.
    - [ ] Design and implement `WebRequestAPIHandler.swift` for the blocking `webRequest` API.

### 2. Expanded API Surface
- [ ] `storage.sync` (requires backend infrastructure)
- [ ] `downloads`
- [ ] `history`
- [ ] `bookmarks`
- [ ] `identity`
- [ ] `proxy`

### 3. Developer Tools
- [ ] Implement `devtools_page` manifest key support.
- [ ] Allow extensions to create custom panels in the browser's developer tools.
