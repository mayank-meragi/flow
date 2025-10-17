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
