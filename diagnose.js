const puppeteer = require('puppeteer');
(async () => {
  const browser = await puppeteer.launch({
    args: ['--no-sandbox', '--disable-setuid-sandbox'],
    headless: true
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 800 });

  const consoleLogs = [];
  page.on('console', msg => consoleLogs.push(`[${msg.type()}] ${msg.text()}`));
  page.on('pageerror', err => consoleLogs.push(`[ERROR] ${err.message}`));

  await page.goto('https://family-planner-sage.vercel.app/login', {
    waitUntil: 'networkidle0', timeout: 30000
  });
  await new Promise(r => setTimeout(r, 6000));

  // --- DOM inspection BEFORE click ---
  const before = await page.evaluate(() => {
    const info = {};
    const body = document.body;
    const bodyStyle = window.getComputedStyle(body);
    info.bodyMargin = bodyStyle.margin;
    info.bodyOverflow = bodyStyle.overflow;

    const gp = document.querySelector('flt-glass-pane');
    if (!gp) { info.glassPane = 'NOT FOUND'; return info; }

    const gpStyle = window.getComputedStyle(gp);
    info.glassPane = {
      pointerEvents: gpStyle.pointerEvents,
      position: gpStyle.position,
      top: gpStyle.top,
      left: gpStyle.left,
      width: gpStyle.width,
      height: gpStyle.height,
      zIndex: gpStyle.zIndex,
      hasShadowRoot: !!gp.shadowRoot,
    };

    if (gp.shadowRoot) {
      const sr = gp.shadowRoot;
      info.shadowChildren = Array.from(sr.children).map(c => c.tagName);
      const eh = sr.querySelector('flt-text-editing-host');
      info.editingHostFound = !!eh;
      if (eh) {
        info.editingHostStyle = window.getComputedStyle(eh).pointerEvents;
        info.editingHostInputs = eh.querySelectorAll('input,textarea').length;
      }
    }
    return info;
  });
  console.log('\n=== BEFORE CLICK ===');
  console.log(JSON.stringify(before, null, 2));

  // --- Click at email field location ---
  await page.mouse.click(640, 400);
  await new Promise(r => setTimeout(r, 2000));

  // --- DOM inspection AFTER click ---
  const after = await page.evaluate(() => {
    const info = {};
    info.activeElement = document.activeElement?.tagName;
    info.activeElementId = document.activeElement?.id;

    const gp = document.querySelector('flt-glass-pane');
    if (!gp || !gp.shadowRoot) { info.error = 'no shadow root'; return info; }
    const sr = gp.shadowRoot;
    info.shadowActiveElement = sr.activeElement?.tagName;
    const eh = sr.querySelector('flt-text-editing-host');
    if (eh) {
      const inputs = Array.from(eh.querySelectorAll('input,textarea'));
      info.inputsAfterClick = inputs.length;
      info.inputs = inputs.map(i => ({
        type: i.type,
        style: i.getAttribute('style'),
        value: i.value,
        focused: sr.activeElement === i,
      }));
    }
    return info;
  });
  console.log('\n=== AFTER CLICK ===');
  console.log(JSON.stringify(after, null, 2));

  // --- Try to type if an input was created ---
  if (after.inputsAfterClick > 0) {
    console.log('\n--- Input found! Trying to type ---');
    await page.keyboard.type('hello@test.com');
    await new Promise(r => setTimeout(r, 1000));
    const typed = await page.evaluate(() => {
      const gp = document.querySelector('flt-glass-pane');
      if (!gp?.shadowRoot) return 'no shadow root';
      const eh = gp.shadowRoot.querySelector('flt-text-editing-host');
      if (!eh) return 'no editing host';
      const inputs = eh.querySelectorAll('input,textarea');
      return Array.from(inputs).map(i => ({ value: i.value, type: i.type }));
    });
    console.log('Input values after typing:', JSON.stringify(typed));
  } else {
    console.log('\n--- NO INPUT FOUND after click! Text input bridge is broken ---');
    // Try clicking on center of visible field area
    console.log('Trying alternative click positions...');
    for (const [x, y] of [[640, 375], [640, 390], [640, 410], [640, 430]]) {
      await page.mouse.click(x, y);
      await new Promise(r => setTimeout(r, 500));
      const check = await page.evaluate(() => {
        const gp = document.querySelector('flt-glass-pane');
        if (!gp?.shadowRoot) return 0;
        const eh = gp.shadowRoot.querySelector('flt-text-editing-host');
        return eh ? eh.querySelectorAll('input,textarea').length : 0;
      });
      if (check > 0) {
        console.log(`  Found input after clicking at (${x}, ${y})!`);
        break;
      }
    }
  }

  console.log('\n=== CONSOLE ERRORS ===');
  consoleLogs.filter(l => l.includes('ERROR') || l.includes('error') || l.includes('Error')).forEach(l => console.log(l));

  await browser.close();
})().catch(e => { console.error('FATAL:', e.message); process.exit(1); });
