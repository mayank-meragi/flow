# Dark Reader (MV3) – Enablement Checklist

This checklist tracks what’s needed to get the Dark Reader extension working end‑to‑end in Flow.

## P0 Blockers
- [ ] MV3 background worker host
  - [x] Load and run `background/index.js` in a service‑worker‑like context.
  - [x] Provide `chrome.runtime` messaging: `sendMessage`, `onMessage`, `connect`, `onConnect`.
  - [x] Expose `chrome.storage`, `chrome.alarms`, `chrome.commands`, `chrome.contextMenus`, `chrome.scripting` to background.
- [ ] Content scripts
  - [ ] Parse `content_scripts[]` and inject according to manifest:
    - [x] `inject/proxy.js` at `document_start`, `all_frames: true`, `match_about_blank: true`, world MAIN.
    - [x] `inject/fallback.js` + `inject/index.js` at `document_start`, `all_frames: true`, world ISOLATED.
    - [x] `inject/color-scheme-watcher.js` at `document_idle`, main frame only.
  - [x] Enforce `matches`, `run_at`, `all_frames`, `match_about_blank`, and JS world (MAIN/ISOLATED).
- [x] Scripting API
  - [x] Implement `chrome.scripting.executeScript` for tab/frame targeted execution (used by background).
- [ ] Runtime/tabs messaging bus
  - [x] Implement cross‑context messaging: background ↔ popup/options ↔ content.
  - [x] `chrome.runtime.sendMessage/connect`, `chrome.runtime.onMessage/onConnect`.
  - [x] `chrome.tabs.sendMessage` to content scripts.
- [ ] Tabs events
  - [x] Fire `tabs.onCreated`, `tabs.onUpdated`, `tabs.onRemoved` from BrowserStore changes.

## P0 Popup Rendering Issue
- [ ] Popup does not render (only background shows)
  - [ ] Extend `ExtensionJSBridge` for popup/options to expose:
    - [x] `chrome.runtime.getURL`, `chrome.runtime.sendMessage/connect`
    - [x] `chrome.i18n.getMessage`
    - [x] `chrome.storage.local/session` (get/set/remove/clear)
    - [x] `chrome.tabs.sendMessage`
    - [x] Minimal `chrome.windows.getAll/update/create` used by popup
    - [x] `chrome.fontSettings.getFontList` (stub is acceptable initially)
  - [ ] Ensure missing API calls fail gracefully (no popup crash).
  - [ ] Verify popup initializes UI and i18n text successfully.

## P1 Required For Feature Parity
- [x] Windows API
  - [x] Implement `windows.getAll`, `windows.update`, `windows.create` used by popup/options.
- [ ] Context Menus API
  - [x] Implement `contextMenus.create/remove/removeAll` and `contextMenus.onClicked`.
  - [x] Integrate created items into the web view’s context menu.
- [ ] Commands API
  - [x] Parse `commands` from manifest and register accelerators.
  - [x] Fire `commands.onCommand` to background.
- [ ] Font Settings API
  - [x] Implement `chrome.fontSettings.getFontList` mapping to system fonts.

## P1 Storage Sync (Graceful Degradation)
- [ ] Provide a `chrome.storage.sync` shim
  - [ ] Minimal: local fallback mirror for `get/set/remove` to avoid errors.
  - [ ] Avoid noisy `lastError` unless behavior is functionally blocked.

## P1 Tabs API Completeness
- [x] `tabs.create`, `tabs.query`, `tabs.update`, `tabs.remove` (host implemented)
- [x] `tabs.get`, `tabs.getCurrent`, `tabs.duplicate`, `tabs.reload`
- [x] Improve `tabs.query` URL filtering to support wildcard patterns.

## P1 Host Permissions
- [x] Parse and grant `permissions` and `host_permissions` from manifest.
- [x] Enforce URL matching for content script injection against host permissions.

## P2 Polish and Stability
- [ ] Broadcast events (e.g., `storage.onChanged`, `alarms.onAlarm`) to all active extension contexts.
- [ ] CSP nuances for extension pages (ensure resources load as per manifest CSP).
- [ ] Add structured logging and surfaced errors in the JS bridge for easier debugging.

## Validation Checklist
- [ ] Load Dark Reader unpacked and confirm:
  - [ ] Popup opens and renders with i18n text and controls.
  - [ ] Options page opens from toolbar context menu and functions.
  - [ ] Content scripts apply page styling on typical sites.
  - [ ] Background can message content scripts and execute scripts via `scripting`.
  - [ ] Windows actions from popup work (open/manage pages).
  - [ ] Context menu items appear and clicks reach background.
  - [ ] Keyboard shortcuts trigger `commands.onCommand`.
  - [ ] No uncaught errors in popup/background consoles during typical usage.
