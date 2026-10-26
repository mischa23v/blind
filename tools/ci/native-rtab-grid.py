#!/usr/bin/env python3
"""One manual, hosted, unsigned RTAB-Map device-compile experiment.

No dependency source fallback, OS installation, simulator run, device install, signing,
archive/export or binary artifact. The existing reviewed prepare-rtabmap.mjs owns the
native overlay. This adapter only assembles pinned inputs in an ephemeral directory.
Passing means compilation, not localization/navigation accuracy or license clearance.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import re
import shutil
import signal
import stat
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import zipfile

GIB = 1024 ** 3
UPSTREAM = "a4e7f13522722878dea3f07e8fd082291e72eb49"
UPSTREAM_URL = "https://github.com/introlab/rtabmap.git"
ASSET_URL = "https://github.com/introlab/rtabmap/releases/download/0.23.1/libraries-ios-xcode26.5.zip"
ASSET_BYTES = 234342396
ASSET_SHA = "ec84a34adacb09a851e14dff4f351114f92aca261ad36df8906b8c2945a28747"
INSTALL_SHA = "7b6bd18c9240183a4fc873fedefee9c0a8d89c8da9f7e91218c1d2d2fd217aa1"
DEVELOPER = "/Applications/Xcode_27.0.app/Contents/Developer"
MAX_WORK = 8 * GIB
MAX_ZIP = 4 * GIB
MAX_ENTRIES = 100000
MAX_SECONDS = 40 * 60
MAX_LOG = 64 * 1024 ** 2
PINNED_PACKAGES = {
    "zip": ("https://github.com/marmelroy/Zip", "2.1.1", "bd19d974e8a38cc8d3a88c90c8a107386c3b8ccf"),
    "grdb.swift": ("https://github.com/groue/GRDB.swift", "7.11.1", "b83108d10f42680d78f23fe4d4d80fc88dab3212"),
}
SENTINELS = ("include/boost", "include/eigen3", "include/lz4.h", "include/flann",
             "include/gtsam", "include/suitesparse/SuiteSparse_config.h", "include/g2o",
             "lib/vtk.framework", "include/pcl-1.15", "include/opencv4", "include/laszip", "include/liblas")
OVERLAY_PATHS = {"app/android/jni/RTABMapApp.h", "app/android/jni/RTABMapApp.cpp",
                 "app/ios/RTABMapApp/NativeWrapper.hpp", "app/ios/RTABMapApp/NativeWrapper.cpp",
                 "app/ios/RTABMapApp/RTABMap.swift"}


def require(condition, reason):
    if not condition:
        raise RuntimeError(reason)


def sha(path):
    with open(path, "rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def json_write(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def safe_relative(name):
    require(name and "\\" not in name and not name.startswith("/"), "unsafe archive path")
    parts = name.rstrip("/").split("/")
    require(all(p not in ("", ".", "..") and ":" not in p for p in parts), "unsafe archive component")
    return PurePosixPath(*parts)


def zip_manifest(archive):
    """Validate all names/links before writing; no symlink-parent extraction allowed."""
    infos = archive.infolist()
    require(0 < len(infos) <= MAX_ENTRIES, "archive entry cap")
    require(sum(i.file_size for i in infos) <= MAX_ZIP, "archive expanded-byte cap")
    raw = [(i, safe_relative(i.filename)) for i in infos]
    wrapped = all(p.parts[0] == "Libraries" for _, p in raw)
    entries, seen = [], set()
    for item, rawpath in raw:
        require(not item.flag_bits & 1, "encrypted archive entry")
        path = PurePosixPath(*rawpath.parts[1:]) if wrapped else rawpath
        if path == PurePosixPath("."):
            require(item.is_dir(), "invalid Libraries wrapper")
            continue
        require(path.parts[0] in {"include", "lib", "share", "bin", "licenses", "LICENSE", "LICENSE.txt"}, "unknown archive root")
        key = str(path).casefold()
        require(key not in seen, "duplicate/case-colliding archive path")
        seen.add(key)
        mode = item.external_attr >> 16
        kind = stat.S_IFMT(mode)
        require(kind in (0, stat.S_IFREG, stat.S_IFDIR, stat.S_IFLNK), "unsupported archive entry type")
        link = None
        if stat.S_ISLNK(mode):
            require(item.file_size <= 4096, "oversized symlink")
            link = archive.read(item).decode("utf-8", errors="strict")
            require(link and not link.startswith("/") and "\\" not in link and "\0" not in link, "unsafe symlink target")
            resolved = list(path.parent.parts)
            for part in link.split("/"):
                if part == "..":
                    require(resolved, "escaping symlink")
                    resolved.pop()
                elif part not in ("", "."):
                    require(":" not in part, "unsafe symlink component")
                    resolved.append(part)
            require(resolved and resolved[0] == path.parts[0], "symlink leaves archive section")
        entries.append((item, path, link))
    links = {str(p).casefold() for _, p, link in entries if link is not None}
    for _, path, _ in entries:
        require(not any(str(p).casefold() in links for p in path.parents), "archive writes through symlink parent")
    require(any(p.parts[0] == "include" for _, p, _ in entries) and any(p.parts[0] == "lib" for _, p, _ in entries), "missing include/lib archive roots")
    return entries


def extract_archive(source, destination, check):
    require(not destination.exists(), "Libraries destination already exists")
    with zipfile.ZipFile(source) as archive:
        entries = zip_manifest(archive)
        destination.mkdir(parents=True)
        for item, relative, link in entries:
            if link is not None:
                continue
            target = destination.joinpath(*relative.parts)
            if item.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(item) as inp, open(target, "xb") as out:
                count = 0
                while chunk := inp.read(1024 ** 2):
                    count += len(chunk)
                    require(count <= item.file_size, "entry expanded beyond declaration")
                    out.write(chunk)
                    check()
                require(count == item.file_size, "entry size mismatch")
            target.chmod(0o755 if (item.external_attr >> 16) & 0o111 else 0o644)
        for _, relative, link in entries:
            if link is not None:
                target = destination.joinpath(*relative.parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.symlink_to(link)
        # Check resolved chains too (including cycles/dangling links), not just lexical targets.
        for _, relative, link in entries:
            if link is not None:
                resolved = destination.joinpath(*relative.parts).resolve(strict=True)
                require(resolved.is_relative_to(destination.resolve()), "resolved symlink escaped")
        return {"entries": len(entries), "expandedBytes": sum(i.file_size for i, _, _ in entries),
                "symlinks": sum(link is not None for _, _, link in entries)}


def verify_packages(document, expected=PINNED_PACKAGES):
    pins = document.get("pins", document.get("object", {}).get("pins", []))
    actual = {}
    for pin in pins:
        location = pin.get("location", pin.get("repositoryURL", "")).removesuffix(".git").rstrip("/")
        identity = location.rsplit("/", 1)[-1].lower()
        state = pin.get("state", {})
        require(identity not in actual, "duplicate package pin")
        actual[identity] = (location, state.get("version"), state.get("revision"))
    require(actual == expected, "Swift package pin drift/additional dependency")


def package_lock():
    return {"version": 2, "pins": [{"identity": name, "kind": "remoteSourceControl", "location": location,
             "state": {"version": version, "revision": revision}}
            for name, (location, version, revision) in sorted(PINNED_PACKAGES.items())]}


def ios_platform_evidence(output):
    versions = re.findall(r"\bplatform\s+(\S+)", output)
    bad_legacy = re.findall(r"LC_VERSION_MIN_(MACOSX|TVOS|WATCHOS)", output)
    require(not bad_legacy and all(p.upper() in ("2", "IOS") for p in versions), "non-device-iOS Mach-O platform")
    legacy = output.count("LC_VERSION_MIN_IPHONEOS")
    require(versions or legacy, "no affirmative device-iOS Mach-O platform evidence")
    return {"buildVersionCommands": len(versions), "legacyIPhoneOSCommands": legacy,
            "scope": "all reported platform commands; objects without platform commands are not individually certified"}


def linked_libraries(pbx):
    # Follow the actual Frameworks phase, not stale unused PBXFileReferences.
    refs = dict(re.findall(r'([A-F0-9]{24})[^\n]*?isa = PBXFileReference;[^\n]*?path = ("[^"\n]+"|[^;\n]+);', pbx))
    builds = dict(re.findall(r'([A-F0-9]{24})[^\n]*?isa = PBXBuildFile;[^\n]*?fileRef = ([A-F0-9]{24})', pbx))
    blocks = re.findall(r'isa = PBXFrameworksBuildPhase;[\s\S]*?files = \(([\s\S]*?)\);', pbx)
    paths = set()
    for block in blocks:
        for build in re.findall(r'\b[A-F0-9]{24}\b', block):
            path = refs.get(builds.get(build, ""), "").strip('"')
            prefix = "RTABMapApp/Libraries/"
            if path.startswith(prefix):
                relative = safe_relative(path[len(prefix):])
                if str(relative).endswith(".a"):
                    paths.add(str(relative))
                elif str(relative).endswith(".framework"):
                    paths.add(str(relative / relative.stem))
    require("lib/librtabmap_core.a" in paths and "lib/vtk.framework/vtk" in paths, "unexpected native link manifest")
    return sorted(paths)


def app_build_args(project, work):
    return ["xcodebuild", "-project", str(project), "-scheme", "RTABMapApp", "-configuration", "Release",
            "-sdk", "iphoneos", "-destination", "generic/platform=iOS", "-jobs", "2",
            "-derivedDataPath", str(work / "DerivedData"), "-clonedSourcePackagesDirPath", str(work / "packages"),
            "-packageCachePath", str(work / "package-cache"), "-disableAutomaticPackageResolution",
            "-onlyUsePackageVersionsFromResolvedFile", "ARCHS=arm64", "ONLY_ACTIVE_ARCH=NO",
            "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY=", "DEVELOPMENT_TEAM=", "build"]


class HTTPSOnly(urllib.request.HTTPRedirectHandler):
    @staticmethod
    def validate(url):
        parsed = urllib.parse.urlparse(url)
        require(parsed.scheme == "https" and parsed.hostname in
                {"github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"}
                and parsed.port in (None, 443) and parsed.username is None, "unapproved asset URL/redirect")
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        self.validate(newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


class Experiment:
    def __init__(self, source, work):
        self.source, self.work = source, work
        self.started = time.monotonic()
        self.next_check = 0.0
        self.peak_bytes = 0
        self.min_free = shutil.disk_usage(work).free
        self.logdir = work / "logs"
        self.logdir.mkdir()
        self.receipt = work / "receipt"
        self.receipt.mkdir()
        self.steps = []
        self.summary = {"scope": "unsigned device compile only; no runtime or physical-safety validation",
                        "status": "running", "upstreamRevision": UPSTREAM, "assetSHA256": ASSET_SHA,
                        "policyCaps": {"seconds": MAX_SECONDS, "workBytes": MAX_WORK, "zipExpandedBytes": MAX_ZIP,
                                       "zipEntries": MAX_ENTRIES, "minimumFreeBytes": 2 * GIB, "jobs": 2}}
        self.env = dict(os.environ, CMAKE_BUILD_PARALLEL_LEVEL="2", GIT_TERMINAL_PROMPT="0",
                        CLANG_MODULE_CACHE_PATH=str(work / "module-cache"),
                        SWIFTPM_MODULECACHE_OVERRIDE=str(work / "swift-module-cache"))

    def check(self, force=False):
        now = time.monotonic()
        require(now - self.started < MAX_SECONDS, "total time cap")
        if not force and now < self.next_check:
            return
        self.next_check = now + 5
        used = 0
        for root, dirs, files in os.walk(self.work, followlinks=False):
            for name in files:
                used += (Path(root) / name).lstat().st_size
        free = shutil.disk_usage(self.work).free
        self.peak_bytes = max(self.peak_bytes, used)
        self.min_free = min(self.min_free, free)
        require(used <= MAX_WORK, "owned-work byte cap")
        require(free >= 2 * GIB, "free disk floor")

    def run(self, name, command, cwd=None, timeout=600):
        self.check(force=True)
        log = self.logdir / (name + ".log")
        step = {"name": name, "command": [str(c) for c in command], "status": "running"}
        self.steps.append(step)
        start = time.monotonic()
        with open(log, "wb") as out:
            process = subprocess.Popen(command, cwd=cwd or self.work, env=self.env, stdout=out,
                                       stderr=subprocess.STDOUT, start_new_session=True)
            try:
                while process.poll() is None:
                    self.check()
                    require(time.monotonic() - start < timeout, "step time cap: " + name)
                    require(log.stat().st_size <= MAX_LOG, "step log cap: " + name)
                    time.sleep(0.1)
                step["exitCode"] = process.returncode
                require(process.returncode == 0, "command failed: " + name)
                step["status"] = "passed"
            except BaseException as error:
                step["status"] = "failed"
                step["error"] = str(error)
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                step["exitCode"] = process.returncode
                raise
            finally:
                step["seconds"] = round(time.monotonic() - start, 2)
        self.check(force=True)
        return log

    def download(self):
        path = self.work / "libraries.zip"
        HTTPSOnly.validate(ASSET_URL)
        opener = urllib.request.build_opener(HTTPSOnly())
        count, digest, start = 0, hashlib.sha256(), time.monotonic()
        with opener.open(ASSET_URL, timeout=30) as response, open(path, "xb") as out:
            require(response.status == 200, "asset HTTP status")
            length = response.headers.get("Content-Length")
            require(length is None or int(length) == ASSET_BYTES, "asset declared size mismatch")
            while chunk := response.read(1024 ** 2):
                count += len(chunk)
                require(count <= ASSET_BYTES and time.monotonic() - start < 600, "asset download cap")
                out.write(chunk)
                digest.update(chunk)
                self.check()
        require(count == ASSET_BYTES and digest.hexdigest() == ASSET_SHA, "asset size/digest mismatch")
        self.summary["assetBytes"] = count
        return path

    def finish(self, error=None):
        self.summary.update(status="failed" if error else "passed", error=str(error) if error else None,
                            seconds=round(time.monotonic() - self.started, 2), steps=self.steps,
                            peakOwnedBytes=self.peak_bytes, minimumFreeBytes=self.min_free)
        json_write(self.receipt / "summary.json", self.summary)
        # Only bounded excerpts, not binaries or the complete build tree, leave this machine.
        excerpts = []
        for step in self.steps:
            path = self.logdir / (step["name"] + ".log")
            if path.exists():
                with open(path, "rb") as stream:
                    stream.seek(max(0, path.stat().st_size - 8192))
                    excerpts.append("\n=== " + step["name"] + " ===\n" + stream.read(8192).decode("utf-8", errors="replace"))
        (self.receipt / "diagnostics.txt").write_text("".join(excerpts)[-512000:])
        require(sum(p.stat().st_size for p in self.receipt.iterdir()) <= 2 * 1024 ** 2, "receipt cap")


def check_host(source, expected_sha, allow_pinned_push=False):
    e = os.environ
    require(e.get("GITHUB_ACTIONS") == "true" and e.get("RUNNER_ENVIRONMENT") == "github-hosted", "github-hosted only")
    require(e.get("GITHUB_REPOSITORY") == "mischa23v/blind"
            and e.get("GITHUB_REF") == "refs/heads/master" and e.get("GITHUB_RUN_ATTEMPT") == "1", "public master first-attempt only")
    check_event(e.get("GITHUB_EVENT_NAME"), allow_pinned_push)
    event = json.loads(Path(e["GITHUB_EVENT_PATH"]).read_text())
    require(event.get("repository", {}).get("private") is False, "public source only")
    require(platform.system() == "Darwin" and e.get("DEVELOPER_DIR") == DEVELOPER and Path(DEVELOPER).is_dir(), "installed exact Xcode27 only")
    require(re.fullmatch(r"[0-9]+", e.get("GITHUB_RUN_ID", "")), "invalid run id")
    for tool in ("git", "node", "cmake", "python3", "xcodebuild", "xcrun"):
        require(shutil.which(tool), "missing tool; no installation allowed: " + tool)
    require(shutil.disk_usage(e["RUNNER_TEMP"]).free >= 12 * GIB, "initial disk below 12 GiB")
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=source, text=True, timeout=20).strip()
    require(head == expected_sha and re.fullmatch(r"[a-f0-9]{40}", head), "app source SHA mismatch")
    require(sha(Path(__file__)) == sha(source / "tools/ci/native-rtab-grid.py"), "runner differs from exact app source")
    return head


def copy_sources(experiment):
    names = subprocess.check_output(["git", "ls-files", "-z"], cwd=experiment.source, timeout=20).decode().split("\0")
    app = experiment.work / "app"
    app.mkdir()
    hashes = {}
    for name in names:
        if not (name.startswith(("BlindCore/", "BlindMemory/", "ios/BlindAssist/", "integration/")) or name == "tools/prepare-rtabmap.mjs"):
            continue
        relative = safe_relative(name)
        source = experiment.source.joinpath(*relative.parts)
        require(source.is_file() and not source.is_symlink(), "nonregular selected app source")
        target = app.joinpath(*relative.parts)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        hashes[name] = sha(target)
        experiment.check()
    require(hashes and (app / "tools/prepare-rtabmap.mjs").exists(), "required app source unavailable")
    json_write(experiment.receipt / "app-source-hashes.json", hashes)
    return app


def relocate_g2o(text):
    return re.sub(r'[^\r\n";]*/Libraries', '${CMAKE_CURRENT_LIST_DIR}/../../..', text)


def version_headers(libraries):
    required = {
        "include/opencv4/opencv2/core/version.hpp": (("CV_VERSION_MAJOR", "CV_VERSION_MINOR", "CV_VERSION_REVISION"), (4, 11, 0)),
        "include/pcl-1.15/pcl/pcl_config.h": (("PCL_MAJOR_VERSION", "PCL_MINOR_VERSION", "PCL_REVISION_VERSION"), (1, 15, 0)),
    }
    for relative, (names, expected) in required.items():
        path = libraries / relative
        require(path.is_file(), "required dependency version header missing: " + relative)
        contents = path.read_text()
        observed = []
        for name in names:
            values = re.findall(r"^\s*#\s*define\s+" + name + r"\s+(\d+)\b", contents, re.MULTILINE)
            require(len(values) == 1, "missing/ambiguous version define: " + name)
            observed.append(int(values[0]))
        require(tuple(observed) == expected, "dependency version drift: " + relative)
    candidates = ("include/boost/version.hpp", "include/eigen3/Eigen/src/Core/util/Macros.h",
                  "include/lz4.h", "include/flann/config.h", "include/gtsam/config.h",
                  "include/suitesparse/SuiteSparse_config.h", "include/g2o/config.h",
                  "lib/vtk.framework/Headers/vtkVersionMacros.h", "include/pcl-1.15/pcl/pcl_config.h",
                  "include/opencv4/opencv2/core/version.hpp", "include/liblas/version.hpp")
    result = []
    for relative in candidates:
        path = libraries / relative
        if not path.is_file():
            result.append({"path": relative, "available": False})
            continue
        lines = [line.strip()[:300] for line in path.read_text(errors="replace").splitlines()
                 if re.match(r"\s*#\s*define\s+\w*VERSION\w*\s+", line)]
        result.append({"path": relative, "available": True, "sha256": sha(path), "versionDefines": lines[:30]})
    return result


def execute(experiment, head):
    x = experiment
    x.summary["appRevision"] = head
    x.summary["workflowRevision"] = os.environ["GITHUB_SHA"]
    x.summary["runnerSHA256"] = sha(Path(__file__))
    version = x.run("xcode-version", ["xcodebuild", "-version"]).read_text()
    sdk = x.run("sdk-version", ["xcrun", "--sdk", "iphoneos", "--show-sdk-version"]).read_text().strip()
    require(version.startswith("Xcode 27.") and sdk.startswith("27."), "actual installed Xcode/iPhoneOS version mismatch")
    for tool in ("cmake", "node", "python3"):
        x.run(tool + "-version", [tool, "--version"])
    x.run("source-clean-at-entry", ["git", "diff", "--exit-code", "HEAD", "--"], x.source)
    app = copy_sources(x)
    lock = json.loads((app / "integration/rtabmap.lock.json").read_text())
    require(lock["revision"] == UPSTREAM and lock["repository"] == UPSTREAM_URL, "upstream lock drift")
    overlay_file = app / "integration/rtabmap/local-grid-manifest.json"
    overlay = json.loads(overlay_file.read_text())
    require(overlay["revision"] == UPSTREAM and len(overlay["files"]) == 5 and
            {f["path"] for f in overlay["files"]} == OVERLAY_PATHS, "unexpected overlay manifest")
    upstream = app / ".tools/rtabmap"
    upstream.mkdir(parents=True)
    x.run("upstream-init", ["git", "init", str(upstream)])
    x.run("upstream-remote", ["git", "remote", "add", "origin", UPSTREAM_URL], upstream)
    x.run("upstream-fetch", ["git", "fetch", "--depth=1", "origin", UPSTREAM], upstream, 300)
    x.run("upstream-checkout", ["git", "checkout", "--detach", "FETCH_HEAD"], upstream)
    require(x.run("upstream-head", ["git", "rev-parse", "HEAD"], upstream).read_text().strip() == UPSTREAM, "upstream HEAD mismatch")
    upstream_lock = upstream / "app/ios/RTABMapApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    verify_packages(json.loads(upstream_lock.read_text()), {"zip": PINNED_PACKAGES["zip"]})
    require('exact: "7.11.1"' in (app / "BlindMemory/Package.swift").read_text(), "GRDB package requirement drift")
    script = upstream / "app/ios/RTABMapApp/install_deps.sh"
    require(sha(script) == INSTALL_SHA, "pinned install recipe drift")
    for entry in overlay["files"]:
        require(sha(upstream / entry["path"]) == entry["beforeSHA256"], "overlay preimage drift")
    x.run("prepare-reviewed-overlay", ["node", "tools/prepare-rtabmap.mjs"], app)
    for entry in overlay["files"]:
        require(sha(upstream / entry["path"]) == entry["afterSHA256"], "overlay postimage drift")
    require(sha(upstream / "app/android/jni/BlindLocalGridBridge.hpp") == sha(app / "integration/rtabmap/BlindLocalGridBridge.hpp"), "bridge header drift")
    require("typedef void (*BlindGridCallback)(void *, const BlindGridPacket *);" in (upstream / "app/android/jni/BlindLocalGridBridge.hpp").read_text(), "C callback signature absent")
    require("var localGridReceived: ((NativeLocalGridPacket) -> Void)?" in (upstream / "app/ios/RTABMapApp/RTABMap.swift").read_text(), "Swift callback signature absent")
    project = upstream / "app/ios/RTABMapApp.xcodeproj"
    pbx = (project / "project.pbxproj").read_text()
    require(all(s in pbx for s in ("BLIND_RTABMAP", "NativeMapping.swift", "BlindCore", "BlindMemory")), "native target integration missing")
    json_write(x.receipt / "overlay-inputs.json", {"manifestSHA256": sha(overlay_file), "manifest": overlay,
        "bridgeHeaderSHA256": sha(app / "integration/rtabmap/BlindLocalGridBridge.hpp"), "preparedProjectSHA256": sha(project / "project.pbxproj"),
        "installRecipeSHA256": INSTALL_SHA})
    libraries = upstream / "app/ios/RTABMapApp/Libraries"
    x.summary["archive"] = extract_archive(x.download(), libraries, x.check)
    require(all((libraries / path).exists() for path in SENTINELS), "missing prebuilt dependency sentinel; no fallback")
    linked = linked_libraries(pbx)
    header_evidence = version_headers(libraries)
    dependency_records = []
    for index, relative in enumerate(linked):
        if Path(relative).name in ("librtabmap_core.a", "librtabmap_utilite.a"):
            continue  # These exact-source products are rebuilt below, never accepted from the ZIP.
        path = libraries / relative
        require(path.is_file(), "missing linked prebuilt: " + relative)
        arch = x.run(f"arch-{index}", ["xcrun", "lipo", "-archs", str(path)]).read_text().strip()
        require("arm64" in arch.split(), "missing arm64 in " + relative)
        load = x.run(f"platform-{index}", ["xcrun", "otool", "-l", "-arch", "arm64", str(path)]).read_text()
        dependency_records.append({"path": relative, "sha256": sha(path), "architectures": arch,
                                   "platformEvidence": ios_platform_evidence(load)})
    json_write(x.receipt / "dependency-manifest.json", {"linkedBinaries": dependency_records,
        "archive": x.summary["archive"], "binarySBOMVerified": False, "distributionApproved": False,
        "licenseCaveat": "Linked SuiteSparse SPQR/CHOLMOD and LGPL components need distribution review; root BSD is not the whole-app license.",
        "declaredRecipeVersionsNotBinaryAttestation": {"boost": "1.88.0", "eigen": "3.4.0", "lz4": "1.10.0",
          "flann": "1.9.2", "gtsam": "4.2", "suitesparse": "7.6.1", "g2o": "20241228_git", "vtk": "9.5.0.rc1",
          "pcl": "1.15.0", "opencv": "4.11.0", "laszip": "2.0.1", "libLAS": "unpinned script branch; archive pinned by SHA"},
        "versionHeaderEvidence": header_evidence})
    relocations = []
    for path in sorted((libraries / "lib").glob("**/cmake/g2o/*.cmake")):
        before = sha(path)
        path.write_text(relocate_g2o(path.read_text()))
        relocations.append({"path": str(path.relative_to(libraries)), "before": before, "after": sha(path)})
    x.summary["g2oRelocations"] = relocations
    # This is only the pinned install script's final RTAB resource/core section.
    # Never execute its dependency-clone/build branches.
    core = libraries / "rtabmap"
    require(not core.exists(), "unexpected archive bundled build tree")
    core.mkdir()
    x.run("resource-configure", ["cmake", "-DANDROID_PREBUILD=ON", str(upstream)], core)
    x.run("resource-build", ["cmake", "--build", ".", "--config", "Release", "--parallel", "2"], core)
    ios = core / "ios"
    ios.mkdir()
    config = ["cmake", "-G", "Xcode", "-DCMAKE_SYSTEM_NAME=iOS", "-DCMAKE_OSX_ARCHITECTURES=arm64",
              "-DCMAKE_OSX_SYSROOT=iphoneos", "-DBUILD_SHARED_LIBS=OFF", "-DCMAKE_BUILD_TYPE=Release",
              "-DCMAKE_OSX_DEPLOYMENT_TARGET=12.0", "-DCMAKE_INSTALL_PREFIX=" + str(libraries),
              "-DCMAKE_FIND_ROOT_PATH=" + str(libraries)]
    config += ["-D" + setting for setting in ("WITH_QT=OFF", "BUILD_APP=OFF", "BUILD_TOOLS=OFF", "WITH_TORO=OFF",
               "WITH_VERTIGO=OFF", "WITH_MADGWICK=OFF", "WITH_ORB_OCTREE=ON", "BUILD_EXAMPLES=OFF", "WITH_LIBLAS=ON", "WITH_OPENGV=OFF")]
    x.run("core-configure", config + [str(upstream)], ios)
    unsigned = ["--", "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY=", "CODE_SIGN_ENTITLEMENTS="]
    x.run("core-build", ["cmake", "--build", ".", "--config", "Release", "--parallel", "2"] + unsigned, ios, 1200)
    x.run("core-install-prefix", ["cmake", "--build", ".", "--config", "Release", "--target", "install", "--parallel", "2"] + unsigned, ios, 300)
    for name in ("librtabmap_core.a", "librtabmap_utilite.a"):
        path = libraries / "lib" / name
        require(path.is_file(), "exact-source core library missing")
        evidence = x.run("platform-built-" + name, ["xcrun", "otool", "-l", "-arch", "arm64", str(path)]).read_text()
        ios_platform_evidence(evidence)
    package_path = project / "project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    package_path.parent.mkdir(parents=True, exist_ok=True)
    json_write(package_path, package_lock())
    arguments = app_build_args(project, x.work)
    resolution = arguments[:]
    resolution.remove("-disableAutomaticPackageResolution")
    resolution[-1] = "-resolvePackageDependencies"
    x.run("resolve-pinned-packages", resolution, timeout=300)
    verify_packages(json.loads(package_path.read_text()))
    json_write(x.receipt / "Package.resolved.json", json.loads(package_path.read_text()))
    x.run("actual-native-app-build", arguments, timeout=1200)
    verify_packages(json.loads(package_path.read_text()))
    # Preparation edits occur only in this disposable tree. The app checkout stays unchanged.
    x.run("source-unchanged", ["git", "diff", "--exit-code", "HEAD", "--"], x.source)


def validate_receipt(path):
    allowed = {"summary.json", "diagnostics.txt", "app-source-hashes.json", "overlay-inputs.json",
               "dependency-manifest.json", "Package.resolved.json"}
    require(path.is_dir() and not path.is_symlink(), "receipt directory absent/unsafe")
    files = list(path.iterdir())
    require(files and all(p.name in allowed and p.is_file() and not p.is_symlink() for p in files), "unexpected receipt entry")
    require(sum(p.stat().st_size for p in files) <= 2 * 1024 ** 2, "receipt upload cap")
    require((path / "summary.json").is_file(), "summary receipt missing")


def receipt_path():
    require(re.fullmatch(r"[0-9]+", os.environ.get("GITHUB_RUN_ID", "")), "invalid run id")
    require(os.environ.get("GITHUB_RUN_ATTEMPT") == "1", "first attempt only")
    return Path(os.environ["RUNNER_TEMP"]) / ("blind-rtab-grid-" + os.environ["GITHUB_RUN_ID"] + "-1") / "receipt"


def check_event(event, allow_pinned_push):
    require(event == "workflow_dispatch" or (event == "push" and allow_pinned_push), "manual event or explicit pinned push only")


def select_source(source_arg, expected_arg, allow_push, own_source, environment):
    require((source_arg is None) == (expected_arg is None), "source path and expected SHA must be paired")
    require(not allow_push or source_arg is not None, "pinned push requires explicit source pair")
    source = Path(source_arg).resolve() if source_arg is not None else own_source.resolve()
    workspace = Path(environment["GITHUB_WORKSPACE"]).resolve()
    require(source.is_relative_to(workspace), "source must be inside checkout workspace")
    expected = expected_arg if expected_arg is not None else environment.get("GITHUB_SHA", "")
    require(re.fullmatch(r"[a-f0-9]{40}", expected), "expected source must be immutable 40-hex SHA")
    return source, expected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--validate-receipt", action="store_true")
    parser.add_argument("--source", help="Exact source checkout inside GITHUB_WORKSPACE; pair with --expected-source")
    parser.add_argument("--expected-source", help="Reviewed immutable app commit; never a branch/tag")
    parser.add_argument("--allow-pinned-push", action="store_true", help="Only for a separately reviewed workflow-only activation with explicit source pair")
    options = parser.parse_args()
    if options.validate_receipt:
        try:
            require(options.source is None and options.expected_source is None and not options.allow_pinned_push, "receipt-only invocation")
            validate_receipt(receipt_path())
            return 0
        except (RuntimeError, KeyError) as error:
            print("Metadata upload refused: " + str(error), file=sys.stderr)
            return 1
    own_source = Path(__file__).resolve().parents[2]
    experiment = None
    try:
        # Refuse local/nonhosted execution before interpreting activation paths.
        require(os.environ.get("GITHUB_ACTIONS") == "true" and os.environ.get("RUNNER_ENVIRONMENT") == "github-hosted", "github-hosted only")
        source, expected = select_source(options.source, options.expected_source, options.allow_pinned_push, own_source, os.environ)
        head = check_host(source, expected, options.allow_pinned_push)
        work = Path(os.environ["RUNNER_TEMP"]) / ("blind-rtab-grid-" + os.environ["GITHUB_RUN_ID"] + "-1")
        work.mkdir(exist_ok=False)
        experiment = Experiment(source, work)
        execute(experiment, head)
        experiment.finish()
        print("Unsigned device source compile passed; no runtime/safety claim.")
        return 0
    except BaseException as error:
        if experiment:
            experiment.finish(error)
        print("RTAB experiment stopped: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
