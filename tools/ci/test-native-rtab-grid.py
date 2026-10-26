#!/usr/bin/env python3
"""Pure fixtures: no network, native compiler, archive download or activation."""
import copy
import importlib.util
import io
import json
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location("runner", Path(__file__).with_name("native-rtab-grid.py"))
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)


def archive(files):
    data = io.BytesIO()
    with zipfile.ZipFile(data, "w") as z:
        for name, body, kind in files:
            entry = zipfile.ZipInfo(name)
            entry.create_system = 3
            entry.external_attr = (kind | 0o644) << 16
            z.writestr(entry, body)
    data.seek(0)
    return zipfile.ZipFile(data)


BASE = [("include/test.h", b"#define VERSION 1", stat.S_IFREG), ("lib/test.a", b"fixture", stat.S_IFREG)]


class ArchiveTests(unittest.TestCase):
    def test_direct_and_wrapper_layout(self):
        for prefix in ("", "Libraries/"):
            with archive([(prefix + p, b, k) for p, b, k in BASE]) as z:
                self.assertEqual(len(r.zip_manifest(z)), 2)

    def test_reject_traversal_absolute_windows_and_unknown_root(self):
        for name in ("../escape", "/absolute", "lib/../escape", "lib\\escape", "C:/escape", "rtabmap/build"):
            with archive(BASE + [(name, b"x", stat.S_IFREG)]) as z:
                with self.subTest(name=name), self.assertRaises(RuntimeError):
                    r.zip_manifest(z)

    def test_reject_case_collision_and_duplicate(self):
        for name in ("include/test.h", "include/TEST.h"):
            with archive(BASE + [(name, b"x", stat.S_IFREG)]) as z:
                with self.assertRaises(RuntimeError):
                    r.zip_manifest(z)

    def test_reject_encryption_oversize_and_entry_limit(self):
        with archive(BASE) as z:
            z.infolist()[0].flag_bits |= 1
            with self.assertRaises(RuntimeError): r.zip_manifest(z)
        with archive(BASE) as z:
            z.infolist()[0].file_size = r.MAX_ZIP + 1
            with self.assertRaises(RuntimeError): r.zip_manifest(z)
        with archive(BASE) as z, patch.object(r, "MAX_ENTRIES", 1):
            with self.assertRaises(RuntimeError): r.zip_manifest(z)

    def test_reject_special_file_and_escaping_link(self):
        for body, kind in ((b"x", stat.S_IFIFO), (b"../../../outside", stat.S_IFLNK), (b"/outside", stat.S_IFLNK)):
            with archive(BASE + [("lib/link", body, kind)]) as z:
                with self.assertRaises(RuntimeError): r.zip_manifest(z)

    def test_reject_writes_through_symlink_parent(self):
        with archive(BASE + [("lib/link", b"target", stat.S_IFLNK), ("lib/link/child", b"x", stat.S_IFREG)]) as z:
            with self.assertRaises(RuntimeError): r.zip_manifest(z)

    def test_internal_framework_links_extract_and_resolve(self):
        entries = BASE + [("lib/vtk.framework/Versions/A/vtk", b"binary fixture", stat.S_IFREG),
                          ("lib/vtk.framework/Versions/Current", b"A", stat.S_IFLNK),
                          ("lib/vtk.framework/vtk", b"Versions/Current/vtk", stat.S_IFLNK)]
        with tempfile.TemporaryDirectory() as tmp:
            with archive(entries) as z:
                source = Path(tmp) / "fixture.zip"
                source.write_bytes(z.fp.getvalue())
            target = Path(tmp) / "Libraries"
            result = r.extract_archive(source, target, lambda: None)
            self.assertEqual(result["symlinks"], 2)
            self.assertEqual((target / "lib/vtk.framework/vtk").read_bytes(), b"binary fixture")
            with self.assertRaises(RuntimeError): r.extract_archive(source, target, lambda: None)

    def test_dangling_or_cyclic_links_fail(self):
        with tempfile.TemporaryDirectory() as tmp:
            with archive(BASE + [("lib/link", b"link", stat.S_IFLNK)]) as z:
                source = Path(tmp) / "fixture.zip"
                source.write_bytes(z.fp.getvalue())
            with self.assertRaises((RuntimeError, OSError)):
                r.extract_archive(source, Path(tmp) / "Libraries", lambda: None)


