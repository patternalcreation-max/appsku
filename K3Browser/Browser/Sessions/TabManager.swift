import Foundation
import SwiftUI

// PEAK 2 Slice B — Tab manager (URL-switch model).
// Each tab stores URL + title metadata. Switching saves current state
// and loads the target URL into the existing WKWebView.
// SessionRestorer persists the set across launches.

struct TabItem: Identifiable, Equatable {
    let id: UUID
    var url: String
    var title: String

    init(url: String, title: String = "") {
        self.id = UUID()
        self.url = url
        self.title = title
    }
}

extension BrowserState {
    var savedTabs: [TabItem] {
        get { _tabs }
    }

    var activeTabIndex: Int {
        get { _activeTabIndex }
    }

    func openNewTab(url: String = "https://duckduckgo.com") {
        _tabs.append(TabItem(url: url, title: url))
        _activeTabIndex = _tabs.count - 1
        address = url
        persistSession()
        loadAddress()
    }

    func switchTab(to index: Int) {
        guard index >= 0, index < _tabs.count else { return }
        saveCurrentTabMetadata()
        _activeTabIndex = index
        let tab = _tabs[index]
        address = tab.url
        loadAddress()
    }

    func closeTab(at index: Int) {
        guard _tabs.indices.contains(index) else { return }
        let wasActive = index == _activeTabIndex
        _tabs.remove(at: index)

        if _tabs.isEmpty {
            // Always keep at least one tab
            _tabs.append(TabItem(url: "https://duckduckgo.com", title: ""))
            _activeTabIndex = 0
            address = "https://duckduckgo.com"
        } else if wasActive {
            _activeTabIndex = min(index, _tabs.count - 1)
            address = _tabs[_activeTabIndex].url
        } else if index < _activeTabIndex {
            _activeTabIndex -= 1
        }

        if wasActive {
            loadAddress()
        }
        persistSession()
    }

    func saveCurrentTabMetadata() {
        guard _tabs.indices.contains(_activeTabIndex) else { return }
        _tabs[_activeTabIndex].url = currentURL.isEmpty ? address : currentURL
        _tabs[_activeTabIndex].title = pageTitle
        persistSession()
    }

    func restoreSession() {
        guard let snapshot = SessionRestorer.load(), !snapshot.tabs.isEmpty else {
            if _tabs.isEmpty {
                _tabs.append(TabItem(url: address, title: pageTitle))
                _activeTabIndex = 0
            }
            return
        }
        _tabs = snapshot.tabs.map { TabItem(url: $0.url, title: $0.title) }
        _activeTabIndex = min(snapshot.activeIndex, _tabs.count - 1)
        let active = _tabs[_activeTabIndex]
        address = active.url
        loadAddress()
    }

    private func persistSession() {
        let saved = _tabs.map { SavedTab(url: $0.url, title: $0.title) }
        SessionRestorer.save(tabs: saved, activeIndex: _activeTabIndex)
    }
}
