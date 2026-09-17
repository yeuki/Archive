# Major change: transparent optical dock

## Control

- Status: Candidate
- Owner: Kyle / Codex
- Created: 2026-09-16
- Baseline: main `222d583`, version 0.13.0 plus accepted unreleased work
- Working branch: `codex/optical-dock-material`
- Target release: Unreleased; acceptance required before publication

## Approved direction

Replace, rather than stack onto, the old white-blurred material. Use a clear center, narrow optical bevel, restrained directional highlights and backdrop-responsive edge sampling. The Charles Grassi article is a conceptual technical reference, not a literal shader port. Prefer bounded CSS over dependencies or continuous GPU animation. Remove decorative caustics and scroll/movement-dependent whitening.

## Preserve / non-goals

Keep centered Home, separate destinations and order, both expansion groups, compact-on-scroll behavior, true-width capsule and circular caps, safe areas, semantic colors, keyboard semantics and all data/native workflows. No other screen redesign, persistence migration, release, Drive upload or physical-phone installation.

## Interaction and accessibility

Touch lighting uses CSS variables and bounded animation frames, never per-frame React state. Release settles smoothly; interrupted input replaces the target. No animation while idle. Reduced motion removes tracking animation. Reduced transparency or missing backdrop/mask support produces a readable solid vessel. Existing labels, focus and touch geometry remain intact.

## Data and compatibility

No persisted fields, migration, backup, Health Connect, security or signing changes. CSS provides the center and bevel; a cached SVG red/green channel field adds actual subtle backdrop displacement inside the rim on supporting engines. This approximates edge normals rather than physically calculating lens geometry. Android WebView validation uses the existing emulator; physical-phone performance remains a separate acceptance check.

## Acceptance and verification

- [x] Calm transparent center and narrow visible edge depth; selection shares material.
- [x] Backdrop sampling stays consistent during scroll and expansion.
- [x] Navigation order/behavior and circular caps preserved at 360 x 800 and 412 x 915.
- [x] Touch release, keyboard focus, reduced motion/transparency and no overflow checked in browser.
- [x] Build, motion, performance and complete verification pass.
- [x] Packaged Android unit tests, lint and debug assembly pass.
- [x] Documentation and Unreleased notes updated; remaining device checks stated.

## References

- https://charlesgrassi.dev/blog/apple-liquid-glass/
- `docs/DESIGN_SYSTEM.md`, decisions D-013 and D-015
- `src/App.jsx` BottomNav; `src/styles.css`

## Decision log

2026-09-16: User approved material-only implementation. Supersedes the D-015 scroll-dependent backdrop suspension, not its other performance safeguards. Original dirty Garmin work remains isolated in its checkout.

2026-09-16: Controlled rendering probes demonstrated that both retained opacity animation and a named View Transition on the vessel suppress its backdrop sampling in Chromium. Removed those obsolete vessel effects, while keeping page transitions and nav control/selection motion. SVG displacement is limited to the narrow rim, approximately 1.5px horizontally on the expanded vessel; vertical displacement is smaller. No shaders, dispersion, absorption or caustics.

## Verification evidence and reproduction

`npm run verify` (including build, motion and performance) passed. Capacitor sync and `testDebugUnitTest lintDebug assembleDebug` passed with existing non-blocking native warnings. No personal phone is connected; only the existing Android emulator is used. Debug APK stays in this candidate worktree's generated build folder, not a published release.

The optional `scripts/verify-optical-dock-browser.mjs` serves the production build on a temporary loopback port. Set `ARCHIVE_PLAYWRIGHT_MODULE` to an installed Playwright `index.mjs` if it is not available through normal module resolution, then run the script. No production dependency is added. `ARCHIVE_WEBVIEW_CDP` can instead target an adb-forwarded debug WebView. Only use an emulator or explicitly authorized test device. `ARCHIVE_GLASS_FIXTURE` optionally seeds generated demo data into an isolated browser context, never the packaged app.

Ignored evidence folders: `test-results/optical-dock-final`, `test-results/optical-dock-populated-final` and `test-results/optical-dock-webview-*-final`. Browser checks cover both named phone sizes, empty and generated populated states, labels/order, equal expansions, circular caps, button containment, overflow, touch release, keyboard focus, reduced motion/transparency, and identical computed material styles before/during/after scroll (the established compact selection opacity is exempt).

Controlled stripe-backdrop pixel comparison: default displacement versus zero displacement changed 754/848 edge pixels at 360/412 respectively, maximum channel difference 30, with zero changed pixels in the flat central region (excluding circular caps). This distinguishes actual refraction from simply accepting a CSS url(). The center and rim are sibling samplers to avoid a filtered-parent backdrop root. Headless browser scroll-frame p95 varied approximately 9-21ms with no idle nav animation; these are smoke measurements, not controlled benchmarks. Filters process dock-sized buffers before masks limit visibility; keep this cost explicit.

Packaged emulator uses Android WebView `147.0.7727.111`. Interactive checks at both phone sizes reached and passed navigation/geometry, stable scrolling material, keyboard/touch and both emulated accessibility preferences. The pixel test needed geometry-based cap exclusion rather than a fixed rectangular margin. Scaled-to-CSS DevTools captures also re-rasterized foreground SVG icons in WebView, corrupting that comparison; native-DPR captures are required. Native-DPR optics-only rechecks passed at both sizes: 24,401/28,694 changed rim/cap pixels at 360/412, maximum differences 45/48, zero changed flat-center pixels and no idle nav animations. This is a rendering check, not a relaxation of production material behavior. Supplemental evidence is in `test-results/optical-dock-webview-360-native` and `test-results/optical-dock-webview-412-native`.

The emulator uses Google SwiftShader (software GLES), not a physical mobile GPU. Its broad scrolling smoke p95 was 400ms; a warmed equal-geometry comparison had medians around 100ms across SVG, CSS-only and fully disabled backdrop filters, with p95 around 150/167/167ms respectively. No meaningful SVG-specific slowdown was isolated; the environment cannot certify phone smoothness. Keep physical-phone acceptance pending rather than treating these measurements as representative. `ARCHIVE_GLASS_OPTICS_ONLY=1` isolates the native-DPR pixel and idle-frame check after interactive tests.

Pending acceptance: extended physical-phone scrolling, text-over-dark-content readability, rapid navigation and power/thermal behavior. Do not merge, assign a release version, upload APKs, or install on the user's phone before authorization.
