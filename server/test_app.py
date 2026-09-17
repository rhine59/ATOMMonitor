import os
import tempfile
import unittest

_tmp = tempfile.TemporaryDirectory()
os.environ["ATOM_DB"] = os.path.join(_tmp.name, "test.sqlite3")
import app

class StaleObservationTests(unittest.TestCase):
    def setUp(self):
        if os.path.exists(app.DB_PATH):os.remove(app.DB_PATH)
    def row(self,station="PWTEST"):
        with app.db() as connection:
            r=connection.execute("SELECT * FROM stations WHERE id=?",(station,)).fetchone();return dict(r) if r else None
    def test_older_status_does_not_replace_newer_status_fields(self):
        self.assertTrue(app.upsert({"station":"PWTEST","kind":"status","packet_time_utc":"2026-09-17T12:10:00+00:00","received_at":"2026-09-17T12:10:01+00:00","cpu_load":10.0,"temperature_c":40.0}))
        self.assertTrue(app.upsert({"station":"PWTEST","kind":"status","packet_time_utc":"2026-09-17T12:05:00+00:00","received_at":"2026-09-17T12:11:00+00:00","cpu_load":99.0,"temperature_c":90.0}))
        r=self.row();self.assertEqual(r["lastTechnicalStatus"],"2026-09-17T12:10:00+00:00");self.assertEqual(r["cpuLoadPercent"],10.0);self.assertEqual(r["cpuTemperatureC"],40.0);self.assertEqual(r["lastSeen"],"2026-09-17T12:10:01+00:00")
    def test_older_position_does_not_replace_newer_position(self):
        app.upsert({"station":"PWTEST","kind":"position","packet_time_utc":"2026-09-17T12:10:00+00:00","received_at":"2026-09-17T12:10:01+00:00","latitude":54.0,"longitude":-2.0})
        app.upsert({"station":"PWTEST","kind":"position","packet_time_utc":"2026-09-17T12:00:00+00:00","received_at":"2026-09-17T12:12:00+00:00","latitude":1.0,"longitude":2.0})
        r=self.row();self.assertEqual(r["latitude"],54.0);self.assertEqual(r["longitude"],-2.0);self.assertEqual(r["lastPosition"],"2026-09-17T12:10:00+00:00")
    def test_newer_packet_updates_same_category(self):
        app.upsert({"station":"PWTEST","kind":"status","packet_time_utc":"2026-09-17T12:00:00+00:00","received_at":"2026-09-17T12:00:01+00:00","cpu_load":10.0})
        app.upsert({"station":"PWTEST","kind":"status","packet_time_utc":"2026-09-17T12:01:00+00:00","received_at":"2026-09-17T12:01:01+00:00","cpu_load":20.0})
        r=self.row();self.assertEqual(r["cpuLoadPercent"],20.0);self.assertEqual(r["lastTechnicalStatus"],"2026-09-17T12:01:00+00:00")
    def test_categories_are_ordered_independently(self):
        app.upsert({"station":"PWTEST","kind":"position","packet_time_utc":"2026-09-17T12:10:00+00:00","received_at":"2026-09-17T12:10:01+00:00","latitude":54.0})
        app.upsert({"station":"PWTEST","kind":"pilotaware_heartbeat","packet_time_utc":"2026-09-17T12:05:00+00:00","received_at":"2026-09-17T12:10:02+00:00","pilotaware_version":"20260917"})
        r=self.row();self.assertEqual(r["lastPosition"],"2026-09-17T12:10:00+00:00");self.assertEqual(r["lastHeartbeat"],"2026-09-17T12:05:00+00:00");self.assertEqual(r["isPilotAware"],1)
    def test_large_future_timestamp_is_rejected_without_poisoning_state(self):
        self.assertFalse(app.upsert({"station":"PWTEST","kind":"position","received_at":"2026-09-17T12:45:32+00:00","packet_time_utc":"2026-09-18T00:37:17+00:00","latitude":50.7}))
        self.assertIsNone(self.row())
        self.assertTrue(app.upsert({"station":"PWTEST","kind":"position","received_at":"2026-09-17T12:46:00+00:00","packet_time_utc":"2026-09-17T12:45:59+00:00","latitude":54.0}))
        self.assertEqual(self.row()["latitude"],54.0)
    def test_small_future_clock_skew_is_accepted(self):
        self.assertTrue(app.upsert({"station":"PWTEST","kind":"position","received_at":"2026-09-17T12:45:00+00:00","packet_time_utc":"2026-09-17T12:49:59+00:00","latitude":54.0}))
        self.assertEqual(self.row()["lastPosition"],"2026-09-17T12:49:59+00:00")
    def test_malformed_packet_timestamp_is_rejected(self):
        self.assertFalse(app.upsert({"station":"PWTEST","kind":"status","received_at":"2026-09-17T12:45:00+00:00","packet_time_utc":"not-a-time","cpu_load":20.0}))
        self.assertIsNone(self.row())

if __name__=="__main__":unittest.main()
