import unittest
from ogn_station_probe import parse_receiver_packet


class ReceiverPacketTests(unittest.TestCase):
    def test_ognsdr_position(self):
        p = parse_receiver_packet("Barton>OGNSDR,TCPIP*,qAC,GLIDERN2:/233133h5145.94NI00111.49W&/A=000295")
        self.assertIsNotNone(p)
        self.assertEqual(p.station, "Barton")
        self.assertEqual(p.kind, "position")
        self.assertAlmostEqual(p.latitude, 51.7656667, places=4)
        self.assertAlmostEqual(p.longitude, -1.1915, places=4)
        self.assertAlmostEqual(p.altitude_m, 89.9, places=1)

    def test_ognsdr_health(self):
        p = parse_receiver_packet("Barton>OGNSDR,TCPIP*,qAC,GLIDERN2:>233133h v0.2.7.RPI-GPU CPU:1.0 RAM:204.3/970.5MB NTP:1.4ms/-4.6ppm +52.5C 1/1Acfts[1h] RF:+10+3.1ppm/+6.85dB")
        self.assertIsNotNone(p)
        self.assertEqual(p.station, "Barton")
        self.assertEqual(p.software_version, "0.2.7.RPI-GPU")
        self.assertEqual(p.cpu_load, 1.0)
        self.assertEqual(p.ram_used_mb, 204.3)
        self.assertEqual(p.ntp_offset_ms, 1.4)
        self.assertEqual(p.ntp_correction_ppm, -4.6)
        self.assertEqual(p.temperature_c, 52.5)
        self.assertEqual(p.rf_correction_ppm, 3.1)
        self.assertEqual(p.rf_quality_db, 6.85)

    def test_ognsxr_health(self):
        p = parse_receiver_packet("K2B9>OGNSXR,TCPIP*,qAC,GLIDERN0:>183602h vMB101-ESP32-OGNbase 3.8V 55/min 2/3Acfts[1h] 10sat time_synched 180_m_r_uptime")
        self.assertIsNotNone(p)
        self.assertEqual(p.tocall, "OGNSXR")
        self.assertEqual(p.software_version, "MB101-ESP32-OGNbase")
        self.assertEqual(p.voltage_v, 3.8)
        self.assertEqual(p.time_sync, "time_synched")
        self.assertEqual(p.uptime_minutes, 180)

    def test_aircraft_packet_is_discarded(self):
        p = parse_receiver_packet("ICA3836BC>OGFLR,qAS,LFLE:/100956h4533.58N/00558.45E'000/000/A=000964 !W85! id053836BC +020fpm")
        self.assertIsNone(p)


if __name__ == "__main__":
    unittest.main()
