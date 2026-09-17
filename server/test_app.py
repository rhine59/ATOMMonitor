import os
import tempfile
import unittest

# Configure the database before importing app.py.
_tmp = tempfile.TemporaryDirectory()
os.environ["ATOM_DB"] = os.path.join(_tmp.name, "test.sqlite3")

import app


class StaleObservationTests(unittest.TestCase):
    def setUp(self):
        if os.path.exists(app.DB_PATH):
            os.remove(app.DB_PATH)

    def row(self, station="PWTEST"):
        with app.db() as connection:
            return dict(connection.execute("SELECT * FROM stations WHERE id=?", (station,)).fetchone())

    def test_older_status_does_not_replace_newer_status_fields(self):
        self.assertTrue(app.upsert({
            "station": "PWTEST", "kind": "status",
            "packet_time_utc": "2026-09-17T12:10:00+00:00",
            "received_at": "2026-09-17T12:10:01+00:00",
            "cpu_load": 10.0, "temperature_c": 40.0,
        }))
        self.assertTrue(app.upsert({
            "station": "PWTEST", "kind": "status",
            "packet_time_utc": "2026-09-17T12:05:00+00:00",
            "received_at": "2026-09-17T12:11:00+00:00",
            "cpu_load": 99.0, "temperature_c": 90.0,
        }))
        row = self.row()
        self.assertEqual(row["lastTechnicalStatus"], "2026-09-17T12:10:00+00:00")
        self.assertEqual(row["cpuLoadPercent"], 10.0)
        self.assertEqual(row["cpuTemperatureC"], 40.0)
        self.assertEqual(row["lastSeen"], "2026-09-17T12:10:01+00:00")

    def test_older_position_does_not_replace_newer_position(self):
        app.upsert({"station":"PWTEST","kind":"position","packet_time_utc":"2026-09-17T12:10:00+00:00","received_at":"2026-09-17T12:10:01+00:00","latitude":54.0,"longitude":-2.0})
        app.upsert({"station":"PWTEST","kind":"position","packet_time_utc":"2026-09-17T12:00:00+00:00","received_at":"2026-09-17T12:12:00+00:00","latitude":1.0,"longitude":2.0})
        row=self.row();self.assertEqual(row["latitude"],54.0);self.assertEqual(row["longitude"],-2.0);self.assertEqual(row["lastPosition"],"2026-09-17T12:10:00+00:00")

    def test_newer_packet_updates_same_category(self):
        app.upsert({"station":"PWTEST","kind":"status","packet_time_utc":"2026-09-17T12:00:00+00:00","cpu_load":10.0})
        app.upsert({"station":"PWTEST","kind":"status","packet_time_utc":"2026-09-17T12:01:00+00:00","cpu_load":20.0})
        row=self.row();self.assertEqual(row["cpuLoadPercent"],20.0);self.assertEqual(row["lastTechnicalStatus"],"2026-09-17T12:01:00+00:00")

    def test_categories_are_ordered_independently(self):
        app.upsert({"station":"PWTEST","kind":"position","packet_time_utc":"2026-09-17T12:10:00+00:00","latitude":54.0})
        app.upsert({"station":"PWTEST","kind":"pilotaware_heartbeat","packet_time_utc":"2026-09-17T12:05:00+00:00","pilotaware_version":"20260917"})
        row=self.row();self.assertEqual(row["lastPosition"],"2026-09-17T12:10:00+00:00");self.assertEqual(row["lastHeartbeat"],"2026-09-17T12:05:00+00:00");self.assertEqual(row["isPilotAware"],1)


if __name__ == "__main__":
    unittest.main()