class PinAndCommandTests(unittest.TestCase):
    def test_packages_exact_and_reject_version_revision_or_additional(self):
        valid = r.package_lock()
        r.verify_packages(valid)
        for field in ("version", "revision"):
            bad = copy.deepcopy(valid)
            bad["pins"][0]["state"][field] = "wrong"
            with self.assertRaises(RuntimeError): r.verify_packages(bad)
        bad = copy.deepcopy(valid)
        bad["pins"].append({"location": "https://github.com/a/new", "state": {}})
        with self.assertRaises(RuntimeError): r.verify_packages(bad)

    def test_original_v1_zip_pin(self):
        location, version, revision = r.PINNED_PACKAGES["zip"]
        old = {"object": {"pins": [{"repositoryURL": location + ".git", "state": {"version": version, "revision": revision}}]}}
        r.verify_packages(old, {"zip": r.PINNED_PACKAGES["zip"]})
        with self.assertRaises(RuntimeError): r.verify_packages(old)

    def test_platform_must_be_device_not_merely_arm64(self):
        for output in ("cmd LC_BUILD_VERSION\n platform 2", "cmd LC_BUILD_VERSION\n platform IOS", "cmd LC_VERSION_MIN_IPHONEOS"):
            self.assertTrue(r.ios_platform_evidence(output))
        for output in ("architecture arm64", "platform 7", "platform IOSSIMULATOR", "platform 2\nplatform 1", "LC_VERSION_MIN_MACOSX"):
            with self.subTest(output=output), self.assertRaises(RuntimeError): r.ios_platform_evidence(output)

    def test_strict_asset_redirects(self):
        for host in ("github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"):
            r.HTTPSOnly.validate("https://" + host + "/asset?token=ephemeral")
        for url in ("http://github.com/asset", "https://github.com.evil.test/asset", "https://user@github.com/asset", "file:///etc/passwd", "https://github.com:444/asset"):
            with self.assertRaises(RuntimeError): r.HTTPSOnly.validate(url)

    def test_actual_unsigned_device_only_build(self):
        args = r.app_build_args(Path("/owned/project.xcodeproj"), Path("/owned"))
        self.assertEqual(args[-1], "build")
        for required in ("generic/platform=iOS", "iphoneos", "ARCHS=arm64", "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "-disableAutomaticPackageResolution", "-onlyUsePackageVersionsFromResolvedFile"):
            self.assertIn(required, args)
        self.assertFalse(set(("test", "archive", "install", "-exportArchive", "iphonesimulator")) & set(args))
        self.assertEqual(args[args.index("-jobs") + 1], "2")

    def test_link_manifest_follows_build_phase_not_stale_refs(self):
        pbx = """
AAAAAAAAAAAAAAAAAAAAAAAA = {isa = PBXFileReference; path = RTABMapApp/Libraries/lib/librtabmap_core.a; };
BBBBBBBBBBBBBBBBBBBBBBBB = {isa = PBXFileReference; path = RTABMapApp/Libraries/lib/vtk.framework; };
CCCCCCCCCCCCCCCCCCCCCCCC = {isa = PBXFileReference; path = RTABMapApp/Libraries/lib/stale.a; };
DDDDDDDDDDDDDDDDDDDDDDDD = {isa = PBXBuildFile; fileRef = AAAAAAAAAAAAAAAAAAAAAAAA; };
EEEEEEEEEEEEEEEEEEEEEEEE = {isa = PBXBuildFile; fileRef = BBBBBBBBBBBBBBBBBBBBBBBB; };
FFFFFFFFFFFFFFFFFFFFFFFF = {isa = PBXFrameworksBuildPhase; files = (DDDDDDDDDDDDDDDDDDDDDDDD, EEEEEEEEEEEEEEEEEEEEEEEE,); };
"""
        self.assertEqual(r.linked_libraries(pbx), ["lib/librtabmap_core.a", "lib/vtk.framework/vtk"])

    def test_no_nonhosted_execution(self):
        with patch.dict(r.os.environ, {}, clear=True), self.assertRaisesRegex(RuntimeError, "github-hosted only"):
            r.check_host(Path("."), "a" * 40)

    def test_failure_preserves_exit_and_no_retry(self):
        with tempfile.TemporaryDirectory() as tmp:
            experiment = r.Experiment(Path(tmp), Path(tmp))
            experiment.check = lambda force=False: None  # Resource gates tested separately.
            with self.assertRaisesRegex(RuntimeError, "command failed"):
                experiment.run("fixture-failure", [r.sys.executable, "-c", "raise SystemExit(7)"])
            experiment.finish("fixture failure")
            report = json.loads((Path(tmp) / "receipt/summary.json").read_text())
            self.assertEqual(report["status"], "failed")
            self.assertEqual(len(report["steps"]), 1)
            self.assertEqual(report["steps"][0]["exitCode"], 7)

    def test_work_and_time_caps_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            experiment = r.Experiment(Path(tmp), Path(tmp))
            (Path(tmp) / "payload").write_text("large fixture")
            with patch.object(r, "MAX_WORK", 1), self.assertRaisesRegex(RuntimeError, "owned-work byte cap"):
                experiment.check(force=True)
            experiment.started -= r.MAX_SECONDS + 1
            with self.assertRaisesRegex(RuntimeError, "total time cap"):
                experiment.check(force=True)

    def test_g2o_relocation_preserves_adjacent_lines(self):
        original = '# untouched comment\nset(PREFIX /builder/Libraries)\n# next comment\nset(OTHER /another/Libraries)\n'
        # Match upstream sed's per-line prefix replacement, including text before path.
        expected = '# untouched comment\n${CMAKE_CURRENT_LIST_DIR}/../../..)\n# next comment\n${CMAKE_CURRENT_LIST_DIR}/../../..)\n'
        self.assertEqual(r.relocate_g2o(original), expected)

    def test_dependency_versions_reject_missing_or_drift(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(RuntimeError, "version"):
                r.version_headers(Path(tmp))
            root = Path(tmp)
            cv = root / "include/opencv4/opencv2/core/version.hpp"
            pcl = root / "include/pcl-1.15/pcl/pcl_config.h"
            cv.parent.mkdir(parents=True); pcl.parent.mkdir(parents=True)
            cv.write_text("#define CV_VERSION_MAJOR 4\n#define CV_VERSION_MINOR 11\n#define CV_VERSION_REVISION 0\n")
            pcl.write_text("#define PCL_MAJOR_VERSION 1\n#define PCL_MINOR_VERSION 15\n#define PCL_REVISION_VERSION 0\n")
            self.assertTrue(r.version_headers(root))
            for path, before, after in ((cv, "MINOR 11", "MINOR 12"), (pcl, "PCL_MINOR_VERSION 15", "PCL_MINOR_VERSION 14")):
                original = path.read_text(); path.write_text(original.replace(before, after))
                with self.assertRaisesRegex(RuntimeError, "version drift"): r.version_headers(root)
                path.write_text(original)

    def test_upload_allowlist_blocks_binary_symlink_and_oversize(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "summary.json").write_text("{}")
            r.validate_receipt(root)
            (root / "binary.app").write_text("not metadata")
            with self.assertRaisesRegex(RuntimeError, "unexpected receipt"): r.validate_receipt(root)
            (root / "binary.app").unlink()
            (root / "diagnostics.txt").symlink_to(root / "summary.json")
            with self.assertRaisesRegex(RuntimeError, "unexpected receipt"): r.validate_receipt(root)
            (root / "diagnostics.txt").unlink()
            with open(root / "diagnostics.txt", "wb") as out: out.truncate(2 * 1024 ** 2)
            with self.assertRaisesRegex(RuntimeError, "upload cap"): r.validate_receipt(root)

    def test_source_selection_defaults_and_explicit_pin(self):
        with tempfile.TemporaryDirectory() as tmp:
            workspace = Path(tmp); own = workspace / "repo"; fixed = workspace / "fixed-source"
            own.mkdir(); fixed.mkdir()
            env = {"GITHUB_WORKSPACE": tmp, "GITHUB_SHA": "a" * 40}
            self.assertEqual(r.select_source(None, None, False, own, env), (own.resolve(), "a" * 40))
            self.assertEqual(r.select_source(str(fixed), "b" * 40, True, own, env), (fixed.resolve(), "b" * 40))

    def test_source_selection_rejects_unpinned_or_outside_paths(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            env = {"GITHUB_WORKSPACE": tmp, "GITHUB_SHA": "a" * 40}
            cases = [(str(root), None, False), (None, "a" * 40, False), (None, None, True),
                     (str(root), "master", True), (str(root.parent), "a" * 40, True)]
            for source, pin, push in cases:
                with self.subTest(case=(source,pin,push)), self.assertRaises(RuntimeError):
                    r.select_source(source, pin, push, root, env)

    def test_push_is_opt_in_and_other_events_never_allowed(self):
        r.check_event("workflow_dispatch", False)
        r.check_event("push", True)
        for event, flag in (("push", False), ("pull_request", True), ("workflow_run", True), ("schedule", True)):
            with self.assertRaises(RuntimeError): r.check_event(event, flag)

    def test_workflow_activation_and_artifact_bounds(self):
        workflow = Path(__file__).parents[2] / ".github/workflows/native-rtab-grid.yml"
        text = workflow.read_text()
        for required in ("workflow_dispatch:", "github.run_attempt == 1", "github.event.repository.private == false", "github.ref == 'refs/heads/master'", "contents: read", "timeout-minutes: 45", "runs-on: xcode-27", "persist-credentials: false", "retention-days: 3", "/receipt/*", "steps.receipt_guard.outcome == 'success'", "--validate-receipt"):
            self.assertIn(required, text)
        self.assertNotIn("  push:", text)
        self.assertNotIn("pull_request", text)
        self.assertNotIn("secrets.", text)
        self.assertNotIn("actions/cache", text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
