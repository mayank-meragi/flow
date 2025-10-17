document.getElementById('open').addEventListener('click', () => {
  try {
    if (window.chrome && chrome.tabs && chrome.tabs.create) {
      chrome.tabs.create({ url: 'https://example.com', active: true }, (tab) => {
        console.log('Created tab:', tab);
      });
    } else {
      console.error('chrome.tabs API not available');
      alert('chrome.tabs API not available in this context');
    }
  } catch (e) {
    console.error('Error calling chrome.tabs.create', e);
  }
});

