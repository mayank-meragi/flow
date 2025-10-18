function assertTabsAvailable() {
  if (!(window.chrome && chrome.tabs)) {
    alert('chrome.tabs API not available');
    throw new Error('chrome.tabs not available');
  }
}

document.getElementById('create').addEventListener('click', () => {
  try {
    assertTabsAvailable();
    chrome.tabs.create({ url: 'https://example.com', active: true }, (tab) => {
      console.log('Created tab:', tab);
    });
  } catch (e) { console.error(e); }
});

document.getElementById('query').addEventListener('click', () => {
  try {
    assertTabsAvailable();
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      console.log('Query active:', tabs);
      alert('Active tab url: ' + (tabs[0]?.url || 'n/a'));
    });
  } catch (e) { console.error(e); }
});

document.getElementById('update').addEventListener('click', () => {
  try {
    assertTabsAvailable();
    chrome.tabs.update(undefined, { url: 'https://example.org', active: true, pinned: false }, (tab) => {
      console.log('Updated tab:', tab);
    });
  } catch (e) { console.error(e); }
});

document.getElementById('reload').addEventListener('click', () => {
  try {
    assertTabsAvailable();
    chrome.tabs.reload();
  } catch (e) { console.error(e); }
});

document.getElementById('duplicate').addEventListener('click', () => {
  try {
    assertTabsAvailable();
    chrome.tabs.getCurrent((tab) => {
      if (!tab) { alert('No current tab'); return; }
      chrome.tabs.duplicate(tab.id, (newTab) => {
        console.log('Duplicated to:', newTab);
      });
    });
  } catch (e) { console.error(e); }
});

document.getElementById('remove').addEventListener('click', () => {
  try {
    assertTabsAvailable();
    chrome.tabs.getCurrent((tab) => {
      if (!tab) { alert('No current tab'); return; }
      chrome.tabs.remove(tab.id, () => console.log('Removed tab')); 
    });
  } catch (e) { console.error(e); }
});

// ---- Tab Groups ----
document.getElementById('groupActive').addEventListener('click', () => {
  try {
    assertTabsAvailable();
    chrome.tabs.getCurrent((tab) => {
      if (!tab) { alert('No current tab'); return; }
      chrome.tabs.group({ tabIds: [tab.id] }, (groupId) => {
        console.log('Grouped into id:', groupId);
        // Give it a name for demo
        chrome.tabGroups.update(groupId, { title: 'Demo Group' }, (g) => console.log('Group updated:', g));
      });
    });
  } catch (e) { console.error(e); }
});

document.getElementById('ungroupActive').addEventListener('click', () => {
  try {
    assertTabsAvailable();
    chrome.tabs.getCurrent((tab) => {
      if (!tab) { alert('No current tab'); return; }
      chrome.tabs.ungroup(tab.id, () => console.log('Ungrouped'));
    });
  } catch (e) { console.error(e); }
});

document.getElementById('listGroups').addEventListener('click', () => {
  try {
    assertTabsAvailable();
    chrome.tabGroups.query({}, (groups) => {
      console.log('Groups:', groups);
      alert('Groups: ' + groups.map(g => `${g.id}:${g.title}`).join(', '));
    });
  } catch (e) { console.error(e); }
});

document.getElementById('renameGroup').addEventListener('click', () => {
  try {
    assertTabsAvailable();
    chrome.tabs.getCurrent((tab) => {
      if (!tab || tab.groupId === -1) { alert('Tab not in a group'); return; }
      const newName = prompt('New group name:', 'Renamed Group');
      if (!newName) return;
      chrome.tabGroups.update(tab.groupId, { title: newName }, (g) => console.log('Renamed:', g));
    });
  } catch (e) { console.error(e); }
});
