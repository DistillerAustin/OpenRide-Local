"""Dependency-free API tests. Run: python -m unittest discover -s tests -v"""
from __future__ import annotations

import importlib.util
import json
import os
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen


class ServerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.tmp.name) / "videos"
        cls.root.mkdir()
        (cls.root / "Rides" / "Intervals").mkdir(parents=True)
        cls.video = cls.root / "Rides" / "Intervals" / "30_min_Ride.mp4"
        cls.contents = b"1234567890" * 20
        cls.video.write_bytes(cls.contents)
        cls.video.with_suffix(".json").write_text(json.dumps({"title": "Interval Session", "instructor": "Alex", "duration_seconds": 1800}))
        cls.cache = Path(cls.tmp.name) / "cache"
        os.environ.update(VIDEO_ROOT=str(cls.root), CACHE_ROOT=str(cls.cache), PROBE_DURATION="false")
        spec = importlib.util.spec_from_file_location("openride_local_server", Path(__file__).resolve().parents[1] / "server.py")
        cls.app = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.app)
        cls.http = ThreadingHTTPServer(("127.0.0.1", 0), cls.app.Handler)
        cls.port = cls.http.server_address[1]
        cls.thread = threading.Thread(target=cls.http.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.http.shutdown()
        cls.http.server_close()
        cls.thread.join(timeout=3)
        cls.tmp.cleanup()

    def req(self, path, headers=None, method="GET"):
        return urlopen(Request(f"http://127.0.0.1:{self.port}{path}", headers=headers or {}, method=method), timeout=3)

    def test_catalog_and_nested_folder(self):
        with self.req("/api/v1/classes") as response:
            payload = json.load(response)
        self.assertEqual(payload["count"], 1)
        item = payload["classes"][0]
        self.assertEqual(item["title"], "Interval Session")
        self.assertEqual(item["collection"], "Rides/Intervals")
        self.assertEqual(item["category"], "Rides")
        self.assertEqual(item["instructor"], "Alex")
        self.assertEqual(item["duration_seconds"], 1800)
        self.assertEqual(item["source"], "local")

    def test_stream_all_and_byte_range(self):
        item = json.load(self.req("/api/v1/classes"))["classes"][0]
        path = item["playback_url"]
        with self.req(path) as response:
            self.assertEqual(response.status, 200)
            self.assertEqual(response.read(), self.contents)
        with self.req(path, {"Range": "bytes=4-12"}) as response:
            self.assertEqual(response.status, 206)
            self.assertEqual(response.headers["Content-Range"], "bytes 4-12/200")
            self.assertEqual(response.read(), self.contents[4:13])
        with self.req(path, {"Range": "bytes=-4"}) as response:
            self.assertEqual(response.status, 206)
            self.assertEqual(response.read(), self.contents[-4:])
        with self.req(path, method="HEAD") as response:
            self.assertEqual(response.status, 200)
            self.assertEqual(int(response.headers["Content-Length"]), len(self.contents))
        with self.assertRaises(HTTPError) as error:
            self.req(path, {"Range": "bytes=200-300"})
        self.assertEqual(error.exception.code, 416)

    def test_live_library_refresh(self):
        new_video = self.root / "Rides" / "Free Ride.m4v"
        new_video.write_bytes(b"HELLO")
        try:
            payload = json.load(self.req("/api/v1/classes"))
            self.assertEqual(payload["count"], 2)
        finally:
            new_video.unlink()

    def test_missing_routes_and_traversal_not_allowed(self):
        for path in ("/api/v1/classes/../../etc/passwd/video", "/api/v1/classes/not-a-real-id/video"):
            with self.assertRaises(HTTPError) as error:
                self.req(path)
            self.assertEqual(error.exception.code, 404)


if __name__ == "__main__":
    unittest.main()
