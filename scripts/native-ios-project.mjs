import { createHash } from 'node:crypto';
import { readFileSync, readdirSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const native = resolve(root, 'native-ios');
const id = (key) => createHash('sha256').update(`archive-native:${key}`).digest('hex').slice(0, 24).toUpperCase();
const quote = (value) => JSON.stringify(value);
function swiftFiles(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => entry.isDirectory()
    ? swiftFiles(resolve(dir, entry.name)) : entry.name.endsWith('.swift') ? [resolve(dir, entry.name)] : []);
}
const files = swiftFiles(resolve(native, 'Archive')).map((path) => relative(native, path).replaceAll('\\', '/')).sort();
const testFiles = swiftFiles(resolve(native, 'ArchiveTests')).map((path) => relative(native, path).replaceAll('\\', '/')).sort();
const objects = [];
function object(key, body) { objects.push(`\t\t${id(key)} = { ${body} };`); return id(key); }
const refs = files.map((path) => object(`ref:${path}`, `isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${quote(path)}; sourceTree = SOURCE_ROOT;`));
const sources = files.map((path) => object(`build:${path}`, `isa = PBXBuildFile; fileRef = ${id(`ref:${path}`)};`));
const assets = object('assets-ref', 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Archive/Assets.xcassets; sourceTree = SOURCE_ROOT;');
const assetsBuild = object('assets-build', `isa = PBXBuildFile; fileRef = ${assets};`);
const core = object('core-package', 'isa = XCLocalSwiftPackageReference; relativePath = ArchiveCore;');
const coreProduct = object('core-product', `isa = XCSwiftPackageProductDependency; package = ${core}; productName = ArchiveCore;`);
const coreBuild = object('core-build', `isa = PBXBuildFile; productRef = ${coreProduct};`);
const appProduct = object('app-product', 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Archive.app; sourceTree = BUILT_PRODUCTS_DIR;');
const products = object('products', `isa = PBXGroup; children = (${appProduct},); name = Products; sourceTree = "<group>";`);
const main = object('main', `isa = PBXGroup; children = (${refs.join(',')},${assets},${products},); sourceTree = "<group>";`);
const src = object('sources', `isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (${sources.join(',')},); runOnlyForDeploymentPostprocessing = 0;`);
const resources = object('resources', `isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (${assetsBuild},); runOnlyForDeploymentPostprocessing = 0;`);
const frameworks = object('frameworks', `isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (${coreBuild},); runOnlyForDeploymentPostprocessing = 0;`);
const version = readFileSync(resolve(root, 'VERSION'), 'utf8').trim();
const configurations = ['Debug', 'Release'];
for (const config of configurations) {
  object(`project:${config}`, `isa = XCBuildConfiguration; name = ${config}; buildSettings = {
    SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; CLANG_ENABLE_MODULES = YES;
    SWIFT_VERSION = 5.0; SWIFT_STRICT_CONCURRENCY = targeted; ENABLE_USER_SCRIPT_SANDBOXING = YES;
    ONLY_ACTIVE_ARCH = ${config === 'Debug' ? 'YES' : 'NO'};
    SWIFT_OPTIMIZATION_LEVEL = ${quote(config === 'Debug' ? '-Onone' : '-O')};
    SWIFT_ACTIVE_COMPILATION_CONDITIONS = ${quote(config === 'Debug' ? 'DEBUG $(inherited)' : '$(inherited)')};
    DEBUG_INFORMATION_FORMAT = ${quote(config === 'Debug' ? 'dwarf' : 'dwarf-with-dsym')};
    ${config === 'Debug' ? 'ENABLE_TESTABILITY = YES;' : ''}
  };`);
  object(`target:${config}`, `isa = XCBuildConfiguration; name = ${config}; buildSettings = {
    PRODUCT_NAME = Archive; PRODUCT_BUNDLE_IDENTIFIER = com.kyle.archive;
    INFOPLIST_FILE = Archive/Info.plist; GENERATE_INFOPLIST_FILE = NO;
    CODE_SIGN_ENTITLEMENTS = Archive/Archive.entitlements; CODE_SIGN_STYLE = Automatic;
    ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; CURRENT_PROJECT_VERSION = 1;
    MARKETING_VERSION = ${version}; TARGETED_DEVICE_FAMILY = "1,2";
    LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
    SWIFT_EMIT_LOC_STRINGS = YES; SUPPORTS_MACCATALYST = NO;
  };`);
}
const projectConfig = object('project-config', `isa = XCConfigurationList; buildConfigurations = (${configurations.map((c) => id(`project:${c}`)).join(',')},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;`);
const targetConfig = object('target-config', `isa = XCConfigurationList; buildConfigurations = (${configurations.map((c) => id(`target:${c}`)).join(',')},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;`);
const target = object('target', `isa = PBXNativeTarget; name = Archive; productName = Archive; productReference = ${appProduct}; productType = "com.apple.product-type.application"; buildConfigurationList = ${targetConfig}; buildPhases = (${src},${frameworks},${resources},); buildRules = (); dependencies = (); packageProductDependencies = (${coreProduct},);`);
const testRefs = testFiles.map((path) => object(`ref:${path}`, `isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${quote(path)}; sourceTree = SOURCE_ROOT;`));
const testBuilds = testFiles.map((path) => object(`build:${path}`, `isa = PBXBuildFile; fileRef = ${id(`ref:${path}`)};`));
const testSources = object('test-sources', `isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = (${testBuilds.join(',')},); runOnlyForDeploymentPostprocessing = 0;`);
const testPackageProduct = object('test-core-product', `isa = XCSwiftPackageProductDependency; package = ${core}; productName = ArchiveCore;`);
const testPackageBuild = object('test-core-build', `isa = PBXBuildFile; productRef = ${testPackageProduct};`);
const testFrameworks = object('test-frameworks', `isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (${testPackageBuild},); runOnlyForDeploymentPostprocessing = 0;`);
const testProduct = object('test-product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = ArchiveTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;');
const proxy = object('test-proxy', `isa = PBXContainerItemProxy; containerPortal = ${id('project')}; proxyType = 1; remoteGlobalIDString = ${target}; remoteInfo = Archive;`);
const dependency = object('test-dependency', `isa = PBXTargetDependency; target = ${target}; targetProxy = ${proxy};`);
for (const config of configurations) {
  object(`tests:${config}`, `isa = XCBuildConfiguration; name = ${config}; buildSettings = {
    PRODUCT_NAME = ArchiveTests; PRODUCT_BUNDLE_IDENTIFIER = com.kyle.archive.tests;
    GENERATE_INFOPLIST_FILE = YES; CODE_SIGN_STYLE = Automatic;
    BUNDLE_LOADER = "$(TEST_HOST)"; TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Archive.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Archive";
    TARGETED_DEVICE_FAMILY = "1,2"; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks @loader_path/Frameworks";
  };`);
}
const testConfigs = object('test-config', `isa = XCConfigurationList; buildConfigurations = (${configurations.map((c) => id(`tests:${c}`)).join(',')},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;`);
const testTarget = object('test-target', `isa = PBXNativeTarget; name = ArchiveTests; productName = ArchiveTests; productReference = ${testProduct}; productType = "com.apple.product-type.bundle.unit-test"; buildConfigurationList = ${testConfigs}; buildPhases = (${testSources},${testFrameworks},); buildRules = (); dependencies = (${dependency},); packageProductDependencies = (${testPackageProduct},);`);
objects[objects.findIndex((line) => line.startsWith(`\t\t${main} =`))] = `\t\t${main} = { isa = PBXGroup; children = (${[...refs, ...testRefs, assets, products].join(',')},); sourceTree = "<group>"; };`;
objects[objects.findIndex((line) => line.startsWith(`\t\t${products} =`))] = `\t\t${products} = { isa = PBXGroup; children = (${appProduct},${testProduct},); name = Products; sourceTree = "<group>"; };`;
const project = object('project', `isa = PBXProject; attributes = { LastUpgradeCheck = 2600; TargetAttributes = { ${target} = { CreatedOnToolsVersion = 26.0; ProvisioningStyle = Automatic; SystemCapabilities = { com.apple.HealthKit = { enabled = 1; }; }; }; ${testTarget} = { CreatedOnToolsVersion = 26.0; TestTargetID = ${target}; }; }; }; buildConfigurationList = ${projectConfig}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en,Base,); mainGroup = ${main}; productRefGroup = ${products}; projectDirPath = ""; projectRoot = ""; packageReferences = (${core},); targets = (${target},${testTarget},);`);
const pbx = `// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n${objects.join('\n')}\n\t};\n\trootObject = ${project};\n}\n`.replace(/[\t ]+$/gm, '');
const scheme = `<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.7">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${target}" BuildableName="Archive.app" BlueprintName="Archive" ReferencedContainer="container:Archive.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${testTarget}" BuildableName="ArchiveTests.xctest" BlueprintName="ArchiveTests" ReferencedContainer="container:Archive.xcodeproj"/></TestableReference></Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${target}" BuildableName="Archive.app" BlueprintName="Archive" ReferencedContainer="container:Archive.xcodeproj"/></BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="${target}" BuildableName="Archive.app" BlueprintName="Archive" ReferencedContainer="container:Archive.xcodeproj"/></BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
`;
const artifacts = new Map([
  ['Archive.xcodeproj/project.pbxproj', pbx],
  ['Archive.xcodeproj/xcshareddata/xcschemes/Archive.xcscheme', scheme],
]);
for (const [path, expected] of artifacts) {
  const destination = resolve(native, path);
  if (process.argv.includes('--write')) {
    mkdirSync(dirname(destination), { recursive: true });
    writeFileSync(destination, expected);
  } else {
    let actual;
    try { actual = readFileSync(destination, 'utf8').replaceAll('\r\n', '\n'); } catch { actual = ''; }
    if (actual !== expected) throw new Error(`${path} is missing or stale. Run npm run native:project.`);
  }
}
console.log(`Native Xcode project ${process.argv.includes('--write') ? 'generated' : 'graph verified'}: ${files.length} Swift source files; local ArchiveCore package; no CocoaPods or graphics dependencies.`);
