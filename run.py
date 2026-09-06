#!/usr/bin/env python3
"""Fetch a varn release and run the Varn GUI suite against it."""

from __future__ import annotations

import argparse
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CACHE = ROOT / ".varn"
LATEST = "https://github.com/varn-org/varn/releases/latest/download"
TAGGED = "https://github.com/varn-org/varn/releases/download/{version}"


def _asset() -> str:
    system = platform.system()
    machine = platform.machine().lower()

    if system == "Darwin":
        return "varn-macos-arm64.tar.gz" if machine in ("arm64", "aarch64") else "varn-macos-x86_64.tar.gz"
    if system == "Linux":
        return "varn-linux-x86_64.tar.gz"
    if system == "Windows":
        return "varn-windows-x86_64.zip"

    raise SystemExit(f"no released engine for {system} {machine}")


def _download(version: str) -> Path:
    target = CACHE / version
    binary = target / ("varn.exe" if platform.system() == "Windows" else "varn")
    if binary.exists():
        return binary

    base = LATEST if version == "latest" else TAGGED.format(version=version)
    url = f"{base}/{_asset()}"
    print(f"> fetching {url}")

    target.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(delete=False, suffix=Path(_asset()).suffix) as handle:
        archive = Path(handle.name)

    try:
        urllib.request.urlretrieve(url, archive)
        if archive.suffix == ".zip":
            with zipfile.ZipFile(archive) as bundle:
                bundle.extractall(target)
        else:
            with tarfile.open(archive) as bundle:
                bundle.extractall(target)
    finally:
        archive.unlink(missing_ok=True)

    found = next((path for path in target.rglob(binary.name) if path.is_file()), None)
    if found is None:
        raise SystemExit(f"the archive carried no {binary.name}")

    if found != binary:
        shutil.move(str(found), binary)

    binary.chmod(0o755)
    return binary


def _engine(args: argparse.Namespace) -> Path:
    if args.engine:
        return Path(args.engine).resolve()

    return _download(args.version)


def test(args: argparse.Namespace) -> None:
    engine = _engine(args)
    suite = sorted(ROOT.glob("gui/tests/*_test.lua"))

    if args.filter:
        suite = [path for path in suite if args.filter in path.name]

    if not suite:
        raise SystemExit("no tests matched")

    failed = []
    for path in suite:
        scratch = tempfile.mkdtemp(prefix="varn-gui-")
        environment = dict(os.environ, VARN_TEST_DIR=scratch)
        result = subprocess.run([str(engine), str(path.relative_to(ROOT))], cwd=ROOT, env=environment)
        shutil.rmtree(scratch, ignore_errors=True)

        if result.returncode != 0:
            failed.append(path.name)

    print()
    print(f"{len(suite) - len(failed)} passed, {len(failed)} failed")
    if failed:
        print("failed: " + ", ".join(failed))
        sys.exit(1)


def pack(args: argparse.Namespace) -> None:
    source = Path(args.source).resolve()
    output = Path(args.output).resolve()

    if not (source / "manifest.lua").exists():
        raise SystemExit(f"{source} carries no manifest.lua")

    output.parent.mkdir(parents=True, exist_ok=True)

    # A project's own output is not part of it, or an archive ends up carrying the last one.
    def carried(path: Path) -> bool:
        relative = path.relative_to(source)
        return (
            path.is_file()
            and ".DS_Store" not in path.name
            and relative.parts[0] != "dist"
            and path != output
        )

    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(source.rglob("*")):
            if carried(path):
                archive.write(path, path.relative_to(source).as_posix())

    print(f"packed {output} from {source}")


def framework(output: Path) -> Path:
    """Packs the framework itself, which a host that shares no filesystem with the engine has to carry."""

    output.parent.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted((ROOT / "gui").rglob("*.lua")):
            if "/tests/" not in path.as_posix():
                archive.write(path, path.relative_to(ROOT).as_posix())

    print(f"packed {output.relative_to(ROOT)}")
    return output


def sample(args: argparse.Namespace) -> None:
    args.source = str(ROOT / "sample")
    args.output = str(ROOT / "sample" / "dist" / "gallery.vap")
    pack(args)
    framework(ROOT / "sample" / "dist" / "framework.zip")


def web(args: argparse.Namespace) -> None:
    """Assembles what the page loads: the framework, the gallery, and the engine beside them."""

    target = ROOT / "apps" / "web"
    sample(args)

    for name in ("gallery.vap", "framework.zip"):
        shutil.copyfile(ROOT / "sample" / "dist" / name, target / name)
        print(f"copied {(target / name).relative_to(ROOT)}")

    if not (target / "varn_wasm.wasm").exists():
        print("the engine is missing: run `python3 run.py fetch-native --platform web`")


NATIVE = {
    "ios": ("varn-apple-xcframework.tar.gz", ROOT / "apps" / "ios" / "Frameworks", "*.xcframework", None),
    "android": ("varn-android-aar.tar.gz", ROOT / "apps" / "android" / "app" / "libs", "*.aar", "varn.aar"),
    "web": ("varn-wasm.tar.gz", ROOT / "apps" / "web", "varn_wasm.*", None),
}


