const puppeteer = require('puppeteer');
(async () => {
  const browser = await puppeteer.launch({
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
    headless: true
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 800 });

  await page.goto('https://family-planner-sage.vercel.app/login', {
    waitUntil: 'networkidle0', timeout: 30000
  });
  // Wait for Flutter to fully initialize
  await new Promise(r => setTimeout(r, 7000));

  // Verify glass pane dimensions FIRST
  const before = await page.evaluate(() => {
    const gp = document.querySelector('flt-glass-pane');
    if (!gp) return { error: 'flt-glass-pane not found' };
    const rect = gp.getBoundingClientRect();
    const s = window.getComputedStyle(gp);
    return {
      position: s.position,
      pointerEvents: s.pointerEvents,
      rect: { top: rect.top, left: rect.left, width: rect.width, height: rect.height },
      hasShadowRoot: !!gp.shadowRoot,
      shadowChildren: gp.shadowRoot ? Array.from(gp.shadowRoot.children).map(c => c.tagName) : []
    };
  });
  console.log('Glass pane:', JSON.stringify(before, null, 2));

  // Take screenshot before any click
  await page.screenshot({ path: 'C:/Users/Amine/OneDrive/Projects/family-planner-app/test_before.png' });
  console.log('Screenshot: test_before.png');

  // Click on email field area
  await page.mouse.click(640, 395);
  console.log('Clicked at (640, 395)');

  // Poll for flt-text-editing-host up to 5 seconds
  let found = false;
  for (let i = 0; i < 10; i++) {
    await new Promise(r => setTimeout(r, 500));
    const check = await page.evaluate(() => {
      const gp = document.querySelector('flt-glass-pane');
      if (!gp || !gp.shadowRoot) return null;
      const eh = gp.shadowRoot.querySelector('flt-text-editing-host');
      if (!eh) {
        // Also return current shadow children to track what's happening
        return { found: false, shadowChildren: Array.from(gp.shadowRoot.children).map(c => c.tagName) };
      }
      const inputs = Array.from(eh.querySelectorAll('input,textarea'));
      return { found: true, inputCount: inputs.length, inputs: inputs.map(i => ({ type: i.type, style: i.getAttribute('style') })) };
    });
    if (check && check.found) {
      found = true;
      console.log(`Text editing host appeared after ${(i+1)*500}ms:`, JSON.stringify(check));
      break;
    } else if (check) {
      console.log(`  t=${(i+1)*500}ms: shadowChildren=${JSON.stringify(check.shadowChildren)}`);
    }
  }

  if (!found) {
    console.log('\nText editing host did NOT appear. Trying focus via JavaScript...');
    // Try to find the canvas element and dispatch proper events
    const result = await page.evaluate(() => {
      // Look for the glass pane and try dispatching pointer events
      const gp = document.querySelector('flt-glass-pane');
      const rect = gp ? gp.getBoundingClientRect() : null;
      return {
        gpRect: rect,
        gpPointerEvents: gp ? window.getComputedStyle(gp).pointerEvents : null,
        activeElement: document.activeElement?.tagName
      };
    });
    console.log('State after click:', JSON.stringify(result));
  }

  await page.screenshot({ path: 'C:/Users/Amine/OneDrive/Projects/family-planner-app/test_after_click.png' });
  console.log('Screenshot: test_after_click.png');

  await browser.close();
})().catch(e => { console.error('FATAL:', e.message); process.exit(1); });
