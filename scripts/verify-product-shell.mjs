import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

async function readOptionalText(path) {
  try {
    return await readFile(new URL(path, import.meta.url), "utf8");
  } catch (error) {
    if (error?.code === "ENOENT") return "";
    throw error;
  }
}

const [
  app,
  iosHealthPanel,
  styles,
  viteConfig,
  pagesWorkflow,
  index,
  manifest,
  serviceWorker,
  pwa,
  nativePlugin,
  bridgeController,
  storyboard,
  infoPlist,
  entitlements,
  xcodeProject,
  identityGenerator,
  iosIcon,
  iosSplash,
] = await Promise.all([
  readFile(new URL("../src/App.jsx", import.meta.url), "utf8"),
  readFile(new URL("../src/IOSHealthPanel.jsx", import.meta.url), "utf8"),
  readFile(new URL("../src/styles.css", import.meta.url), "utf8"),
  readFile(new URL("../vite.config.js", import.meta.url), "utf8"),
  readOptionalText("../.github/workflows/deploy-pages.yml"),
  readFile(new URL("../index.html", import.meta.url), "utf8"),
  readFile(new URL("../public/manifest.webmanifest", import.meta.url), "utf8"),
  readFile(new URL("../public/sw.js", import.meta.url), "utf8"),
  readFile(new URL("../src/pwa.js", import.meta.url), "utf8"),
  readFile(new URL("../ios/App/App/ArchiveNativePlugin.swift", import.meta.url), "utf8"),
  readFile(new URL("../ios/App/App/ArchiveBridgeViewController.swift", import.meta.url), "utf8"),
  readFile(new URL("../ios/App/App/Base.lproj/Main.storyboard", import.meta.url), "utf8"),
  readFile(new URL("../ios/App/App/Info.plist", import.meta.url), "utf8"),
  readFile(new URL("../ios/App/App/App.entitlements", import.meta.url), "utf8"),
  readFile(new URL("../ios/App/App.xcodeproj/project.pbxproj", import.meta.url), "utf8"),
  readFile(new URL("./generate-launcher-icons.ps1", import.meta.url), "utf8"),
  readFile(new URL("../ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png", import.meta.url)),
  readFile(new URL("../ios/App/App/Assets.xcassets/Splash.imageset/splash-2732x2732.png", import.meta.url)),
]);

assert.match(app, /function TopBar\(/);
assert.match(app, /aria-label="More page actions"/);
assert.match(app, /function WaterCapture\(/);
assert.match(app, /function SleepNightSummary\(/);
assert.match(app, /lazy\(loadIOSHealthPanel\)/);
assert.match(iosHealthPanel, /function IOSHealthPanel\(/);
assert.match(iosHealthPanel, /registerPlugin\("ArchiveNative"\)/);
assert.match(iosHealthPanel, /presentHealthAccessPrimer/);
assert.match(app, /status: "iosFoundation"/);
assert.match(app, /platform === "android"/);
assert.match(app, /if \(platform === "ios"\) return \{ ok: false, status: "iosFoundation" \}/);
assert.match(styles, /Archive Living Canvas/);
assert.match(styles, /\.metric-capture\s*\{/);
assert.match(styles, /\.canvas-screen \.pinned-panels-section \.module-panel\s*\{/);

const parsedManifest = JSON.parse(manifest);
assert.equal(parsedManifest.display, "standalone");
assert.equal(parsedManifest.short_name, "Archive");
assert.match(index, /apple-mobile-web-app-capable/);
assert.match(index, /manifest\.webmanifest/);
assert.match(serviceWorker, /request\.mode === "navigate"/);
assert.match(pwa, /import\.meta\.env\.PROD/);
assert.match(pwa, /localhost/);
assert.match(viteConfig, /process\.env\.ARCHIVE_WEB_BASE \|\| "\.\/"/);
assert.match(pagesWorkflow, /branches:\s*\[main\]/);
assert.match(pagesWorkflow, /workflow_dispatch:/);
assert.match(pagesWorkflow, /if:\s*github\.ref == 'refs\/heads\/main'/);
assert.match(pagesWorkflow, /pages:\s*write/);
assert.match(pagesWorkflow, /id-token:\s*write/);
assert.doesNotMatch(pagesWorkflow, /permissions:\s*\n\s+contents: read\s*\n\s+pages: write/);
assert.match(pagesWorkflow, /deploy:[\s\S]*permissions:\s*\n\s+pages: write\s*\n\s+id-token: write/);
assert.match(pagesWorkflow, /ARCHIVE_WEB_BASE:\s*\/Archive\//);
assert.match(pagesWorkflow, /run:\s*npm run verify/);
assert.match(pagesWorkflow, /path:\s*\.\/dist/);
assert.match(pagesWorkflow, /uses:\s*actions\/deploy-pages@v4/);

assert.match(nativePlugin, /CAPBridgedPlugin/);
assert.match(nativePlugin, /presentHealthAccessPrimer/);
assert.match(nativePlugin, /requestAuthorization\(toShare: \[\], read: readTypes\)/);
assert.match(nativePlugin, /healthImportReady": false/);
assert.match(bridgeController, /registerPluginInstance\(ArchiveNativePlugin\(\)\)/);
assert.match(storyboard, /customClass="ArchiveBridgeViewController"/);
assert.match(infoPlist, /NSHealthShareUsageDescription/);
assert.match(entitlements, /com\.apple\.developer\.healthkit/);
assert.match(xcodeProject, /ArchiveNativePlugin\.swift in Sources/);
assert.match(xcodeProject, /CODE_SIGN_ENTITLEMENTS = App\/App\.entitlements/);
assert.doesNotMatch(xcodeProject, /IPHONEOS_DEPLOYMENT_TARGET = 14\.0/);
assert.match(xcodeProject, /IPHONEOS_DEPLOYMENT_TARGET = 15\.0/);
assert.match(identityGenerator, /New-ArchiveBitmap -Size 1024 -Variant "square"/);
assert.match(identityGenerator, /New-ArchiveSplashBitmap -Size 2732/);
assert.ok(iosIcon.length > 20_000, "iOS Archive icon should be a real branded raster");
assert.ok(iosSplash.length > 20_000, "iOS Archive launch image should be a real branded raster");

console.log("Living Canvas, PWA, and iOS native-boundary verification passed.");
