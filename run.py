#!/usr/bin/env python3
"""Fetch a varn release and run the Varn GUI suite against it."""

from __future__ import annotations

import argparse
import functools
import hashlib
import http.server
import json
import os
import platform
import re
import shutil
import socketserver
import subprocess
import sys
import tarfile
import tempfile
import threading
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


def _shaped(path: Path) -> str:
    """Answers what is wrong with how a test is written, or nothing when it is written correctly."""
    source = path.read_text()
    bodies = source.count("async.run(")

    if bodies > 1:
        return f"has {bodies} async.run bodies, and only the first of them is ever resumed"

    said = [line for line in source.splitlines() if line.lstrip().startswith('print("gui.')]

    if not said:
        return "never says it finished, which is the only sign its body ran to the end"

    if bodies == 1 and said[-1] == said[-1].lstrip():
        return "says it finished outside its asynchronous body, so nothing awaited in it is checked"

    return ""


def _why(stderr: str) -> str:
    """Answers what a test said when it failed, out of the engine's own log line."""
    for line in stderr.splitlines():
        if "[error]" not in line:
            continue

        said = line.split("] ")[-1].strip()
        return said[:200]

    return ""


def test(args: argparse.Namespace) -> None:
    engine = _engine(args)
    suite = sorted(ROOT.glob("gui/tests/*_test.lua"))

    if args.filter:
        suite = [path for path in suite if args.filter in path.name]

    if not suite:
        raise SystemExit("no tests matched")

    failed = {}
    for path in suite:
        reason = _shaped(path)
        if reason:
            print(f"{path.name}: {reason}")
            failed[path.name] = reason
            continue

        scratch = tempfile.mkdtemp(prefix="varn-gui-")
        environment = dict(os.environ, VARN_TEST_DIR=scratch)
        result = subprocess.run(
            [str(engine), str(path.relative_to(ROOT))],
            cwd=ROOT,
            env=environment,
            capture_output=True,
            text=True,
        )
        shutil.rmtree(scratch, ignore_errors=True)

        sys.stdout.write(result.stdout)
        sys.stderr.write(result.stderr)

        # A test says when it has finished. Anything after an await runs once the chunk has ended, so a
        # body that dies there leaves the engine exiting cleanly and the test looking as if it passed.
        if result.returncode != 0 or " ok" not in result.stdout:
            failed[path.name] = _why(result.stderr) or "said nothing about why"

    print()
    print(f"{len(suite) - len(failed)} passed, {len(failed)} failed")

    # What failed scrolls past thirty other files, so the reason is said again at the end rather than
    # left to be found.
    if failed:
        for name, reason in failed.items():
            print(f"failed: {name}: {reason}")

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

    carried = [path for path in sorted((ROOT / "gui").rglob("*.lua")) if "/tests/" not in path.as_posix()]
    carried += sorted((ROOT / "gui" / "assets" / "fonts").glob("*.ttf"))

    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in carried:
            archive.write(path, path.relative_to(ROOT).as_posix())

    print(f"packed {output.relative_to(ROOT)}")
    return output


def sample(args: argparse.Namespace) -> None:
    args.source = str(ROOT / "sample")
    args.output = str(ROOT / "sample" / "dist" / "gallery.vap")
    pack(args)
    framework(ROOT / "sample" / "dist" / "framework.zip")


def _icon(source: Path) -> str:
    """Answers the picture an application names as its icon, which is what the page shows in its tab."""
    manifest = (source / "manifest.lua").read_text()
    named = re.search(r"""icon\s*=\s*["']([^"']+)["']""", manifest)

    if named is None:
        raise SystemExit(f"{source}/manifest.lua names no icon, which the page needs for its tab")

    return named.group(1)


def _stamped(name: str, content: bytes) -> str:
    """Answers the name a file is served under, which carries the hash of what it holds."""
    stem, _, extension = name.rpartition(".")
    return f"{stem}.{hashlib.sha256(content).hexdigest()[:12]}.{extension}"


def _written(into: Path, name: str, content: bytes, stamped: dict[str, str]) -> str:
    """Writes one file under its stamped name, and remembers the name it was written under."""
    served = _stamped(name, content)
    (into / served).write_bytes(content)
    stamped[name] = served
    return served


def _rewritten(text: str, stamped: dict[str, str]) -> bytes:
    """Answers a source with every name it loads replaced by the name that name is served under."""
    for name, served in stamped.items():
        text = text.replace(f'"./{name}"', f'"./{served}"')

    return text.encode()


