#!/usr/bin/env python3
"""Prepare and inspect an isolated, sandboxed DownloadScroller review copy."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import shutil
import subprocess
import uuid

ROOT = Path(__file__).resolve().parents[4]
PREFIX = "io.github.mganesh1610.DownloadScroller.Review"


def run(*args):
    return subprocess.run(args, check=True, text=True, capture_output=True).stdout.strip()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def processes(binary):
    result = []
    for line in run("ps", "-axo", "pid=,command=").splitlines():
        bits = line.strip().split(None, 1)
        if len(bits) == 2 and (bits[1] == binary or bits[1].startswith(binary + " ")):
            result.append(int(bits[0]))
    return result


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("action", choices=["prepare", "doctor", "cleanup"])
parser.add_argument("--evidence", type=Path, required=True)
args = parser.parse_args()
evidence = args.evidence.resolve()
manifest = evidence / "session.json"

if args.action == "prepare":
    if manifest.exists():
        raise SystemExit("Session exists; inspect it or choose a new evidence directory.")
    source = ROOT / "dist/DownloadScroller.app"
    if not source.exists():
        raise SystemExit("Run bash scripts/build-app.sh first.")
    evidence.mkdir(parents=True, exist_ok=True)
    scratch = evidence / "scratch"
    scratch.mkdir(exist_ok=False)
    token = uuid.uuid4().hex
    identifier = PREFIX + token
    (scratch / ".owner").write_text(token)
    bundle = scratch / "DownloadScroller Review.app"
    shutil.copytree(source, bundle)
    plist = bundle / "Contents/Info.plist"
    info = plistlib.loads(plist.read_bytes())
    info.update(CFBundleIdentifier=identifier, CFBundleName="DownloadScroller Review",
                CFBundleDisplayName="DownloadScroller Review")
    # Test documents must never launch the installed production app (or another
    # review copy), and must not take over its normal extension association.
    launcher_extension = "dsc-review-" + token
    launcher_type = identifier + ".launcher"
    info["DownloadScrollerLauncherExtension"] = launcher_extension
    for declaration in info.get("CFBundleDocumentTypes", []):
        declaration["LSItemContentTypes"] = [launcher_type]
    for declaration in info.get("UTExportedTypeDeclarations", []):
        declaration["UTTypeIdentifier"] = launcher_type
        declaration["UTTypeTagSpecification"] = {"public.filename-extension": [launcher_extension]}
    plist.write_bytes(plistlib.dumps(info))
    run("codesign", "--force", "--sign", "-", "--options", "runtime", "--entitlements",
        str(ROOT / "Config/DownloadScroller.entitlements"), str(bundle))
    run("codesign", "--verify", "--strict", str(bundle))
    fixtures = scratch / "Review Downloads"
    fixtures.mkdir()
    for number, title in enumerate(["Original", "Middle", "Recent"], 1):
        (fixtures / f"{number:02d} {title}.txt").write_text(
            f"DownloadScroller verification fixture {number}: {title}.\n")
    (scratch / "Empty Downloads").mkdir()
    binary = bundle / "Contents/MacOS/DownloadScroller"
    data = dict(token=token, bundle_id=identifier, bundle=str(bundle), binary=str(binary),
                launcher_extension=launcher_extension, launcher_type=launcher_type,
                fixtures=str(fixtures), empty=str(scratch / "Empty Downloads"),
                head=run("git", "-C", str(ROOT), "rev-parse", "HEAD"),
                source_sha256=digest(source / "Contents/MacOS/DownloadScroller"),
                review_sha256=digest(binary))
    manifest.write_text(json.dumps(data, indent=2) + "\n")
    print(json.dumps(data, indent=2))
else:
    data = json.loads(manifest.read_text())
    scratch = evidence / "scratch"
    if not data["bundle_id"].startswith(PREFIX) or (scratch / ".owner").read_text() != data["token"]:
        raise SystemExit("Session ownership check failed.")
    if Path(data["bundle"]).parent != scratch:
        raise SystemExit("Bundle is outside this session.")
    pids = processes(data["binary"])
    if args.action == "doctor":
        run("codesign", "--verify", "--strict", data["bundle"])
        actual = digest(Path(data["binary"]))
        if actual != data["review_sha256"] or len(pids) != 1:
            raise SystemExit(f"Not healthy: executable changed or expected one process, found {pids}.")
        print(json.dumps(dict(head=data["head"], bundle_id=data["bundle_id"], pid=pids[0],
                              signature="valid", executable="unchanged", fixtures=data["fixtures"]), indent=2))
    else:
        if pids:
            raise SystemExit(f"Quit this review app via Command-Q before cleanup; still running: {pids}")
        # Only the UUID bundle's own container and marked scratch tree are disposable.
        container = Path.home() / "Library/Containers" / data["bundle_id"]
        if container.exists():
            try:
                shutil.rmtree(container)
            except PermissionError:
                print(f"macOS retained protected container metadata: {container}")
        shutil.rmtree(scratch)
        (evidence / "cleanup.txt").write_text("Review process stopped; owned scratch removed. Evidence retained.\n")
        print(f"Cleaned owned scratch; evidence retained in {evidence}")
