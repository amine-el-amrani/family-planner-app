const puppeteer = require('puppeteer');
(async () => {
  const browser = await puppeteer.launch({
    headless: 'new', // Chrome's new headless — closer to real Chrome
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 800 });

  const errors = [];
  const logs = [];
  page.on('console', msg => logs.push(`[${msg.type()}] ${msg.text()}`));
  page.on('pageerror', err => errors.push(err.message));

  // Capture all network failures
  const failed = [];
  page.on('requestfailed', req => failed.push(req.url() + ': ' + req.failure()?.errorText));

  await page.goto('https://family-planner-sage.vercel.app/login', {
    waitUntil: 'networkidle0', timeout: 30000
  });
  await new Promise(r => setTimeout(r, 8000));

  // Deep structure check
  const structure = await page.evaluate(() => {
    const info = {};

    // Check flutter-view
    const fv = document.querySelector('flutter-view');
    if (fv) {
      const r = fv.getBoundingClientRect();
      const s = window.getComputedStyle(fv);
      info.flutterView = { pos: s.position, w: r.width, h: r.height, pointerEvents: s.pointerEvents };
    }

    // Check flt-glass-pane
    const gp = document.querySelector('flt-glass-pane');
    if (gp) {
      const r = gp.getBoundingClientRect();
      const s = window.getComputedStyle(gp);
      info.glassPane = {
        pos: s.position, pointerEvents: s.pointerEvents,
        w: r.width, h: r.height, top: r.top, left: r.left,
        zIndex: s.zIndex, hasShadow: !!gp.shadowRoot
      };

      if (gp.shadowRoot) {
        const sr = gp.shadowRoot;
        info.shadowRootChildren = Array.from(sr.children).map(c => {
          const cr = c.getBoundingClientRect();
          const cs = window.getComputedStyle(c);
          return { tag: c.tagName, w: cr.width, h: cr.height, pos: cs.position, pointerEvents: cs.pointerEvents };
        });

        // Check for canvas inside scene host
        const sceneHost = sr.querySelector('flt-scene-host');
        if (sceneHost) {
          const canvas = sceneHost.querySelector('canvas, flt-canvas-container, [id*="canvas"]');
          if (canvas) {
            const cr = canvas.getBoundingClientRect();
            info.canvas = { tag: canvas.tagName, w: cr.width, h: cr.height };
          }
          // Also check shadow root of scene host
          if (sceneHost.shadowRoot) {
            const innerCanvas = sceneHost.shadowRoot.querySelector('canvas');
            if (innerCanvas) {
              const cr = innerCanvas.getBoundingClientRect();
              info.innerCanvas = { w: cr.width, h: cr.height };
            }
          }
          info.sceneHostChildren = Array.from(sceneHost.children).map(c => ({ tag: c.tagName, id: c.id, className: c.className }));
        }
      }
    }

    // Check what's at the center of the email field
    const el = document.elementFromPoint(640, 395);
    if (el) {
      const r = el.getBoundingClientRect();
      const s = window.getComputedStyle(el);
      info.elementAtEmailField = {
        tag: el.tagName, id: el.id, class: el.className,
        pointerEvents: s.pointerEvents, zIndex: s.zIndex,
        w: r.width, h: r.height
      };
    }

    // Check window.flutter
    info.hasFlutterObj = typeof window.flutter !== 'undefined';
    info.hasFlutterEngine = typeof window._flutter !== 'undefined';

    return info;
  });

  console.log('=== STRUCTURE ===');
  console.log(JSON.stringify(structure, null, 2));

  if (errors.length) {
    console.log('\n=== PAGE ERRORS ===');
    errors.forEach(e => console.log(e));
  }

  const errorLogs = logs.filter(l => l.includes('error') || l.includes('Error') || l.includes('ERROR'));
  if (errorLogs.length) {
    console.log('\n=== ERROR LOGS ===');
    errorLogs.forEach(l => console.log(l));
  }

  if (failed.length) {
    console.log('\n=== FAILED REQUESTS ===');
    failed.forEach(f => console.log(f));
  }

  // Try clicking the email field and wait longer
  console.log('\n--- Clicking email field ---');
  await page.mouse.click(640, 395);
  await new Promise(r => setTimeout(r, 500));
  // Dispatch a second click with pointerdown/up
  await page.mouse.move(640, 395);
  await page.mouse.down();
  await new Promise(r => setTimeout(r, 100));
  await page.mouse.up();
  await new Promise(r => setTimeout(r, 4000));

  const afterClick = await page.evaluate(() => {
    const gp = document.querySelector('flt-glass-pane');
    if (!gp?.shadowRoot) return { error: 'no shadow root' };
    const sr = gp.shadowRoot;
    const eh = sr.querySelector('flt-text-editing-host');
    const children = Array.from(sr.children).map(c => c.tagName);
    const activeEl = document.activeElement?.tagName + '#' + document.activeElement?.id;
    const shadowActiveEl = sr.activeElement?.tagName;
    return {
      shadowChildren: children,
      editingHostFound: !!eh,
      activeElement: activeEl,
      shadowActiveElement: shadowActiveEl,
      editingHostInputs: eh ? Array.from(eh.querySelectorAll('input,textarea')).length : 0
    };
  });
  console.log('After click:', JSON.stringify(afterClick, null, 2));

  await page.screenshot({ path: 'C:/Users/Amine/OneDrive/Projects/family-planner-app/deep_after_click.png' });
  console.log('Screenshot: deep_after_click.png');

  await browser.close();
})().catch(e => { console.error('FATAL:', e.message); process.exit(1); });