def _ordered(entry: Path) -> list[Path]:
    """Answers a module and everything it imports, each one after what it imports."""
    order = []
    seen = set()

    def walk(source: Path) -> None:
        if source in seen:
            return

        seen.add(source)

        for name in re.findall(r'from "\./([\w.-]+)"', source.read_text()):
            walk(source.parent / name)

        order.append(source)

    walk(entry)
    return order


def web(args: argparse.Namespace) -> None:
    """Assembles the page into a folder a static host serves as it stands, every file named by its hash.

    A browser keeps what it has already fetched, so a deploy that reuses a name is a reader running half
    the new files and half the old until they think to reload the hard way. A name that carries the hash
    of what it holds cannot be stale: it is either what the page asks for or it is a file nobody asks
    for. The page itself is the one name that never changes, and it is the one thing never cached."""

    target = ROOT / "apps" / "web" / "dist"
    source = ROOT / "apps" / "web"

    sample(args)

    if target.exists():
        shutil.rmtree(target)

    target.mkdir(parents=True)
    stamped: dict[str, str] = {}

    for name, path in (
        ("gallery.vap", ROOT / "sample" / "dist" / "gallery.vap"),
        ("framework.zip", ROOT / "sample" / "dist" / "framework.zip"),
        ("favicon.png", ROOT / "sample" / "assets" / _icon(ROOT / "sample")),
    ):
        _written(target, name, path.read_bytes(), stamped)

    engine = source / "varn_wasm.wasm"

    if not engine.exists():
        raise SystemExit("the engine is missing: run `python3 run.py fetch-native --platform web`")

    _written(target, "varn_wasm.wasm", engine.read_bytes(), stamped)
    _written(target, "varn_wasm.js", (source / "varn_wasm.js").read_bytes(), stamped)

    # The renderer is written beside its own sources and read by the page, which is served from this
    # folder and can reach nothing above it. Each module is written after what it imports, so the names
    # it imports are already the names they are served under.
    for module in _ordered(ROOT / "renderers" / "web" / "host.js"):
        _written(target, module.name, _rewritten(module.read_text(), stamped), stamped)

    _written(target, "main.js", _rewritten((source / "main.js").read_text(), stamped), stamped)

    # The page names what it loads and nothing names the page, so it is the one file a host must not let
    # a browser keep.
    (target / "index.html").write_bytes(_rewritten((source / "index.html").read_text(), stamped))

    # The engine's own loader is a vendored bundle full of strings that read like paths and are not, and
    # it finds its wasm through `locateFile` rather than by loading a name, so what is asked here is what
    # the page itself loads.
    ours = [target / "index.html"] + [target / stamped[name] for name in stamped if name.endswith(".js")]
    missing = _unreachable(target, [path for path in ours if path.name != stamped["varn_wasm.js"]])

    if missing:
        raise SystemExit("the page loads what it does not carry: " + ", ".join(sorted(missing)))

    print(f"assembled {target.relative_to(ROOT)}: {len(stamped) + 1} files, each named by its own hash")


def _unreachable(page: Path, sources: list[Path]) -> set[str]:
    """Answers everything the given files load from outside the folder a host serves the page as.

    Existing on this disk is not the question: a browser is given this folder and nothing above it, so a
    name that climbs out of it answers 404 however plainly the file sits there."""
    missing = set()
    root = page.resolve()

    for source in sources:
        for name in re.findall(r'"(\.\.?/[^"]+)"', source.read_text()):
            resolved = (source.parent / name).resolve()

            if not resolved.exists() or root not in resolved.parents:
                missing.add(f"{source.name} loads {name}")

    return missing


def _server(port: int) -> socketserver.ThreadingTCPServer:
    """Answers a server for the assembled page, since a browser needs one for its modules and its wasm.

    A port of nought is one the system chooses, which is what something driving a browser of its own asks
    for rather than taking a port a person may already be serving on."""
    root = ROOT / "apps" / "web" / "dist"

    handler = functools.partial(_Page, directory=str(root))
    socketserver.ThreadingTCPServer.allow_reuse_address = True

    return socketserver.ThreadingTCPServer(("", port), handler)


def serve(args: argparse.Namespace) -> None:
    """Serves the assembled page, which is how a browser opens it."""

    # The page is assembled again here rather than served as it was left: a reload after a change in Lua
    # would otherwise show what was packed before it.
    web(args)

    with _server(args.port) as server:
        print(f"the gallery is at http://localhost:{server.server_address[1]}", flush=True)

        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print()


