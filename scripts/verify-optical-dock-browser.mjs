// Optional interactive-rendering check. Supply an installed Playwright module
// through ARCHIVE_PLAYWRIGHT_MODULE; no app/runtime dependency is required.
import assert from "node:assert/strict";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { createServer } from "node:http";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const modulePath = process.env.ARCHIVE_PLAYWRIGHT_MODULE;
const { chromium } = await import(modulePath ? pathToFileURL(modulePath).href : "playwright");
const remote = process.env.ARCHIVE_WEBVIEW_CDP;
const adb = remote && process.env.ARCHIVE_WEBVIEW_ADB;
const serial = process.env.ARCHIVE_WEBVIEW_SERIAL;
assert.ok(!adb || serial, "native compositor capture requires an explicit adb device serial");
const execFileAsync = promisify(execFile);
let server;
let url = process.env.ARCHIVE_GLASS_URL;
if (!remote && !url) {
  const root = resolve("dist");
  server = createServer(async (request, response) => {
    const path = resolve(root, `.${new URL(request.url, "http://localhost").pathname === "/" ? "/index.html" : new URL(request.url, "http://localhost").pathname}`);
    if (!path.startsWith(`${root}\\`) && !path.startsWith(`${root}/`)) { response.writeHead(403).end(); return; }
    try {
      const content = await readFile(path);
      const type = path.endsWith(".js") ? "application/javascript" : path.endsWith(".css") ? "text/css" : path.endsWith(".html") ? "text/html" : "application/octet-stream";
      response.writeHead(200, { "Content-Type": type }).end(content);
    } catch { response.writeHead(404).end(); }
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  url = `http://127.0.0.1:${server.address().port}/`;
}
const output = resolve(process.env.ARCHIVE_GLASS_OUTPUT ?? "test-results/optical-dock");
await mkdir(output, { recursive: true });
const browser = remote
  ? await chromium.connectOverCDP(remote)
  : await chromium.launch({ channel: process.env.ARCHIVE_BROWSER_CHANNEL ?? "msedge", headless: true, args: ["--no-proxy-server"] });
const evidence = [];
const errors = [];
let inspectedPage;
const sizes = remote ? [null] : [{ width: 360, height: 800 }, { width: 412, height: 915 }];

try {
  for (const size of sizes) {
    const context = remote ? browser.contexts()[0] : await browser.newContext({ viewport: size, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
    const page = remote ? context.pages().find((tab) => tab.url().includes("localhost")) : await context.newPage();
    assert.ok(page, "packaged Archive WebView target must be available");
    inspectedPage = page;
    page.on("pageerror", (error) => errors.push(error.message));
    if (!remote && process.env.ARCHIVE_GLASS_FIXTURE) {
      const fixture = JSON.parse(await readFile(process.env.ARCHIVE_GLASS_FIXTURE, "utf8"));
      await context.addInitScript((data) => localStorage.setItem("archive-productivity-tracker", JSON.stringify(data)), fixture.data);
    }
    if (!remote) await page.goto(url, { waitUntil: "domcontentloaded", timeout: 120000 });
    else await page.evaluate(() => {
      document.querySelectorAll("#optical-test-backdrop").forEach((node) => node.remove());
      document.querySelector("feDisplacementMap")?.setAttribute("scale", "0.01");
    });
    const nav = page.getByRole("navigation", { name: "Primary" });
    await nav.waitFor();
    const dimensions = await page.evaluate(() => ({ width: innerWidth, height: innerHeight }));
    const edgeTreatment = await page.evaluate(() => {
      const rim = getComputedStyle(document.querySelector(".nav-refraction"));
      const highlight = getComputedStyle(document.querySelector(".nav-specular"));
      const body = getComputedStyle(document.querySelector(".nav-shell"));
      return { mask: rim.maskImage, composite: rim.maskComposite, highlightPadding: highlight.paddingTop, bodyBorder: body.borderTopWidth };
    });
    assert.equal(edgeTreatment.bodyBorder, "0px", "capsule must not have a literal border");
    assert.equal(edgeTreatment.highlightPadding, "0px", "highlight must not be a padded outline");
    assert.equal((edgeTreatment.mask.match(/radial-gradient/g) ?? []).length, 2, "feather mask must join two true semicircular caps");
    assert.ok(edgeTreatment.composite.split(",").every((value) => value.trim() === "add"), "feather mask must not punch out a hard ring");
    const label = `${remote ? "webview" : "browser"}-${dimensions.width}x${dimensions.height}`;
    console.log(`Checking ${label}`);
    const settle = () => page.waitForTimeout(650);
    // Native DPR avoids WebView's scaled-capture re-rasterization of SVG icons.
    const screenshot = async (options = {}) => {
      if (!adb) return page.screenshot({ scale: remote ? "device" : "css", ...options });
      // WebView DevTools capture can omit the transition tree and re-rasterize
      // SVGs. Capture the actual Android compositor instead; compare a ROI in
      // canvas below without changing the packaged app or adding dependencies.
      const { stdout } = await execFileAsync(adb, ["-s", serial, "exec-out", "screencap", "-p"], { encoding: "buffer", maxBuffer: 16 * 1024 * 1024, windowsHide: true, timeout: 30000 });
      if (options.path) await writeFile(options.path, stdout);
      return stdout;
    };
    const comparePixels = (first, second, clip) => page.evaluate(async ([first, second, clip, fullFrame]) => {
      const decode = async (data) => {
        const image = new Image();
        image.src = `data:image/png;base64,${data}`;
        await image.decode();
        const scale = image.width / innerWidth;
        const canvas = document.createElement("canvas");
        canvas.width = fullFrame ? Math.round(clip.width * scale) : image.width;
        canvas.height = fullFrame ? Math.round(clip.height * scale) : image.height;
        const ctx = canvas.getContext("2d");
        if (fullFrame) ctx.drawImage(image, Math.round(clip.x * scale), Math.round(clip.y * scale), canvas.width, canvas.height, 0, 0, canvas.width, canvas.height);
        else ctx.drawImage(image, 0, 0);
        return ctx.getImageData(0, 0, canvas.width, canvas.height);
      };
      const a = await decode(first), b = await decode(second);
      let changedEdgePixels = 0, changedCenterPixels = 0, maximumDifference = 0;
      const vessel = document.querySelector(".nav-shell").getBoundingClientRect();
      const sx = a.width / vessel.width, sy = a.height / vessel.height;
      const centerMargin = vessel.height / 2 + 4;
      for (let y = 0; y < a.height; y++) for (let x = 0; x < a.width; x++) {
        const i = (y * a.width + x) * 4;
        const difference = Math.max(Math.abs(a.data[i] - b.data[i]), Math.abs(a.data[i + 1] - b.data[i + 1]), Math.abs(a.data[i + 2] - b.data[i + 2]));
        if (difference) {
          maximumDifference = Math.max(maximumDifference, difference);
          if (x > centerMargin * sx && x < a.width - centerMargin * sx && y > 13 * sy && y < a.height - 13 * sy) changedCenterPixels++;
          else changedEdgePixels++;
        }
      }
      return { changedEdgePixels, changedCenterPixels, maximumDifference };
    }, [first.toString("base64"), second.toString("base64"), clip, Boolean(adb)]);
    const material = () => page.evaluate(() => {
      const nav = document.querySelector(".bottom-nav");
      const shell = nav.querySelector(".nav-shell");
      const style = (node, pseudo) => {
        const s = getComputedStyle(node, pseudo);
        return { background: s.backgroundColor, image: s.backgroundImage, backdrop: s.backdropFilter, opacity: s.opacity, display: s.display, mask: s.maskComposite };
      };
      return { shell: style(shell), center: style(shell, "::before"), edge: style(nav.querySelector(".nav-refraction")), specular: style(nav.querySelector(".nav-specular")), selection: style(nav.querySelector(".nav-selection-lens")) };
    });
    const checkGeometry = async () => {
      const geometry = await page.evaluate(() => {
        const vessel = document.querySelector(".nav-shell");
        const bounds = vessel.getBoundingClientRect();
        const buttons = [...document.querySelectorAll('.bottom-nav button:not([aria-hidden="true"])')].filter((button) => getComputedStyle(button).visibility !== "hidden");
        return { left: bounds.left, right: bounds.right, width: bounds.width, radius: getComputedStyle(vessel).borderRadius, overflow: document.documentElement.scrollWidth > innerWidth, buttons: buttons.map((button) => ({ name: button.getAttribute("aria-label"), left: button.getBoundingClientRect().left, right: button.getBoundingClientRect().right })) };
      });
      assert.equal(geometry.overflow, false, "page must not overflow horizontally");
      assert.equal(geometry.radius, "999px", "true capsule caps must survive");
      assert.ok(geometry.left >= -1 && geometry.right <= dimensions.width + 1);
      geometry.buttons.forEach((button) => assert.ok(button.left >= geometry.left - 1 && button.right <= geometry.right + 1, `${button.name} must fit inside the vessel`));
      return geometry;
    };
    const checkTransitionLayer = async (button, destination) => {
      assert.equal(await nav.evaluate((node) => getComputedStyle(node).viewTransitionName), "none", "idle dock must sample the real page, not an isolated transition backdrop");
      await button.evaluate((node) => node.click());
      await page.waitForFunction(() => document.documentElement.dataset.archiveTransition === "page"
        && document.getAnimations().some((animation) => animation.effect?.pseudoElement === "::view-transition-group(archive-navigation)"));
      const layers = await page.evaluate(() => {
        // Hold the actual snapshot tree for inspection, rather than inspecting
        // styles after the animation has already hidden the stacking bug.
        document.getAnimations().filter((animation) => animation.effect?.pseudoElement).forEach((animation) => {
          animation.pause();
          animation.currentTime = 130;
        });
        const root = document.documentElement;
        const groupZ = (name) => Number.parseInt(getComputedStyle(root, `::view-transition-group(${name})`).zIndex, 10) || 0;
        const snapshot = getComputedStyle(root, "::view-transition-group(archive-navigation)");
        return { name: getComputedStyle(document.querySelector(".bottom-nav")).viewTransitionName, dock: groupZ("archive-navigation"), page: groupZ("archive-page"), hero: groupZ("archive-hero"), topbar: groupZ("archive-topbar"), backdrop: snapshot.backdropFilter, clip: snapshot.clipPath, inset: root.style.getPropertyValue("--archive-nav-snapshot-inset"), endInset: root.style.getPropertyValue("--archive-nav-snapshot-end-inset") };
      });
      try {
        assert.equal(layers.name, "archive-navigation");
        assert.ok(layers.dock > Math.max(layers.page, layers.hero, layers.topbar), "all page snapshots must remain underneath the dock during navigation");
        assert.equal(layers.backdrop, "blur(0.5px) saturate(1.04)", "transition capture must preserve the same near-clear transmission as the live body");
        assert.match(layers.clip, /inset\(.+round 999px\)/);
        assert.ok(layers.inset, "snapshot filtering must be capsule-bounded");
        await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
        await screenshot({ path: resolve(output, `${label}-${destination}-transition.png`) });
        if (destination === "history") {
          await page.evaluate(async () => {
            const stage = document.querySelector(".page-stage"), nav = document.querySelector(".bottom-nav");
            const probe = document.createElement("div");
            probe.id = "optical-transition-backdrop";
            probe.style.cssText = `position:absolute;z-index:10000;left:0;right:0;top:${nav.getBoundingClientRect().top - stage.getBoundingClientRect().top}px;height:64px;background:repeating-linear-gradient(90deg,#243b53 0 4px,#e7edf5 4px 8px);pointer-events:none`;
            stage.append(probe);
            await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
          });
          const bounds = await page.locator(".nav-shell").boundingBox();
          const clip = { x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height };
          const sampled = await screenshot({ clip, path: resolve(output, `${label}-transition-body.png`) });
          const override = await page.addStyleTag({ content: 'html[data-archive-transition="page"]::view-transition-group(archive-navigation) { backdrop-filter:none; -webkit-backdrop-filter:none; }' });
          try {
            await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
            const unsampled = await screenshot({ clip, path: resolve(output, `${label}-transition-no-body.png`) });
            layers.bodyPixels = await comparePixels(sampled, unsampled, clip);
            assert.ok(layers.bodyPixels.changedCenterPixels > 400 && layers.bodyPixels.maximumDifference > 15, "the whole glass body must really sample content during transitions, not only accept a CSS property");
          } finally {
            await override.evaluate((node) => node.remove());
            await page.evaluate(() => document.querySelector("#optical-transition-backdrop")?.remove());
          }
        }
      } finally {
        await page.evaluate(() => document.getAnimations().filter((animation) => animation.effect?.pseudoElement).forEach((animation) => animation.play()));
      }
      await settle();
      assert.equal(await nav.evaluate((node) => getComputedStyle(node).viewTransitionName), "none", "transition completion must release backdrop isolation");
      assert.deepEqual(await page.evaluate(() => ["inset", "end-inset", "duration"].map((key) => document.documentElement.style.getPropertyValue(`--archive-nav-snapshot-${key}`))), ["", "", ""]);
      return layers;
    };
    let collapsed, productivity, health, before, during, after, reducedTransparency;
    if (!process.env.ARCHIVE_GLASS_OPTICS_ONLY) {
      // A reused native WebView can begin compact after the previous scroll
      // probe. Reset that test precondition before checking expanded geometry.
      await page.evaluate(() => scrollTo({ top: 0, behavior: "instant" }));
      await settle();
      await nav.getByRole("button", { name: "Home", exact: true }).click();
      await settle();
      collapsed = await checkGeometry();
      await screenshot({ path: resolve(output, `${label}-home.png`) });
      await nav.getByRole("button", { name: "Productivity pages" }).click();
      await settle();
      assert.deepEqual(await nav.locator('.nav-group.productivity .nav-page[aria-hidden="false"]').evaluateAll((buttons) => buttons.map((button) => button.getAttribute("aria-label"))), ["Workout", "Workout history", "Habit", "Coach"]);
      productivity = await checkGeometry();
      const historyLayers = await checkTransitionLayer(nav.getByRole("button", { name: "Workout history", exact: true }), "history");
      await screenshot({ path: resolve(output, `${label}-history.png`) });
      await nav.getByRole("button", { name: "Health pages" }).click();
      await settle();
      assert.deepEqual(await nav.locator('.nav-group.health .nav-page[aria-hidden="false"]').evaluateAll((buttons) => buttons.map((button) => button.getAttribute("aria-label"))), ["Water", "Sleep", "Stats", "Settings"]);
      health = await checkGeometry();
      assert.equal(health.width, productivity.width, "both expansions must remain equal");
      const settingsLayers = await checkTransitionLayer(nav.getByRole("button", { name: "Settings", exact: true }), "settings");
      evidence.push({ label, transitionLayers: { history: historyLayers, settings: settingsLayers } });
      before = await material();
      during = await page.evaluate(async () => {
        scrollTo({ top: 300, behavior: "instant" });
        await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
        const shell = document.querySelector(".nav-shell");
        return { background: getComputedStyle(shell).backgroundColor, backdrop: getComputedStyle(shell, "::before").backdropFilter, chrome: document.querySelector(".navigation-chrome").className };
      });
      assert.equal(during.background, before.shell.background);
      assert.equal(during.backdrop, before.center.backdrop);
      await settle();
      after = await material();
      const stable = (value) => ({ ...value, selection: { ...value.selection, opacity: "compact-dependent" } });
      assert.deepEqual(stable(after), stable(before), "scroll/collapse must not alter the optical material (selection visibility follows preserved compact behavior)");
      await screenshot({ path: resolve(output, `${label}-scroll.png`) });
      await page.evaluate(() => scrollTo({ top: 0, behavior: "instant" }));
      await settle();
      await screenshot({ path: resolve(output, `${label}-health.png`) });

      await page.evaluate(async () => {
        document.querySelector('.nav-page[aria-label="Water"]').click();
        await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
        document.querySelector('.nav-page[aria-label="Sleep"]').click();
      });
      await settle();
      assert.equal(await nav.evaluate((node) => getComputedStyle(node).viewTransitionName), "none", "interrupted transitions must not leave dock backdrop isolation behind");
      assert.equal(await page.evaluate(() => document.documentElement.dataset.archiveTransition), undefined);
      await checkTransitionLayer(nav.getByRole("button", { name: "Settings", exact: true }), "settings-return");
      const homeLayers = await checkTransitionLayer(nav.getByRole("button", { name: "Home", exact: true }), "home-collapse");
      const homeGeometry = await checkGeometry();
      assert.deepEqual(homeLayers.endInset.split(" ").map(Number.parseFloat), [0, (dimensions.width - homeGeometry.width) / 2, 0, (dimensions.width - homeGeometry.width) / 2], "snapshot backdrop must shrink with Home, without leaving a stale expanded blur footprint");
      await nav.getByRole("button", { name: "Health pages" }).click();
      await settle();
      await checkTransitionLayer(nav.getByRole("button", { name: "Settings", exact: true }), "settings-from-home");

      const home = nav.getByRole("button", { name: "Home", exact: true });
      await home.focus();
      assert.equal(await home.evaluate((button) => button === document.activeElement), true);
      await home.dispatchEvent("pointerdown", { pointerType: "touch", clientX: dimensions.width / 2 + 20, clientY: dimensions.height - 40 });
      await page.waitForTimeout(120);
      const pressed = await nav.evaluate((node) => node.style.getPropertyValue("--glass-light-x"));
      await home.dispatchEvent("pointerup", { pointerType: "touch" });
      await settle();
      assert.ok(pressed);
      assert.equal(await nav.evaluate((node) => node.style.getPropertyValue("--glass-light-x")), "50.00%");
      const cdp = await context.newCDPSession(page);
      await cdp.send("Emulation.setEmulatedMedia", { features: [{ name: "prefers-reduced-transparency", value: "reduce" }] });
      reducedTransparency = await material();
      assert.equal(reducedTransparency.shell.background, "rgb(248, 248, 250)");
      assert.equal(reducedTransparency.center.display, "none");
      assert.equal(reducedTransparency.edge.display, "none");
      await screenshot({ path: resolve(output, `${label}-reduced-transparency.png`) });
      await cdp.send("Emulation.setEmulatedMedia", { features: [{ name: "prefers-reduced-motion", value: "reduce" }] });
      await home.dispatchEvent("pointerdown", { pointerType: "touch", clientX: 10, clientY: 10 });
      await home.dispatchEvent("pointerup", { pointerType: "touch" });
      assert.equal(await nav.evaluate((node) => node.style.getPropertyValue("--glass-light-x")), "50.00%");
      assert.equal(await page.locator(".nav-shell").evaluate((node) => getComputedStyle(node).transitionDuration), "0s");
      await nav.getByRole("button", { name: "Sleep", exact: true }).evaluate((node) => node.click());
      assert.equal(await nav.evaluate((node) => getComputedStyle(node).viewTransitionName), "none", "reduced motion must bypass snapshot capture");
      assert.equal(await page.evaluate(() => document.documentElement.dataset.archiveTransition), undefined);
      await nav.getByRole("button", { name: "Settings", exact: true }).evaluate((node) => node.click());
      await cdp.send("Emulation.setEmulatedMedia", { features: [] });
      await cdp.detach();
      await settle();
    }
    // Controlled backdrop proves that the SVG filter actually bends pixels,
    // not merely that the CSS parser accepts url(). Never writes tracker data.
    if (process.env.ARCHIVE_GLASS_OPTICS_ONLY) {
      await page.evaluate(() => scrollTo({ top: 0, behavior: "instant" }));
      await settle();
      health = await checkGeometry();
      before = await material();
    }
    await page.evaluate(() => {
      const probe = document.createElement("div");
      probe.id = "optical-test-backdrop";
      probe.style.cssText = "position:fixed;inset:auto 0 0;height:110px;z-index:7;background:repeating-linear-gradient(90deg,#243343 0px,#243343 3px,#c2d6ed 3px,#c2d6ed 9px);pointer-events:none";
      document.body.append(probe);
    });
    await page.waitForTimeout(100);
    const bounds = await page.locator(".nav-shell").boundingBox();
    const clip = { x: Math.ceil(bounds.x + 1), y: Math.ceil(bounds.y + 1), width: Math.floor(bounds.width - 2), height: Math.floor(bounds.height - 2) };
    // Measure transmitted contrast, not merely a smaller computed blur.
    // Temporarily hide only foreground controls in this isolated test view.
    // Compare the current body with the previous frosted body on the same
    // stripe backdrop, excluding the optical edge/caps from both samples.
    const foreground = await page.addStyleTag({ content: '.bottom-nav button, .nav-selection-lens { opacity:0 !important; transition:none !important; }' });
    let clarity, changedEdgePixels, changedCenterPixels, maximumDifference;
    try {
      await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      // Isolate displacement before mutating the body for the frost probe:
      // changing that sibling filter can invalidate Chromium's shared sample
      // raster. Keep foreground SVG controls out of this pixel comparison.
      const warped = await screenshot({ clip, path: resolve(output, `${label}-refraction-probe.png`) });
      await page.locator("feDisplacementMap").evaluate((node) => node.setAttribute("scale", "0"));
      await page.waitForTimeout(100);
      const unwarped = await screenshot({ clip, path: resolve(output, `${label}-no-displacement-probe.png`) });
      ({ changedEdgePixels, changedCenterPixels, maximumDifference } = await comparePixels(warped, unwarped, clip));
      console.log({ changedEdgePixels, changedCenterPixels, maximumDifference });
      assert.ok(changedEdgePixels > 400 && maximumDifference >= 15, "SVG displacement must bend real backdrop pixels, not just change antialiasing");
      assert.equal(changedCenterPixels, 0, "edge refraction must leave the calm center untouched");
      await page.locator("feDisplacementMap").evaluate((node) => node.setAttribute("scale", "0.01"));
      await settle();
      const clear = await screenshot({ clip, path: resolve(output, `${label}-clear-body-probe.png`) });
      const frost = await page.addStyleTag({ content: `.nav-shell::before {
        backdrop-filter:blur(3px) saturate(1.12); -webkit-backdrop-filter:blur(3px) saturate(1.12);
        background:radial-gradient(ellipse at var(--glass-light-x) var(--glass-light-y),rgba(255,255,255,.16),transparent 68%),linear-gradient(180deg,rgba(255,255,255,.18),rgba(255,255,255,.035) 42%,rgba(37,48,64,.055) 76%,rgba(255,255,255,.1));
      }` });
      try {
        await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
        const frosted = await screenshot({ clip, path: resolve(output, `${label}-previous-frost-probe.png`) });
        clarity = await page.evaluate(async ([clear, frosted, clip, fullFrame]) => {
          const contrast = async (data) => {
            const image = new Image();
            image.src = `data:image/png;base64,${data}`;
            await image.decode();
            const scale = image.width / innerWidth;
            const canvas = document.createElement("canvas");
            canvas.width = fullFrame ? Math.round(clip.width * scale) : image.width;
            canvas.height = fullFrame ? Math.round(clip.height * scale) : image.height;
            const ctx = canvas.getContext("2d");
            if (fullFrame) ctx.drawImage(image, Math.round(clip.x * scale), Math.round(clip.y * scale), canvas.width, canvas.height, 0, 0, canvas.width, canvas.height);
            else ctx.drawImage(image, 0, 0);
            const pixels = ctx.getImageData(0, 0, canvas.width, canvas.height).data;
            const sx = canvas.width / clip.width, sy = canvas.height / clip.height;
            const cap = document.querySelector(".nav-shell").getBoundingClientRect().height / 2 + 4;
            const samples = [];
            for (let y = Math.ceil(13 * sy); y < canvas.height - 13 * sy; y++) {
              for (let x = Math.ceil(cap * sx); x < canvas.width - cap * sx; x++) {
                const i = (y * canvas.width + x) * 4;
                samples.push(.2126 * pixels[i] + .7152 * pixels[i + 1] + .0722 * pixels[i + 2]);
              }
            }
            samples.sort((a, b) => a - b);
            return samples[Math.floor(samples.length * .95)] - samples[Math.floor(samples.length * .05)];
          };
          return { clearContrast: await contrast(clear), previousContrast: await contrast(frosted) };
        }, [clear.toString("base64"), frosted.toString("base64"), clip, Boolean(adb)]);
        assert.ok(clarity.clearContrast > 80 && clarity.clearContrast > clarity.previousContrast * 1.4, "clear body must transmit materially sharper background contrast than the previous frost");
        console.log({ clarity });
      } finally { await frost.evaluate((node) => node.remove()); }
      await page.evaluate(() => document.querySelector("#optical-test-backdrop").remove());
    } finally { await foreground.evaluate((node) => node.remove()); }
    const frames = await page.evaluate(async () => {
      const deltas = [];
      let last = 0;
      for (let i = 0; i < 90; i++) {
        const time = await new Promise((resolve) => requestAnimationFrame(resolve));
        if (last) deltas.push(time - last);
        last = time;
        scrollTo({ top: 60 + i * 3, behavior: "instant" });
      }
      deltas.sort((a, b) => a - b);
      await new Promise((resolve) => setTimeout(resolve, 650));
      return { p95Ms: deltas[Math.floor(deltas.length * 0.95)], maxMs: deltas.at(-1), idleNavAnimations: document.querySelector(".bottom-nav").getAnimations({ subtree: true }).filter((animation) => animation.playState === "running").length };
    });
    console.log({ label, frames });
    assert.equal(frames.idleNavAnimations, 0, "the idle dock must not keep animations running");
    evidence.push({ label, edgeTreatment, clarity, collapsed, productivity, health, before, during, after, reducedTransparency, changedEdgePixels, changedCenterPixels, maximumDifference, frames });
    if (!remote) await context.close();
  }
  assert.deepEqual(errors, [], "no runtime errors");
  await writeFile(resolve(output, "evidence.json"), JSON.stringify(evidence, null, 2));
  console.log(`Optical dock browser checks passed: ${evidence.map((entry) => entry.label).join(", ")}. Evidence: ${output}`);
} finally {
  if (inspectedPage && !inspectedPage.isClosed()) await inspectedPage.evaluate(() => {
    document.querySelectorAll("#optical-test-backdrop").forEach((node) => node.remove());
    document.querySelector("#optical-transition-backdrop")?.remove();
    document.querySelector("feDisplacementMap")?.setAttribute("scale", "0.01");
  }).catch(() => {});
  await browser.close();
  if (server) await new Promise((resolve) => server.close(resolve));
}
