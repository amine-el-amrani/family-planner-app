const puppeteer = require('puppeteer');
(async () => {
  const browser = await puppeteer.launch({
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage();

  // Desktop viewport
  await page.setViewport({ width: 1280, height: 800 });
  await page.goto('https://family-planner-sage.vercel.app/login', {
    waitUntil: 'networkidle0',
    timeout: 30000
  });

  // Wait for Flutter CanvasKit to fully render
  await new Promise(r => setTimeout(r, 5000));

  // Screenshot 1: initial state
  await page.screenshot({ path: 'C:/Users/Amine/OneDrive/Projects/family-planner-app/ss_1_initial.png' });
  console.log('1. Initial screenshot saved');

  // Click email field (center of page, roughly where the email field should be)
  await page.mouse.click(640, 370);
  await new Promise(r => setTimeout(r, 1500));
  await page.screenshot({ path: 'C:/Users/Amine/OneDrive/Projects/family-planner-app/ss_2_click_email.png' });
  console.log('2. After clicking email field');

  // Type email
  await page.keyboard.type('test@example.com');
  await new Promise(r => setTimeout(r, 1000));
  await page.screenshot({ path: 'C:/Users/Amine/OneDrive/Projects/family-planner-app/ss_3_typed_email.png' });
  console.log('3. After typing email');

  // Tab to password field
  await page.keyboard.press('Tab');
  await new Promise(r => setTimeout(r, 500));
  await page.keyboard.type('password123');
  await new Promise(r => setTimeout(r, 1000));
  await page.screenshot({ path: 'C:/Users/Amine/OneDrive/Projects/family-planner-app/ss_4_typed_password.png' });
  console.log('4. After typing password');

  // Mobile viewport test
  await page.setViewport({ width: 390, height: 844, deviceScaleFactor: 2 });
  await page.reload({ waitUntil: 'networkidle0' });
  await new Promise(r => setTimeout(r, 5000));
  await page.screenshot({ path: 'C:/Users/Amine/OneDrive/Projects/family-planner-app/ss_5_mobile.png' });
  console.log('5. Mobile screenshot saved');

  await browser.close();
  console.log('All screenshots saved!');
})().catch(e => { console.error('ERROR:', e.message); process.exit(1); });