def fetch_native(args: argparse.Namespace) -> None:
    """Downloads the engine each sample application links against, into the place that application reads."""

    wanted = NATIVE.keys() if args.platform == "all" else [args.platform]
    base = LATEST if args.version == "latest" else TAGGED.format(version=args.version)

    for name in wanted:
        asset, target, pattern, rename = NATIVE[name]
        url = f"{base}/{asset}"
        target.mkdir(parents=True, exist_ok=True)
        print(f"> fetching {url}")

        with tempfile.NamedTemporaryFile(delete=False, suffix=".tar.gz") as handle:
            download = Path(handle.name)

        staging = Path(tempfile.mkdtemp(prefix="varn-native-"))

        try:
            urllib.request.urlretrieve(url, download)
            with tarfile.open(download) as bundle:
                bundle.extractall(staging)

            found = sorted(staging.rglob(pattern))
            if not found:
                raise SystemExit(f"{asset} carried nothing matching {pattern}")

            for path in found:
                destination = target / (rename or path.name)

                if destination.exists():
                    shutil.rmtree(destination) if destination.is_dir() else destination.unlink()

                shutil.move(str(path), destination)
                print(f"  {destination.relative_to(ROOT)}")
        finally:
            download.unlink(missing_ok=True)
            shutil.rmtree(staging, ignore_errors=True)


def doctor(args: argparse.Namespace) -> None:
    engine = _engine(args)
    result = subprocess.run(
        [str(engine), "gui/tools/doctor.lua", str(Path(args.archive).resolve())],
        cwd=ROOT,
    )
    sys.exit(result.returncode)


# Each screen the gallery is judged by, and the environment the sample reads to open it.
DEMOS = [
    "inputs/fields", "inputs/toggles", "inputs/sliders", "inputs/pickers", "inputs/buttons",
    "content/text", "content/images", "content/media",
    "drawing/canvas",
    "lists/list", "lists/sections", "lists/grid", "lists/carousel", "lists/long", "lists/table",
    "layout/flow", "layout/placing", "layout/avoiding", "layout/scrolling",
    "feedback/progress", "feedback/labels",
    "presentation/dialogs", "presentation/menus", "presentation/grouping",
    "screens/form",
]

# Every screen the gallery is judged by, and the environment the sample reads to open it.
SHOTS = [("index", {})] + [(name.replace("/", "-"), {"VARN_GUI_DEMO": name}) for name in DEMOS] + [
    ("screens-network", {"VARN_GUI_DEMO": "screens/network", "VARN_GUI_DEMO_FETCH": "1"}),
]


def shots(args: argparse.Namespace) -> None:
    """Take one screenshot per screen on the iOS simulator, so the chrome is looked at rather than argued about."""
    device = args.device
    bundle = "dev.varn.gui.gallery"
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)

    sample(args)

    project = ROOT / "apps" / "ios"
    subprocess.run(["xcodegen", "generate", "--quiet"], cwd=project, check=True)

    derived = ROOT / ".build" / "ios"
    subprocess.run(
        [
            "xcodebuild", "-project", "VarnGUIGallery.xcodeproj", "-scheme", "VarnGUIGallery",
            "-configuration", "Debug", "-destination", f"platform=iOS Simulator,id={device}",
            "-derivedDataPath", str(derived), "build",
        ],
        cwd=project,
        check=True,
        stdout=subprocess.DEVNULL,
    )

    app = derived / "Build" / "Products" / "Debug-iphonesimulator" / "VarnGUIGallery.app"
    subprocess.run(["xcrun", "simctl", "boot", device], check=False)
    subprocess.run(["xcrun", "simctl", "install", device, str(app)], check=True)

    for appearance in ("light", "dark"):
        subprocess.run(["xcrun", "simctl", "ui", device, "appearance", appearance], check=True)

        for name, wanted in SHOTS:
            subprocess.run(["xcrun", "simctl", "terminate", device, bundle], check=False,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            environment = dict(os.environ)
            for key, value in wanted.items():
                environment[f"SIMCTL_CHILD_{key}"] = value

            subprocess.run(["xcrun", "simctl", "launch", device, bundle], check=True,
                           env=environment, stdout=subprocess.DEVNULL)
            time.sleep(args.settle)

            target = output / f"ios-{appearance}-{name}.png"
            subprocess.run(["xcrun", "simctl", "io", device, "screenshot", str(target)], check=True,
                           stderr=subprocess.DEVNULL)
            print(f"  {target}")

    subprocess.run(["xcrun", "simctl", "terminate", device, bundle], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main() -> None:
    parser = argparse.ArgumentParser(prog="run.py", description=__doc__)
    parser.add_argument("--version", default="latest", help="the engine release to run against")
    parser.add_argument("--engine", help="a varn binary to use instead of a released one")

    tasks = parser.add_subparsers(dest="task", metavar="task", required=True)

    runner = tasks.add_parser("test", help="run the Lua suite")
    runner.add_argument("--filter", help="only run tests whose name contains this")
    runner.set_defaults(run=test)

    packer = tasks.add_parser("pack", help="build an application archive")
    packer.add_argument("source")
    packer.add_argument("output")
    packer.set_defaults(run=pack)

    tasks.add_parser("sample", help="pack the sample application").set_defaults(run=sample)

    tasks.add_parser("web", help="assemble the framework, the gallery and the engine for the page").set_defaults(run=web)

    native = tasks.add_parser("fetch-native", help="download the framework and archive the apps link against")
    native.add_argument("--platform", choices=["all", "ios", "android", "web"], default="all")
    native.set_defaults(run=fetch_native)

    shooter = tasks.add_parser("shots", help="screenshot every gallery screen on the iOS simulator")
    shooter.add_argument("--device", default="booted", help="the simulator udid, or booted")
    shooter.add_argument("--output", default="docs/screenshots", help="where the images are written")
    shooter.add_argument("--settle", type=float, default=1.5, help="seconds to let a screen settle")
    shooter.set_defaults(run=shots)

    checker = tasks.add_parser("doctor", help="validate an application archive")
    checker.add_argument("archive")
    checker.set_defaults(run=doctor)

    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
