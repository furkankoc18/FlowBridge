import { createRequire } from "node:module";
import { mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const playwrightPath = process.env.FLOWBRIDGE_PLAYWRIGHT_PATH || "playwright";
const { chromium } = require(playwrightPath);
const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const output = resolve(root, "docs/images");
await mkdir(output, { recursive: true });

const copy = {
  mac: {
    platform: "macOS",
    device: "Studio Mac",
    peer: "Ofis PC",
    instruction: "Bu Mac'in sağ kenarından Ofis PC cihazına geç. Geldiğin kenara dön veya Esc'ye bas.",
    permissions: "2/2",
  },
  windows: {
    platform: "Windows",
    device: "DESKTOP-FLOW",
    peer: "Studio Mac",
    instruction: "Bu Windows cihazının sol kenarından Studio Mac cihazına geçin. Geldiğiniz kenara dönün veya Esc'ye basın.",
    permissions: "Hazır",
  },
};

const styles = `
  *{box-sizing:border-box} html,body{margin:0;width:100%;height:100%;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#172033}
  body{background:radial-gradient(circle at 15% 12%,#c9f5ff 0,transparent 32%),radial-gradient(circle at 90% 85%,#d9d7ff 0,transparent 35%),linear-gradient(135deg,#eefbff,#f5f2ff);overflow:hidden}
  .shot{width:1400px;height:840px;padding:58px 60px;position:relative;overflow:hidden}
  .orb{position:absolute;border-radius:999px;filter:blur(2px);opacity:.42}.orb.a{width:260px;height:260px;background:#64d8ff;right:-80px;top:-100px}.orb.b{width:220px;height:220px;background:#7269f1;left:-90px;bottom:-100px}
  .window{position:relative;width:1280px;height:724px;background:#f8fafc;border:1px solid rgba(55,65,81,.18);border-radius:20px;overflow:hidden;box-shadow:0 32px 85px rgba(42,52,96,.25),0 4px 18px rgba(31,41,55,.12)}
  .titlebar{height:44px;display:flex;align-items:center;border-bottom:1px solid #dfe5ee;background:rgba(255,255,255,.86);backdrop-filter:blur(12px)}
  .mac-dots{display:flex;gap:8px;margin-left:17px}.dot{width:12px;height:12px;border-radius:50%}.red{background:#ff5f57}.yellow{background:#febc2e}.green{background:#28c840}
  .title{position:absolute;left:50%;transform:translateX(-50%);font-size:13px;font-weight:600;color:#687386}
  .win-title{padding:0 14px;gap:9px;font-size:13px;font-weight:600}.win-title img{width:22px;height:22px}.win-buttons{margin-left:auto;display:flex;height:44px}.win-buttons span{width:47px;display:grid;place-items:center;color:#687386;font-size:14px}.win-buttons .close{font-size:18px}
  .app{display:grid;grid-template-columns:242px 1fr;height:680px}.sidebar{padding:22px 18px;display:flex;flex-direction:column;border-right:1px solid #e1e7ef;background:#f3f6fa}.windows .sidebar{background:#172033;color:#fff;border:0}.brand{display:flex;align-items:center;gap:12px;padding:6px 7px 25px}.mark{width:44px;height:44px;border-radius:13px;background:linear-gradient(135deg,#6067e9,#27c7e8);display:grid;place-items:center;color:#fff;font-size:25px;font-weight:700;box-shadow:0 8px 18px rgba(79,92,226,.32)}
  .brand-name{font-size:18px;font-weight:700}.brand-sub{font-size:11px;color:#8190a6;margin-top:3px}.windows .brand-sub{color:#9ea8bd}
  .nav{display:flex;flex-direction:column;gap:8px}.nav div{height:43px;border-radius:10px;padding:12px 13px;font-size:14px;color:#566277}.nav .active{background:#fff;color:#3444b9;font-weight:650;box-shadow:0 2px 10px rgba(55,65,81,.08)}.windows .nav div{color:#cbd4e3}.windows .nav .active{background:#26324a;color:#fff;box-shadow:none}
  .status{margin-top:auto;padding:12px 10px;color:#68768d;font-size:12px}.windows .status{color:#b1bdcf}.status-line{display:flex;align-items:center;gap:8px;font-weight:600;color:#263347}.windows .status-line{color:#e4eaf4}.status i{width:8px;height:8px;border-radius:50%;background:#34c775;box-shadow:0 0 0 4px rgba(52,199,117,.12)}.device{margin:7px 0 0 16px;font-size:11px}
  main{padding:34px 38px;background:#f8fafc;overflow:hidden}.eyebrow{font-size:12px;color:#68768d;font-weight:650;text-transform:uppercase;letter-spacing:.08em}.headline{font-size:33px;line-height:1.1;margin:7px 0 5px;font-weight:760;letter-spacing:-.035em}.subhead{font-size:15px;color:#6d788c;margin-bottom:25px}
  .metrics{display:grid;grid-template-columns:repeat(3,1fr);gap:13px;margin-bottom:15px}.card{background:#fff;border:1px solid #e4e9f1;border-radius:15px;padding:18px;box-shadow:0 5px 16px rgba(47,57,90,.055)}.metric-label{font-size:10px;letter-spacing:.06em;text-transform:uppercase;color:#788499;font-weight:700}.metric-value{font-size:24px;font-weight:750;margin-top:8px}.blue{color:#5862dc}.good{color:#199859}
  .activity{display:grid;grid-template-columns:42px 1fr auto;align-items:center;gap:14px;margin-bottom:15px}.activity-icon{width:42px;height:42px;border-radius:13px;background:#e9ecff;display:grid;place-items:center;font-size:22px}.activity strong,.mouse strong{font-size:16px}.small{font-size:12px;color:#778398;margin-top:4px;line-height:1.45}.toggle{width:43px;height:25px;border-radius:99px;background:#39bd71;padding:3px}.toggle:after{content:"";display:block;width:19px;height:19px;border-radius:50%;background:white;margin-left:18px;box-shadow:0 2px 5px rgba(0,0,0,.18)}
  .bottom{display:grid;grid-template-columns:1.25fr .75fr;gap:15px}.mouse{display:flex;gap:14px;align-items:center}.mouse .activity-icon{background:#e8f8ff;color:#1c8eb2}.peer{display:flex;align-items:center;gap:12px}.peer-icon{width:42px;height:42px;border-radius:12px;background:#eef0ff;display:grid;place-items:center;font-size:21px}.peer-copy{flex:1}.badge{font-size:11px;font-weight:700;color:#16894d;background:#e4f8ed;padding:6px 9px;border-radius:99px}
  .hero{width:1600px;height:900px;padding:58px 64px;position:relative;overflow:hidden;background:radial-gradient(circle at 12% 8%,#a9efff 0,transparent 30%),radial-gradient(circle at 90% 90%,#aca7ff 0,transparent 35%),linear-gradient(135deg,#effcff,#f6f2ff)}
  .hero-copy{position:relative;z-index:4;text-align:center}.hero-logo{display:inline-flex;align-items:center;gap:13px;font-size:36px;font-weight:800;letter-spacing:-.04em}.hero-logo .mark{width:54px;height:54px;font-size:30px}.hero h1{font-size:51px;line-height:1.05;letter-spacing:-.045em;margin:18px auto 9px;max-width:900px}.hero p{margin:0;color:#657189;font-size:19px}.devices{height:555px;position:relative;margin-top:42px}.mini{position:absolute;width:760px;height:458px;border-radius:17px;background:#f8fafc;border:1px solid rgba(60,70,110,.18);box-shadow:0 28px 70px rgba(44,54,98,.25);overflow:hidden}.mini.macshot{left:55px;top:0;transform:rotate(-3deg)}.mini.winshot{right:55px;top:34px;transform:rotate(3deg)}.mini-bar{height:34px;background:#fff;border-bottom:1px solid #e4e8ef;padding:10px 13px;display:flex;gap:6px}.mini-bar i{width:8px;height:8px;border-radius:50%;background:#ff5f57}.mini-bar i:nth-child(2){background:#febc2e}.mini-bar i:nth-child(3){background:#28c840}.mini-app{display:grid;grid-template-columns:150px 1fr;height:424px}.mini-side{background:#172033;padding:22px 14px;color:white}.mini.macshot .mini-side{background:#f1f4f8;color:#273246;border-right:1px solid #e2e7ee}.mini-brand{font-size:16px;font-weight:750;margin-bottom:28px}.mini-nav{height:28px;border-radius:7px;margin:7px 0;background:rgba(255,255,255,.08)}.mini.macshot .mini-nav{background:#fff}.mini-main{padding:31px;background:#f8fafc}.mini-main h2{font-size:25px;margin:0 0 7px}.mini-main p{font-size:12px;color:#748095;margin:0 0 20px}.mini-cards{display:grid;grid-template-columns:repeat(3,1fr);gap:9px}.mini-card{height:86px;background:#fff;border:1px solid #e4e9f1;border-radius:11px}.mini-wide{height:90px;background:#fff;border:1px solid #e4e9f1;border-radius:11px;margin-top:10px;padding:18px}.mini-wide b{font-size:14px}.bridge{position:absolute;z-index:5;left:50%;top:215px;transform:translateX(-50%);width:94px;height:94px;border-radius:30px;background:linear-gradient(135deg,#5965e8,#22c5e6);display:grid;place-items:center;color:#fff;font-size:48px;font-weight:800;box-shadow:0 18px 38px rgba(67,85,220,.36);border:6px solid rgba(255,255,255,.88)}
`;

function appPreview(os) {
  const c = copy[os];
  const titlebar = os === "mac"
    ? `<div class="titlebar"><div class="mac-dots"><i class="dot red"></i><i class="dot yellow"></i><i class="dot green"></i></div><div class="title">FlowBridge</div></div>`
    : `<div class="titlebar win-title"><span>↔</span> FlowBridge <div class="win-buttons"><span>—</span><span>□</span><span class="close">×</span></div></div>`;
  return `<!doctype html><meta charset="utf-8"><style>${styles}</style><body><div class="shot ${os}"><i class="orb a"></i><i class="orb b"></i><section class="window ${os === "windows" ? "windows" : "mac"}">${titlebar}<div class="app"><aside class="sidebar"><div class="brand"><div class="mark">↔</div><div><div class="brand-name">FlowBridge</div><div class="brand-sub">macOS + Windows</div></div></div><nav class="nav"><div class="active">▣ &nbsp; Genel Bakış</div><div>▰ &nbsp; Cihazlar</div><div>◆ &nbsp; Gizlilik</div><div>＋ &nbsp; Teşhis</div></nav><div class="status"><div class="status-line"><i></i>Ağ taranıyor</div><div class="device">${c.device}</div></div></aside><main><div class="eyebrow">FlowBridge ${c.platform} · 0.4.0</div><div class="headline">Tek masa. İki bilgisayar.</div><div class="subhead">Mac ve Windows cihazlarını güvenli yerel bağlantıda tek fareyle kullan.</div><div class="metrics"><div class="card"><div class="metric-label">Yakındaki cihaz</div><div class="metric-value blue">1</div></div><div class="card"><div class="metric-label">Sistem izinleri</div><div class="metric-value good">${c.permissions}</div></div><div class="card"><div class="metric-label">Güvenli bağlantı</div><div class="metric-value blue">AES-GCM</div></div></div><div class="card activity"><div class="activity-icon">◉</div><div><strong>FlowBridge aktif</strong><div class="small">Bu bilgisayar aynı ağdaki FlowBridge cihazlarını arıyor.</div></div><div class="toggle"></div></div><div class="bottom"><div class="card mouse"><div class="activity-icon">➤</div><div><strong>Ortak fare</strong><div class="small">${c.instruction}</div></div></div><div class="card peer"><div class="peer-icon">▣</div><div class="peer-copy"><strong>${c.peer}</strong><div class="small">Güvenli yerel bağlantı</div></div><div class="badge">Eşleşti</div></div></div></main></div></section></div>`;
}

function heroPreview() {
  return `<!doctype html><meta charset="utf-8"><style>${styles}</style><body><div class="hero"><i class="orb a"></i><i class="orb b"></i><div class="hero-copy"><div class="hero-logo"><div class="mark">↔</div>FlowBridge</div><h1>One mouse. Two computers.</h1><p>Open-source mouse sharing for macOS and Windows — private, local and fast.</p></div><div class="devices"><div class="mini macshot"><div class="mini-bar"><i></i><i></i><i></i></div><div class="mini-app"><div class="mini-side"><div class="mini-brand">↔ &nbsp; FlowBridge</div><div class="mini-nav"></div><div class="mini-nav"></div><div class="mini-nav"></div></div><div class="mini-main"><h2>Tek masa. İki bilgisayar.</h2><p>Güvenli yerel bağlantıda ortak fare.</p><div class="mini-cards"><div class="mini-card"></div><div class="mini-card"></div><div class="mini-card"></div></div><div class="mini-wide"><b>FlowBridge macOS · 0.4.0</b></div></div></div></div><div class="mini winshot"><div class="mini-bar"></div><div class="mini-app"><div class="mini-side"><div class="mini-brand">↔ &nbsp; FlowBridge</div><div class="mini-nav"></div><div class="mini-nav"></div><div class="mini-nav"></div></div><div class="mini-main"><h2>Tek masa. İki bilgisayar.</h2><p>Güvenli yerel bağlantıda ortak fare.</p><div class="mini-cards"><div class="mini-card"></div><div class="mini-card"></div><div class="mini-card"></div></div><div class="mini-wide"><b>FlowBridge Windows · 0.4.0</b></div></div></div></div><div class="bridge">↔</div></div></div>`;
}

const browser = await chromium.launch({
  headless: true,
  executablePath: process.env.FLOWBRIDGE_CHROMIUM_EXECUTABLE || undefined,
});
for (const [name, html, viewport] of [
  ["flowbridge-macos-preview.png", appPreview("mac"), { width: 1400, height: 840 }],
  ["flowbridge-windows-preview.png", appPreview("windows"), { width: 1400, height: 840 }],
  ["flowbridge-hero.png", heroPreview(), { width: 1600, height: 900 }],
]) {
  const page = await browser.newPage({ viewportSize: viewport, deviceScaleFactor: 1 });
  await page.setContent(html, { waitUntil: "load" });
  await page.screenshot({ path: resolve(output, name), fullPage: true });
  await page.close();
}
await browser.close();
console.log(output);