class _Page(http.server.SimpleHTTPRequestHandler):
    """Answers for the page the way a host in front of it should, and without a line per request.

    Every file but the page itself carries the hash of what it holds, so it is safe to keep for good and
    a deploy can never be half of one build and half of another. The page names them and nothing names
    the page, so the page is the one file a browser must ask about every time."""

    def do_GET(self) -> None:
        """Answers the page for an address that names no file, which is what a router's address is.

        A reader who follows a link and then reloads is asking a static host for a path no file sits at,
        and a host that answers 404 there is one where every deep link is broken on arrival."""
        wanted = Path(self.translate_path(self.path))

        if not wanted.exists() and "." not in wanted.name:
            self.path = "/index.html"

        super().do_GET()

    def end_headers(self) -> None:
        stamped = re.search(r"\.[0-9a-f]{12}\.", self.path) is not None

        self.send_header(
            "Cache-Control",
            "public, max-age=31536000, immutable" if stamped else "no-store",
        )

        super().end_headers()

    def log_message(self, format: str, *arguments: object) -> None:
        pass


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


def reference(args: argparse.Namespace) -> None:
    """Writes the component table in docs/components.md from the declarations themselves.

    The table is generated rather than written, so a component cannot document a prop it does not
    accept. Doing it by hand is how one row was right and the next was a guess."""
    engine = _engine(args)
    page = ROOT / "docs" / "components.md"

    built = subprocess.run(
        [str(engine), "gui/tools/reference.lua"],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )

    if built.returncode != 0:
        sys.stderr.write(built.stderr)
        raise SystemExit("the reference could not be generated")

    opens = "## Every component\n\n"
    closes = "\n## What is not in the table"
    written = page.read_text()

    head = written.index(opens) + len(opens)
    tail = written.index(closes)

    page.write_text(written[:head] + built.stdout.strip() + "\n" + written[tail:])
    print(f"wrote {page.relative_to(ROOT)}")


def doctor(args: argparse.Namespace) -> None:
    engine = _engine(args)
    result = subprocess.run(
        [str(engine), "gui/tools/doctor.lua", str(Path(args.archive).resolve())],
        cwd=ROOT,
    )
    sys.exit(result.returncode)


def _demos(engine: Path) -> list[tuple[str, str, list[str]]]:
    """Answers every demo the gallery carries, the title its row is drawn under, and its walk.

    The gallery is asked rather than a list kept here, so a demo added to the catalogue is looked at
    without anything in this file being told about it. A walk is what to press to reach the screens
    inside a whole application, which is empty for a demo that is one screen."""
    listing = subprocess.run(
        [str(engine), "sample/list-demos.lua"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )

    found = [line.split("\t") for line in listing.stdout.split("\n") if "\t" in line]
    walks = []

    for row in found:
        screens = [step.split("=", 1) for step in row[2:]]
        walks.append((row[0], row[1], [{"as": name, "press": label} for name, label in screens]))

    return walks


def _simulator(device: str) -> str:
    """Answers the simulator to work with, since xcodebuild names one by id where simctl takes `booted`."""

    if device != "booted":
        return device

    listing = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "booted", "--json"],
        capture_output=True, text=True, check=True,
    )

    for runtime, entries in json.loads(listing.stdout)["devices"].items():
        for entry in entries:
            if "iOS" in runtime:
                return entry["udid"]

    raise SystemExit("no simulator is booted: open one, or name it with --device")


def _capture(device: str, target: Path, settle: float, patience: float) -> None:
    """Writes a shot once the screen has stopped changing, rather than after a fixed wait.

    A screen that fetches something is not finished when its tree is: a map draws its tiles, a web view
    loads its page and a picture arrives from somewhere else, all of them after the first frame. A shot
    taken before they land is a blank screen this tool exists to find rather than one it made."""
    previous = None
    waited = 0.0

    while True:
        time.sleep(settle)
        waited += settle

        subprocess.run(["xcrun", "simctl", "io", device, "screenshot", str(target)], check=True,
                       stderr=subprocess.DEVNULL)

        current = target.read_bytes()

        if current == previous or waited >= patience:
            return

        previous = current


def _appearances(args: argparse.Namespace) -> list[str]:
    """Answers which appearances are wanted, which is both of them unless one was named."""
    if args.appearance == "all":
        return ["light", "dark"]

    return [args.appearance]


def shots(args: argparse.Namespace) -> None:
    """Take one screenshot per screen, so what a platform draws is looked at rather than argued about."""
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)

    if args.platform in ("ios", "all"):
        _ios_shots(args, output)

    if args.platform in ("web", "all"):
        _web_shots(args, output)


