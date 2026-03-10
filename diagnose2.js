const puppeteer = require('puppeteer');
(async () => {
  const browser = await puppeteer.launch({
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 800 });

  const errors = [];
  page.on('pageerror', err => errors.push(err.message));
  page.on('console', msg => {
    if (msg.type() === 'error') errors.push(msg.text());
  });

  await page.goto('https://family-planner-sage.vercel.app/login', {
    waitUntil: 'networkidle0', timeout: 30000
  });
  await new Promise(r => setTimeout(r, 6000));

  const info = await page.evaluate(() => {
    const out = {};

    // Check flutter-view
    const fv = document.querySelector('flutter-view');
    if (fv) {
      const s = window.getComputedStyle(fv);
      out.flutterView = { position: s.position, width: s.width, height: s.height, top: s.top, left: s.left };
    }

    // Check flt-glass-pane
    const gp = document.querySelector('flt-glass-pane');
    if (gp) {
      const s = window.getComputedStyle(gp);
      const rect = gp.getBoundingClientRect();
      out.glassPaneStyle = { position: s.position, width: s.width, height: s.height, pointerEvents: s.pointerEvents };
      out.glassPaneRect = { top: rect.top, left: rect.left, width: rect.width, height: rect.height };

      // Walk ALL shadow roots in document
      function searchShadowRoots(root) {
        const results = [];
        const walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT);
        let node;
        while ((node = walker.nextNode())) {
          if (node.shadowRoot) {
            results.push({
              tag: node.tagName,
              shadowChildren: Array.from(node.shadowRoot.children).map(c => c.tagName),
            });
            // recurse
            const inner = searchShadowRoots(node.shadowRoot);
            results.push(...inner);
          }
        }
        return results;
      }
      out.allShadowRoots = searchShadowRoots(document);

      // Check ALL inputs in main document
      out.mainDocInputs = document.querySelectorAll('input,textarea').length;
    }

    return out;
  });

  console.log('=== DOM STRUCTURE ===');
  console.log(JSON.stringify(info, null, 2));

  // Click on the email field
  await page.mouse.click(640, 395);
  await new Promise(r => setTimeout(r, 2500));

  const afterClick = await page.evaluate(() => {
    const out = {};
    out.activeElement = document.activeElement?.tagName + ' id=' + (document.activeElement?.id || '');

    // Search ALL shadow roots for inputs
    function findInputsInShadow(root, depth = 0) {
      const results = [];
      const walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT);
      let node;
      while ((node = walker.nextNode())) {
        if (node.tagName === 'INPUT' || node.tagName === 'TEXTAREA') {
          const s = window.getComputedStyle(node);
          const rect = node.getBoundingClientRect();
          results.push({
            tag: node.tagName, type: node.type, value: node.value,
            display: s.display, opacity: s.opacity, pointerEvents: s.pointerEvents,
            rect: { top: rect.top, left: rect.left, width: rect.width, height: rect.height }
          });
        }
        if (node.shadowRoot) {
          results.push(...findInputsInShadow(node.shadowRoot, depth + 1));
        }
      }
      return results;
    }

    out.allInputs = findInputsInShadow(document);
    return out;
  });

  console.log('\n=== AFTER CLICK ===');
  console.log(JSON.stringify(afterClick, null, 2));

  if (errors.length) {
    console.log('\n=== JS ERRORS ===');
    errors.forEach(e => console.log(e));
  }

  await browser.close();
})().catch(e => { console.error('FATAL:', e.message); process.exit(1); });
