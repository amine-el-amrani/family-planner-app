const puppeteer = require('puppeteer');
(async () => {
  const browser = await puppeteer.launch({ headless: 'new', args: ['--no-sandbox'] });
  const page = await browser.newPage();
  await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2, isMobile: true, hasTouch: true });

  const logs = [];
  page.on('console', msg => logs.push('[' + msg.type() + '] ' + msg.text()));
  page.on('pageerror', err => logs.push('[PAGEERROR] ' + err.message));

  await page.goto('https://family-planner-sage.vercel.app/login', {
    waitUntil: 'networkidle0', timeout: 30000
  });
  await new Promise(r => setTimeout(r, 7000));

  await page.screenshot({ path: 'C:/Users/Amine/OneDrive/Projects/family-planner-app/final_mobile.png' });

  const errs = logs.filter(l =>
    l.includes('null') || l.includes('Null') ||
    l.includes('Error') || l.includes('PAGEERROR')
  );
  console.log('Errors:', errs.length === 0 ? 'NONE ✓' : '');
  errs.forEach(e => console.log(e));

  const gp = await page.evaluate(() => {
    const el = document.querySelector('flt-glass-pane');
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { w: r.width, h: r.height, pos: window.getComputedStyle(el).position };
  });
  console.log('Glass pane:', JSON.stringify(gp));

  await browser.close();
  process.exit(0);
})().catch(e => { console.error(e.message); process.exit(1); });