def _web_shots(args: argparse.Namespace, output: Path) -> None:
    """Walks the gallery in a headless browser, opening each screen the way a reader opens it."""
    web(args)

    demos = [
        {"name": name, "title": title, "screens": screens}
        for name, title, screens in _demos(_engine(args))
        if args.only in name.replace("/", "-")
    ]

    print("> the browser is walking the gallery")

    with _server(0) as server:
        threading.Thread(target=server.serve_forever, daemon=True).start()

        wanted = {
            "url": f"http://127.0.0.1:{server.server_address[1]}/",
            "output": str(output),
            "demos": demos,
            "appearances": _appearances(args),
        }

        try:
            subprocess.run(
                ["node", str(ROOT / "renderers" / "web" / "tools" / "shots.mjs"), json.dumps(wanted)],
                cwd=ROOT,
                check=True,
            )
        finally:
            server.shutdown()


def _ios_shots(args: argparse.Namespace, output: Path) -> None:
    """Launches the gallery once per screen on the simulator, since the application reads which to open."""
    device = _simulator(args.device)
    bundle = "dev.varn.gui"

    sample(args)

    # Every screen the gallery is judged by, and the environment the sample reads to open it.
    shot_list = [("index", {})]
    for name, _, _walk in _demos(_engine(args)):
        wanted = {"VARN_GUI_DEMO": name}

        if name == "screens/network":
            wanted["VARN_GUI_DEMO_FETCH"] = "1"

        shot_list.append((name.replace("/", "-"), wanted))

    shot_list = [entry for entry in shot_list if args.only in entry[0]]

    if not shot_list:
        raise SystemExit(f"no screen matched {args.only}")

    project = ROOT / "apps" / "ios"
    subprocess.run(["xcodegen", "generate", "--quiet"], cwd=project, check=True)

    derived = ROOT / ".build" / "ios"
    subprocess.run(
        [
            "xcodebuild", "-project", "VarnGUI.xcodeproj", "-scheme", "VarnGUI",
            "-configuration", "Debug", "-destination", f"platform=iOS Simulator,id={device}",
            "-derivedDataPath", str(derived), "build",
        ],
        cwd=project,
        check=True,
        stdout=subprocess.DEVNULL,
    )

    app = derived / "Build" / "Products" / "Debug-iphonesimulator" / "VarnGUI.app"
    subprocess.run(["xcrun", "simctl", "boot", device], check=False)
    subprocess.run(["xcrun", "simctl", "install", device, str(app)], check=True)

    # A screen that asks for a device puts a system alert over whatever is on the simulator, and nobody
    # is here to answer it: it stays up across the relaunch and is in the picture of every screen after.
    for wanted in ("camera", "microphone", "location"):
        subprocess.run(["xcrun", "simctl", "privacy", device, "grant", wanted, bundle], check=False,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    for appearance in _appearances(args):
        subprocess.run(["xcrun", "simctl", "ui", device, "appearance", appearance], check=True)

        for name, wanted in shot_list:
            subprocess.run(["xcrun", "simctl", "terminate", device, bundle], check=False,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            environment = dict(os.environ)
            for key, value in wanted.items():
                environment[f"SIMCTL_CHILD_{key}"] = value

            subprocess.run(["xcrun", "simctl", "launch", device, bundle], check=True,
                           env=environment, stdout=subprocess.DEVNULL)

            target = output / f"ios-{appearance}-{name}.png"
            _capture(device, target, args.settle, args.patience)
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

    server = tasks.add_parser("serve", help="assemble the page and serve it, which is how a browser opens it")
    server.add_argument("--port", type=int, default=8000, help="the port to answer on")
    server.set_defaults(run=serve)

    native = tasks.add_parser("fetch-native", help="download the framework and archive the apps link against")
    native.add_argument("--platform", choices=["all", "ios", "android", "web"], default="all")
    native.set_defaults(run=fetch_native)

    shooter = tasks.add_parser("shots", help="screenshot every gallery screen on a platform")
    shooter.add_argument("--platform", choices=["all", "ios", "web"], default="all")
    shooter.add_argument("--device", default="booted", help="the simulator udid, or booted")
    shooter.add_argument("--output", default="docs/screenshots", help="where the images are written")
    shooter.add_argument("--only", default="", help="capture only the screens whose name carries this")
    shooter.add_argument("--appearance", choices=["all", "light", "dark"], default="all")
    shooter.add_argument("--settle", type=float, default=1.5, help="seconds between looks at a screen")
    shooter.add_argument("--patience", type=float, default=15.0,
                         help="seconds to keep waiting for a screen that is still changing")
    shooter.set_defaults(run=shots)

    tasks.add_parser("reference", help="write the component table from the declarations").set_defaults(
        run=reference
    )

    checker = tasks.add_parser("doctor", help="validate an application archive")
    checker.add_argument("archive")
    checker.set_defaults(run=doctor)

    args = parser.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
