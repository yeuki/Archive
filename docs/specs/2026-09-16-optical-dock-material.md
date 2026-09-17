# Major change: transparent optical dock

## Control

- Status: Candidate
- Owner: Kyle / Codex
- Created: 2026-09-16
- Baseline: main `222d583`, version 0.13.0 plus accepted unreleased work
- Working branch: `codex/optical-dock-material`
- Target release: Unreleased; acceptance required before publication

## Approved direction

Replace, rather than stack onto, the old white-blurred material. Use a continuous transparent optical body, clear center, narrow optical bevel, restrained directional highlights and backdrop-responsive edge sampling. The Charles Grassi article is a conceptual technical reference, not a literal shader port. Prefer bounded CSS over dependencies or continuous GPU animation. Remove decorative caustics and scroll/movement-dependent whitening. Keep page panels below the dock throughout navigation, not just after transitions settle.

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

### Soft-edge material revision

User confirmed the page-panel overlap was fixed, but the remaining rim still read as a distinct border. Replaced the hard exclusion masks and 1px highlight strip with a joined, feathered 7px gradient mask: straight upper/lower edges plus two true semicircular half-cap regions derived from dock height. Light peaks slightly inside the silhouette and fades in both directions. Reduced continuous highlight contrast, rim tint, inset darkening and tight outer shadow; kept the full optical body, fixed blur, actual SVG displacement and page-transition fencing unchanged. No new sampler, dependency, DOM geometry or animation loop. Selection edging is quieter; semantic selection colors and behavior remain unchanged.

Computed rendering checks require a zero capsule border, zero highlight padding and two additive cap gradients rather than a punched-out ring. This revision stays Unreleased on the existing candidate branch; no version, merge, Drive archive or phone installation is authorized.

Full `npm run verify`, Capacitor sync, Android unit tests, lint and debug assembly passed. Production-browser and packaged Android/WebView checks passed at both 360 x 800 and 412 x 915, including the new computed feather assertions, geometry, navigation/transition ordering, full-body backdrop sampling, scroll consistency, touch/keyboard behavior and reduced-motion/transparency fallbacks. Controlled displacement changed 1,645/1,813 edge pixels in the browser (maximum differences 25/29) and 18,142/20,401 in actual Android compositor captures (26/29), with zero changed flat-center pixels in either environment. No idle dock animations. Evidence: `test-results/optical-dock-soft-edge-final`, `test-results/optical-dock-soft-edge-native-360` and `test-results/optical-dock-soft-edge-native-412`. Browser scrolling p95 was approximately 8ms; software-GPU emulator p95 was 100/117ms and cannot certify physical-phone performance. User visual acceptance and physical-phone checks remain pending; no phone installation or release publication occurred.

### 2026-09-17 follow-up: snapshot ordering and continuous body

User reported page panels overlapping the dock during navigation and material that read as a border only. Named page/hero snapshots paint above the ordinary root snapshot regardless of the fixed dock's DOM z-index. The correction temporarily names/fences the dock only during page transitions, then removes that backdrop root on completion or interruption. `src/motion.js` captures bounds once per transition, with token-guarded cleanup; the dock snapshot group samples the moving snapshots underneath with 3px softening clipped to those capsule bounds, outside the isolated image-pair. A CSS clip animation mirrors any remaining expansion/collapse using existing geometry tokens and the remaining live transition duration, with no frame-by-frame layout reads. Other overlay/workout layering is unchanged. Optical edge displacement remains a live/idle approximation; transition capture uses bounded backdrop softening rather than reconstructing the SVG edge field in snapshot space.

The body now has low-alpha curvature across its full surface, 3px fixed softening and soft inset thickness; the hard inset inner line is gone. The rim's fill/highlight width is reduced, not supplemented with another blur layer. No brightness, scroll-state substitution, idle work, dependency or data changes.

Production browser checks at both sizes passed with populated demo data, including mid-transition snapshot-tree inspection, dock z-index 20 versus page/hero/topbar 0, actual central-body backdrop changes in a controlled stripe test, capsule-bounded transition backdrop, Home-collapse footprint, cleanup after completion and rapid interruption, stable scroll material, reduced-motion page switching, accessibility and geometry. Controlled live displacement changed 2,238/2,454 rim/cap pixels (max channel difference 17), with zero changed flat-center pixels. Evidence: `test-results/optical-dock-body-group-browser-final`. Full automated verification and Android unit tests/lint/debug assembly passed. Physical-phone acceptance remains pending.

