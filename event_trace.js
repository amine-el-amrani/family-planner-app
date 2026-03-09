const puppeteer = require('puppeteer');
(async () => {
  const browser = await puppeteer.launch({
    headless: 'new',
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 800 });

  // Inject tracing script BEFORE page loads
  await page.evaluateOnNewDocument(() => {
    window.__eventTrace = [];

    // Override addEventListener to track registrations on flt-glass-pane
    const origAddEL = EventTarget.prototype.addEventListener;
    EventTarget.prototype.addEventListener = function(type, handler, opts) {
      if (this?.tagName === 'FLT-GLASS-PANE' ||
          (this?.host && this?.host?.tagName === 'FLT-GLASS-PANE')) {
        window.__eventTrace.push({ action: 'addListener', type, target: this?.tagName || 'ShadowRoot' });
      }
      return origAddEL.call(this, type, handler, opts);
    };

    // Track MutationObserver for glass pane creation
    const bodyObserver = new MutationObserver((mutations) => {
      for (const mut of mutations) {
        for (const node of mut.addedNodes) {
          if (node.tagName === 'FLUTTER-VIEW') {
            window.__eventTrace.push({ action: 'flutter-view-created' });
            // Watch for flt-glass-pane inside flutter-view
            const gpObserver = new MutationObserver((m2) => {
              for (const m of m2) {
                for (const n of m.addedNodes) {
                  if (n.tagName === 'FLT-GLASS-PANE') {
                    window.__eventTrace.push({ action: 'glass-pane-created' });
                  }
                }
              }
            });
            gpObserver.observe(node, { childList: true, subtree: true });
          }
        }
      }
    });
    bodyObserver.observe(document, { childList: true, subtree: true });
  });

  const logs = [];
  page.on('console', msg => logs.push(`[${msg.type()}] ${msg.text()}`));
  page.on('pageerror', err => logs.push(`[PAGEERROR] ${err.message}`));

  await page.goto('https://family-planner-sage.vercel.app/login', {
    waitUntil: 'networkidle0', timeout: 30000
  });
  await new Promise(r => setTimeout(r, 8000));

  const trace1 = await page.evaluate(() => window.__eventTrace);
  console.log('=== EVENT LISTENER TRACE ===');
  console.log(JSON.stringify(trace1, null, 2));

  // Check event listeners via CDP
  const client = await page.createCDPSession();

  const gpNode = await page.evaluateHandle(() => document.querySelector('flt-glass-pane'));
  if (gpNode) {
    try {
      const gpObj = await gpNode.getProperty('constructor'); // get object id
      const remoteObj = gpNode.remoteObject();
      if (remoteObj.objectId) {
        const listenersResult = await client.send('DOMDebugger.getEventListeners', {
          objectId: remoteObj.objectId,
          depth: 0,
          pierce: false
        });
        console.log('\n=== EVENT LISTENERS ON flt-glass-pane ===');
        console.log('Count:', listenersResult.listeners.length);
        listenersResult.listeners.forEach(l => {
          console.log(`  ${l.type} (useCapture: ${l.useCapture}, passive: ${l.passive})`);
        });
      }
    } catch(e) {
      console.log('CDP error:', e.message);
    }
  }

  // Now click and check if any events fire
  await page.evaluateOnNewDocument(() => {}); // no-op
  const pointerReceived = await page.evaluate(() => {
    return new Promise((resolve) => {
      const gp = document.querySelector('flt-glass-pane');
      if (!gp) { resolve({ error: 'no glass pane' }); return; }

      const received = [];
      const types = ['pointerdown', 'pointerup', 'click', 'mousedown', 'mouseup', 'touchstart'];

      types.forEach(type => {
        gp.addEventListener(type, (e) => {
          received.push({ type, x: e.clientX, y: e.clientY, isTrusted: e.isTrusted, bubbles: e.bubbles });
        });
      });

      setTimeout(() => resolve(received), 3000);
    });
  });

  // Trigger click while promise is running
  await new Promise(r => setTimeout(r, 100));
  await page.mouse.click(640, 395);
  await new Promise(r => setTimeout(r, 500));
  await page.mouse.click(640, 395);

  const events = await pointerReceived;
  console.log('\n=== POINTER EVENTS RECEIVED ON flt-glass-pane ===');
  console.log(JSON.stringify(events, null, 2));

  // Console errors
  const errs = logs.filter(l => l.includes('error') || l.includes('Error'));
  if (errs.length) {
    console.log('\n=== ERRORS ===');
    errs.forEach(e => console.log(e));
  }

  console.log('\n=== ALL CONSOLE LOGS ===');
  logs.slice(0, 20).forEach(l => console.log(l));

  await browser.close();
})().catch(e => { console.error('FATAL:', e.message); process.exit(1); });
