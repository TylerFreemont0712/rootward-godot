"""Take names and digests, the cache's listing, briefs, and the package loader (missing tracks included)."""

import json
import os
import tempfile
import unittest
from pathlib import Path

import helpers  # noqa: F401
import library


class Names(unittest.TestCase):
    def test_a_digest_is_stable_and_follows_the_request(self):
        request = {"style": "a", "abc": "X:1\n", "lm_seed": 1, "seed": 2}
        self.assertEqual(library.digest(request), library.digest(dict(reversed(list(request.items())))))
        self.assertEqual(len(library.digest(request)), 6)
        self.assertNotEqual(library.digest(request), library.digest({**request, "style": "b"}))

    def test_native_takes_keep_the_names_the_cache_already_has(self):
        request = {"style": "gentle lullaby", "duration": 76.7}
        self.assertEqual(library.take_name("native", 1001, 1101, 32, request),
                         f"yue2-1001-1101-s32-{library.digest(request)}")

    def test_comfy_takes_are_named_apart(self):
        request = {"style": "gentle lullaby", "duration": 76.7}
        name = library.take_name("comfy", 1000, 1100, 32, request)
        self.assertTrue(name.startswith("yue2-comfy-1000-1100-s32-"), name)
        self.assertNotEqual(name, library.take_name("native", 1000, 1100, 32, request))


class Cache(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.old = os.environ.get("ROOTWARD_MUSIC_TAKES")
        os.environ["ROOTWARD_MUSIC_TAKES"] = self.tmp.name

    def tearDown(self):
        if self.old is None:
            os.environ.pop("ROOTWARD_MUSIC_TAKES", None)
        else:
            os.environ["ROOTWARD_MUSIC_TAKES"] = self.old
        self.tmp.cleanup()

    def test_takes_are_the_finished_wavs_only(self):
        folder = Path(self.tmp.name) / "rest"
        folder.mkdir()
        for name in ("yue2-1000-1100-s32-aaaaaa.wav", "yue2-comfy-1000-1100-s32-bbbbbb.wav",
                     "yue2-1001-1101-s32-cccccc.partial.wav", "yue2-1002-1102-s32-dddddd.request.json"):
            (folder / name).write_bytes(b"")
        self.assertEqual(library.takes("rest"), ["yue2-1000-1100-s32-aaaaaa", "yue2-comfy-1000-1100-s32-bbbbbb"])
        self.assertIsNotNone(library.find_take("rest", "yue2-1000-1100-s32-aaaaaa"))
        self.assertIsNone(library.find_take("rest", "yue2-9999-9999-s32-000000"))

    def test_the_takes_folder_follows_the_environment(self):
        self.assertEqual(library.takes_dir(), Path(self.tmp.name))


class Briefs(unittest.TestCase):
    def test_a_missing_track_says_so(self):
        with self.assertRaisesRegex(library.TrackError, "missing track 'no-such-track'"):
            library.brief("no-such-track")

    def test_a_track_id_must_be_a_plain_id(self):
        with self.assertRaises(library.TrackError):
            library.track_dir("../escape")

    def test_problems_of_a_brief(self):
        problems = library.brief_problems("rest", {"id": "heap", "out": "music-rest", "style": "s", "bpm": 76,
                                                   "key": "F", "kind": "loop"})
        self.assertTrue(any("id 'heap'" in p for p in problems), problems)
        self.assertTrue(any("loop needs" in p for p in problems), problems)
        self.assertEqual(library.brief_problems("rest", library.brief("rest")), [])
        self.assertTrue(any("kind" in p for p in library.brief_problems(
            "x", {"id": "x", "out": "o", "style": "s", "bpm": 1, "key": "C", "kind": "song"})))


class Packages(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.old = library.PACKAGES
        library.PACKAGES = Path(self.tmp.name)

    def tearDown(self):
        library.PACKAGES = self.old
        self.tmp.cleanup()

    def write(self, name, data):
        text = data if isinstance(data, str) else json.dumps(data)
        (Path(self.tmp.name) / f"{name}.json").write_text(text)

    def test_a_package_lists_its_tracks_and_which_are_missing(self):
        self.write("menu", {"name": "menu", "title": "Menu", "concept": "Concept/v0.3/05-lanternroot-overworld.md",
                            "tracks": ["rest", "lanternroot-not-yet-written"]})
        package = library.load_package("menu")
        self.assertEqual(package.title, "Menu")
        self.assertEqual(package.tracks, ("rest", "lanternroot-not-yet-written"))
        self.assertEqual(package.present, ["rest"])
        self.assertEqual(package.missing, ["lanternroot-not-yet-written"])
        self.assertEqual(package.concept_path.name, "05-lanternroot-overworld.md")

    def test_the_shipped_package_loads(self):
        library.PACKAGES = self.old
        package = library.load_package("menu-and-lanternroot")
        self.assertIn("title", package.tracks)
        self.assertTrue(any(t.startswith("lanternroot-") for t in package.tracks), package.tracks)

    def test_a_package_that_is_not_there(self):
        with self.assertRaisesRegex(library.PackageError, "no package 'nope'"):
            library.load_package("nope")

    def test_malformed_packages_are_refused(self):
        cases = {
            "notjson": "{ nope",
            "wrongname": {"name": "other", "title": "T", "tracks": ["rest"]},
            "notitle": {"name": "bad", "tracks": ["rest"]},
            "empty": {"name": "bad", "title": "T", "tracks": []},
            "badid": {"name": "bad", "title": "T", "tracks": ["Rest Track"]},
            "twice": {"name": "bad", "title": "T", "tracks": ["rest", "rest"]},
            "notalist": {"name": "bad", "title": "T", "tracks": "rest"},
        }
        for name, data in cases.items():
            self.write(name, data)
        for name in cases:
            with self.subTest(name=name), self.assertRaises(library.PackageError):
                library.load_package(name)


if __name__ == "__main__":
    unittest.main()