For packaged checks, WebView DevTools screenshots can omit the transition tree or re-rasterize SVGs, producing blank transition captures and false central-pixel differences. The optional script supports actual Android compositor captures via `ARCHIVE_WEBVIEW_ADB` (adb executable path) and `ARCHIVE_WEBVIEW_SERIAL` (explicit authorized test-device serial), alongside `ARCHIVE_WEBVIEW_CDP`. The screenshot ROI is compared in canvas; no app dependency or phone data changes are introduced. Do not interpret a blank DevTools capture as a blank app without checking the real compositor.

Packaged Android/WebView checks passed at 360 x 800 and 412 x 915 using actual compositor captures: snapshot ordering/body sampling, Home collapse, rapid interruption, geometry, scroll consistency, keyboard/touch and reduced-motion/transparency. Live edge displacement changed 22,015/24,724 rim/cap pixels, maximum differences 28/31, with zero changed flat-center pixels. Transition body sampling changed 67,077 central pixels at 360, demonstrating a real full-surface effect. No idle dock animation. Evidence: `test-results/optical-dock-body-group-native-360` and `test-results/optical-dock-body-group-native-412`. Software-GPU emulator scrolling p95 was approximately 67/100ms; these remain environment smoke checks, not proof of physical-phone smoothness. No physical phone was connected or updated; no release was published.

### 2026-09-16 original candidate evidence

`npm run verify` (including build, motion and performance) passed. Capacitor sync and `testDebugUnitTest lintDebug assembleDebug` passed with existing non-blocking native warnings. No personal phone is connected; only the existing Android emulator is used. Debug APK stays in this candidate worktree's generated build folder, not a published release.

The optional `scripts/verify-optical-dock-browser.mjs` serves the production build on a temporary loopback port. Set `ARCHIVE_PLAYWRIGHT_MODULE` to an installed Playwright `index.mjs` if it is not available through normal module resolution, then run the script. No production dependency is added. `ARCHIVE_WEBVIEW_CDP` can instead target an adb-forwarded debug WebView. Only use an emulator or explicitly authorized test device. `ARCHIVE_GLASS_FIXTURE` optionally seeds generated demo data into an isolated browser context, never the packaged app.

Ignored evidence folders: `test-results/optical-dock-final`, `test-results/optical-dock-populated-final` and `test-results/optical-dock-webview-*-final`. Browser checks cover both named phone sizes, empty and generated populated states, labels/order, equal expansions, circular caps, button containment, overflow, touch release, keyboard focus, reduced motion/transparency, and identical computed material styles before/during/after scroll (the established compact selection opacity is exempt).

Controlled stripe-backdrop pixel comparison: default displacement versus zero displacement changed 754/848 edge pixels at 360/412 respectively, maximum channel difference 30, with zero changed pixels in the flat central region (excluding circular caps). This distinguishes actual refraction from simply accepting a CSS url(). The center and rim are sibling samplers to avoid a filtered-parent backdrop root. Headless browser scroll-frame p95 varied approximately 9-21ms with no idle nav animation; these are smoke measurements, not controlled benchmarks. Filters process dock-sized buffers before masks limit visibility; keep this cost explicit.

Packaged emulator uses Android WebView `147.0.7727.111`. Interactive checks at both phone sizes reached and passed navigation/geometry, stable scrolling material, keyboard/touch and both emulated accessibility preferences. The pixel test needed geometry-based cap exclusion rather than a fixed rectangular margin. Scaled-to-CSS DevTools captures also re-rasterized foreground SVG icons in WebView, corrupting that comparison; native-DPR captures are required. Native-DPR optics-only rechecks passed at both sizes: 24,401/28,694 changed rim/cap pixels at 360/412, maximum differences 45/48, zero changed flat-center pixels and no idle nav animations. This is a rendering check, not a relaxation of production material behavior. Supplemental evidence is in `test-results/optical-dock-webview-360-native` and `test-results/optical-dock-webview-412-native`.

The emulator uses Google SwiftShader (software GLES), not a physical mobile GPU. Its broad scrolling smoke p95 was 400ms; a warmed equal-geometry comparison had medians around 100ms across SVG, CSS-only and fully disabled backdrop filters, with p95 around 150/167/167ms respectively. No meaningful SVG-specific slowdown was isolated; the environment cannot certify phone smoothness. Keep physical-phone acceptance pending rather than treating these measurements as representative. `ARCHIVE_GLASS_OPTICS_ONLY=1` isolates the native-DPR pixel and idle-frame check after interactive tests.

Pending acceptance: extended physical-phone scrolling, text-over-dark-content readability, rapid navigation and power/thermal behavior. Do not merge, assign a release version, upload APKs, or install on the user's phone before authorization.
