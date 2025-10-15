# Flow Browser — Architecture & Design Decisions

## Overview
- Goal: Build a macOS browser UI in SwiftUI powered by WebKit, with a sidebar‑first layout (tabs + controls) and a main web content area. Support fixed and floating sidebars, a command bar, and custom window controls.
- Status: Functional prototype with tabs, per‑tab webviews, sidebar controls, command bar, and custom traffic lights. Delegates/configuration hardening and persistence are planned next.

## Goals and Non‑Goals
- Goals
  - Modern SwiftUI app that hosts the full WebKit engine via `WKWebView`.
  - Sidebar owns tabs, navigation controls, and address bar.
  - Main view renders the active tab’s `WKWebView` and fills available space.
  - Support fixed vs floating sidebar modes (hover to reveal in floating mode).
  - Custom window controls (traffic lights) inside the sidebar; native ones hidden.
  - Command bar (⌘T) centered over content for quick actions/navigation.
- Non‑Goals (for now)
  - Replacing WebKit’s engine or using private SPI.
  - Full Safari‑compatible extension ecosystem.
  - Cross‑platform support outside macOS.

## UX Summary
- Sidebar (left)
  - Top left: custom traffic lights + sidebar toggle (fixed/floating).
  - Top right: Back, Forward, Reload.
  - Address bar: type URL, press Return to load.
  - Tabs list: shows all tabs with selection highlight and close button; New Tab.
- Main view (right)
  - Renders the active tab’s `WKWebView` and occupies all remaining space.
  - In floating sidebar mode, the main view remains full‑width; sidebar overlays.

## High‑Level Architecture
- App root: `flowApp` (SwiftUI `App`)
  - Window style: hidden title bar; commands injected.
  - Environment objects: `AppState` (command bar visibility).
- State & Models
  - `AppState`: app‑level UI state (`showCommandBar`).
  - `BrowserStore`: observable store managing tabs and selection via stable IDs.
    - `tabs: [BrowserTab]`
    - `activeTabID: UUID?` → computed `active: BrowserTab?`
    - Actions: `newTab()`, `select(tabID:)`, `close(tabID:)`, `goBack/Forward/reload`.
  - `BrowserTab` (NSObject + ObservableObject): owns a dedicated `WKWebView`, `id`, `urlString`, `title`.
    - Observes `title` via KVO (migrating to token‑based KVO / Combine planned).
- Views
  - `ContentView`: orchestrates layout; selects fixed HSplit vs floating overlay.
  - `SidebarView`: controls + address bar + tabs; toggles mode; environment `BrowserStore`.
  - `WebViewContainer`: `NSViewRepresentable` that embeds an existing `WKWebView`.
  - `CommandBarView`: centered overlay palette with text input (opens on ⌘T).
  - `CustomTrafficButton`: custom close/minimize/zoom buttons (AppKit actions).
- Composition
  - Fixed mode: `HSplitView(SidebarView, WebView)`
  - Floating mode: `ZStack{ WebView, SidebarView.overlay }` with a 4px hot zone to reveal.

## Data Flow & Identity
- Source of truth
  - Tab identity uses `UUID` (`BrowserTab.id`). The selected tab is `BrowserStore.activeTabID`.
  - Views derive selection and render state by resolving `store.active` from the ID.
- WebView swapping
  - Each tab owns its `WKWebView`. `ContentView` renders the active webview and applies `.id(active.id)` to force SwiftUI to swap platform views when selection changes.
  - Future: Change `WebViewContainer` to host a stable container `NSView` and swap the child `WKWebView` in `updateNSView` to avoid recreation.

## Web Engine Configuration (Planned)
- Introduce `WebEngine` builder for reproducible configuration:
  - Shared `WKProcessPool` per profile.
  - `WKWebsiteDataStore` selection (default vs non‑persistent for incognito).
  - `WKUserContentController` for scripts and content rules.
  - Optional `WKURLSchemeHandler` for custom schemes.
- Representable with Coordinator
  - Move to a `WebView` wrapper with `Coordinator` implementing `WKNavigationDelegate` and `WKUIDelegate`.
  - Surface callbacks (title, loading, errors) to `BrowserTab`/`BrowserStore`.

## Navigation & Delegates (Planned)
- `WKNavigationDelegate`
  - Policy decisions, redirects, start/commit/finish events, error handling.
  - Update tab title, loading state, and back/forward availability.
- `WKUIDelegate`
  - New window creation (open in tab), JS dialogs, context menu, file inputs.
- Downloads
  - Adopt `WKDownload` APIs for file downloads with progress UI and destination selection.

## Commands & Shortcuts
- Global Commands: `AppCommands` adds ⌘T to open the command bar.
- Command Bar: future actions include open URL, new/close/switch tab, search history.
- Additional shortcuts planned: ⌘L (focus URL), ⌘W (close), ⌘R (reload), ⌘⇧\[ / \] (tab nav).

## Persistence (Planned)
- Session Restore
  - Persist `tabs` (IDs, URLs, selection) in `Application Support`.
  - Recreate tabs at launch; lazy load content.
- Per‑site data
  - Optionally persist cookies/cache via chosen `WKWebsiteDataStore`.
  - Implement “Clear Data” controls per site or all.

## Privacy & Security
- Sandboxing: use only required entitlements (network, file access for downloads).
- Script injection: scope to user world; never expose privileged native APIs to page JS.
- Content rules: use `WKContentRuleList` for tracker/ad blocking when enabled.
- Incognito: non‑persistent data store; block local storage where feasible.

## Performance Considerations
- Process Pools: share pool within a profile; isolate with separate pools when needed.
- Memory: reclaim background tab resources; optionally suspend heavy tabs.
- Rendering: avoid unnecessary `WKWebView` recreation; prefer stable hosting container.
- UI: throttle expensive SwiftUI updates; compute derived state lazily.

## Error Handling & Reporting
- User‑visible: friendly error pages on navigation failure; retry affordances.
- Diagnostics: log navigation timing, crashes, and JS console messages.
- Recovery: auto‑restore tabs after crash; protect against infinite reload loops.

## Testing Strategy
- Unit tests: `BrowserStore` actions, URL normalization, session persistence.
- Integration tests: navigation delegate behaviors, content rules application.
- UI tests: sidebar interactions, fixed vs floating modes, command bar visibility.

## Build & Distribution
- macOS target using public WebKit APIs (`WKWebView`).
- Hidden title bar; custom traffic lights — acceptable for distribution.
- App Store: avoid private APIs/SPIs; bundle only app resources (no custom WebKit frameworks).

## Key Design Decisions
- Public APIs only: relies on `WKWebView` rather than building/embedding a custom WebKit.
- Sidebar‑first: tabs and navigation live in the left rail; clean separation of concerns.
- Stable IDs: selection and routing driven by `UUID`, not object identity.
- Per‑tab webviews: each tab owns its engine instance for isolation and simplicity.
- Progressive hardening: start simple, migrate to delegate‑first model for robustness.

## Roadmap
1) Engine config + Coordinator wrapper (`WKNavigationDelegate`, `WKUIDelegate`).
2) Session persistence (tabs/selection), incognito profiles.
3) Downloads UI and permission prompts.
4) Content blocking (rule compilation + toggles).
5) Improved command bar (open URL, actions, fuzzy tab switcher).
6) Performance polish (webview container swap, memory heuristics).
7) Telemetry & crash recovery.

## Known Limitations
- No deep HTTP/HTTPS interception via public API; use content rules or external proxy.
- Web Inspector embedding not exposed as a public API for shipping apps.
- Current prototype uses KVO for title; will migrate to token‑based observation.

