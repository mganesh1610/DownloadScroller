#!/usr/bin/env python3
"""Generate a dependency-free native macOS Xcode project from the checked-in sources."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "DownloadScroller.xcodeproj"
PROJECT.mkdir(exist_ok=True)


def uid(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()


def q(value):
    return json.dumps(value)


sources = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "Sources").rglob("*.swift"))
resources = ["Sources/DownloadScroller/Resources/Assets.xcassets", "Sources/DownloadScroller/Resources/PrivacyInfo.xcprivacy"]
configs = ["Config/Info.plist", "Config/DownloadScroller.entitlements"]
objects = []
for path in sources + resources + configs:
    file_type = "sourcecode.swift" if path.endswith(".swift") else "folder.assetcatalog" if path.endswith(".xcassets") else "text.plist.entitlements" if path.endswith(".entitlements") else "text.xml"
    objects.append(f'{uid("ref:" + path)} = {{isa = PBXFileReference; lastKnownFileType = {file_type}; path = {q(path)}; sourceTree = SOURCE_ROOT; }};')
    if path not in configs:
        objects.append(f'{uid("build:" + path)} = {{isa = PBXBuildFile; fileRef = {uid("ref:" + path)}; }};')


def group(name, children):
    objects.append(f'{uid(name)} = {{isa = PBXGroup; children = ({", ".join(children)},); name = {q(name)}; sourceTree = "<group>"; }};')


group("Sources", [uid("ref:" + p) for p in sources])
group("Resources", [uid("ref:" + p) for p in resources])
group("Config", [uid("ref:" + p) for p in configs])
objects.append(f'{uid("app")} = {{isa = PBXFileReference; explicitFileType = wrapper.application; path = DownloadScroller.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
group("Products", [uid("app")])
group("Main", [uid(n) for n in ["Sources", "Resources", "Config", "Products"]])
for name, isa, paths in [("SourcePhase", "PBXSourcesBuildPhase", sources), ("ResourcePhase", "PBXResourcesBuildPhase", resources), ("FrameworkPhase", "PBXFrameworksBuildPhase", [])]:
    files = ", ".join(uid("build:" + p) for p in paths)
    if files:
        files += ","
    objects.append(f'{uid(name)} = {{isa = {isa}; buildActionMask = 2147483647; files = ({files}); runOnlyForDeploymentPostprocessing = 0; }};')

base = {
    "MACOSX_DEPLOYMENT_TARGET": "14.0", "SDKROOT": "macosx", "SWIFT_VERSION": "5.0",
    "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES", "GCC_C_LANGUAGE_STANDARD": "gnu17",
}
target = {
    "PRODUCT_BUNDLE_IDENTIFIER": "io.github.mganesh1610.DownloadScroller",
    "PRODUCT_NAME": "DownloadScroller", "CODE_SIGN_STYLE": "Automatic",
    "CODE_SIGN_ENTITLEMENTS": "Config/DownloadScroller.entitlements",
    "INFOPLIST_FILE": "Config/Info.plist", "GENERATE_INFOPLIST_FILE": "NO",
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "ENABLE_APP_SANDBOX": "YES",
    "ENABLE_HARDENED_RUNTIME": "YES", "COMBINE_HIDPI_IMAGES": "YES",
    "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/../Frameworks",
    "SUPPORTED_PLATFORMS": "macosx", "MARKETING_VERSION": "0.1.0", "CURRENT_PROJECT_VERSION": "1",
    "SWIFT_EMIT_LOC_STRINGS": "YES", "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
}
for owner, settings in [("Project", base), ("Target", target)]:
    for mode in ["Debug", "Release"]:
        values = dict(settings)
        if owner == "Project":
            values.update({"SWIFT_OPTIMIZATION_LEVEL": "-Onone" if mode == "Debug" else "-O",
                           "DEBUG_INFORMATION_FORMAT": "dwarf" if mode == "Debug" else "dwarf-with-dsym"})
            if mode == "Debug":
                values.update({"ENABLE_TESTABILITY": "YES", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG"})
        serialized = " ".join(f"{k} = {q(v)};" for k, v in values.items())
        objects.append(f'{uid(owner + mode)} = {{isa = XCBuildConfiguration; buildSettings = {{{serialized}}}; name = {mode}; }};')
    objects.append(f'{uid(owner + "List")} = {{isa = XCConfigurationList; buildConfigurations = ({uid(owner + "Debug")}, {uid(owner + "Release")},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};')

objects.append(f'''{uid("Target")} = {{isa = PBXNativeTarget; buildConfigurationList = {uid("TargetList")};
    buildPhases = ({uid("SourcePhase")}, {uid("FrameworkPhase")}, {uid("ResourcePhase")},);
    buildRules = (); dependencies = (); name = DownloadScroller; productName = DownloadScroller;
    productReference = {uid("app")}; productType = "com.apple.product-type.application"; }};''')
objects.append(f'''{uid("Project")} = {{isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; }};
    buildConfigurationList = {uid("ProjectList")}; compatibilityVersion = "Xcode 14.0";
    developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base,);
    mainGroup = {uid("Main")}; productRefGroup = {uid("Products")}; projectDirPath = ""; projectRoot = "";
    targets = ({uid("Target")},); }};''')
(PROJECT / "project.pbxproj").write_text("// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n" + "\n".join(objects) + f"\n}}; rootObject = {uid('Project')}; }}\n")
schemes = PROJECT / "xcshareddata/xcschemes"
schemes.mkdir(parents=True, exist_ok=True)
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid("Target")}" BuildableName="DownloadScroller.app" BlueprintName="DownloadScroller" ReferencedContainer="container:DownloadScroller.xcodeproj"/>'
(schemes / "DownloadScroller.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"/>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print("Generated DownloadScroller.xcodeproj")
