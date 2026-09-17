// Optional interactive-rendering check. Supply an installed Playwright module
// through ARCHIVE_PLAYWRIGHT_MODULE; no app/runtime dependency is required.
import assert from "node:assert/strict";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { createServer } from "node:http";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const modulePath = process.env.ARCHIVE_PLAYWRIGHT_MODULE;
const { chromium } = await import(modulePath ? pathToFileURL(modulePath).href : "playwright");
const remote = process.env.ARCHIVE_WEBVIEW_CDP;
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
    const label = `${remote ? "webview" : "browser"}-${dimensions.width}x${dimensions.height}`;
    console.log(`Checking ${label}`);
    const settle = () => page.waitForTimeout(650);
    // Native DPR avoids WebView's scaled-capture re-rasterization of SVG icons.
    const screenshot = (options = {}) => page.screenshot({ scale: remote ? "device" : "css", ...options });
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
    let collapsed, productivity, health, before, during, after, reducedTransparency;
    if (!process.env.ARCHIVE_GLASS_OPTICS_ONLY) {
      await nav.getByRole("button", { name: "Home", exact: true }).click();
      await settle();
      collapsed = await checkGeometry();
      await screenshot({ path: resolve(output, `${label}-home.png`) });
      await nav.getByRole("button", { name: "Productivity pages" }).click();
      await settle();
      assert.deepEqual(await nav.locator('.nav-group.productivity .nav-page[aria-hidden="false"]').evaluateAll((buttons) => buttons.map((button) => button.getAttribute("aria-label"))), ["Workout", "Workout history", "Habit", "Coach"]);
      productivity = await checkGeometry();
      await nav.getByRole("button", { name: "Workout history", exact: true }).click();
      await settle();
      await screenshot({ path: resolve(output, `${label}-history.png`) });
      await nav.getByRole("button", { name: "Health pages" }).click();
      await settle();
      assert.deepEqual(await nav.locator('.nav-group.health .nav-page[aria-hidden="false"]').evaluateAll((buttons) => buttons.map((button) => button.getAttribute("aria-label"))), ["Water", "Sleep", "Stats", "Settings"]);
      health = await checkGeometry();
      assert.equal(health.width, productivity.width, "both expansions must remain equal");
      await nav.getByRole("button", { name: "Settings", exact: true }).click();
      await settle();
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
      await cdp.send("Emulation.setEmulatedMedia", { features: [] });
      await cdp.detach();
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
    const warped = await screenshot({ clip, path: resolve(output, `${label}-refraction-probe.png`) });
    await page.locator("feDisplacementMap").evaluate((node) => node.setAttribute("scale", "0"));
    await page.waitForTimeout(100);
    const unwarped = await screenshot({ clip, path: resolve(output, `${label}-no-displacement-probe.png`) });
    const { changedEdgePixels, changedCenterPixels, maximumDifference } = await page.evaluate(async ([first, second]) => {
      const decode = async (data) => {
        const image = new Image();
        image.src = `data:image/png;base64,${data}`;
        await image.decode();
        const canvas = document.createElement("canvas");
        canvas.width = image.width; canvas.height = image.height;
        const ctx = canvas.getContext("2d");
        ctx.drawImage(image, 0, 0);
        return ctx.getImageData(0, 0, image.width, image.height);
      };
      const a = await decode(first), b = await decode(second);
      let changedEdgePixels = 0, changedCenterPixels = 0, maximumDifference = 0;
      // Capture pixel bounds scale with devicePixelRatio in Android WebView.
      const vessel = document.querySelector(".nav-shell").getBoundingClientRect();
      const sx = a.width / vessel.width;
      const sy = a.height / vessel.height;
      // Exclude circular end caps from the flat-center probe, using actual
      // capsule geometry rather than a fixed margin that misses DPR-scaled caps.
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
    }, [warped.toString("base64"), unwarped.toString("base64")]);
    console.log({ changedEdgePixels, changedCenterPixels, maximumDifference });
    assert.ok(changedEdgePixels > 400 && maximumDifference >= 15, "SVG displacement must bend real backdrop pixels, not just change antialiasing");
    assert.equal(changedCenterPixels, 0, "edge refraction must leave the calm center untouched");
    await page.locator("feDisplacementMap").evaluate((node) => node.setAttribute("scale", "0.01"));
    await page.evaluate(() => document.querySelector("#optical-test-backdrop").remove());
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
    evidence.push({ label, collapsed, productivity, health, before, during, after, reducedTransparency, changedEdgePixels, changedCenterPixels, maximumDifference, frames });
    if (!remote) await context.close();
  }
  assert.deepEqual(errors, [], "no runtime errors");
  await writeFile(resolve(output, "evidence.json"), JSON.stringify(evidence, null, 2));
  console.log(`Optical dock browser checks passed: ${evidence.map((entry) => entry.label).join(", ")}. Evidence: ${output}`);
} finally {
  if (inspectedPage && !inspectedPage.isClosed()) await inspectedPage.evaluate(() => {
    document.querySelectorAll("#optical-test-backdrop").forEach((node) => node.remove());
    document.querySelector("feDisplacementMap")?.setAttribute("scale", "0.01");
  }).catch(() => {});
  await browser.close();
  if (server) await new Promise((resolve) => server.close(resolve));
}
