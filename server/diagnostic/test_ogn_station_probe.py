import unittest
from ogn_station_probe import parse_receiver_packet

class ReceiverPacketTests(unittest.TestCase):
    def test_ognsdr_position(self):
        p=parse_receiver_packet("PWFirefly>OGNSDR,TCPIP*,qAC,GLIDERN1:/113515h5047.70NI00311.98W&/A=000525")
        self.assertEqual(p.kind,"position");self.assertAlmostEqual(p.latitude,50.795,places=4);self.assertAlmostEqual(p.longitude,-3.1996667,places=4);self.assertAlmostEqual(p.altitude_m,160.0,places=1)
    def test_ognsdr_health(self):
        p=parse_receiver_packet("PWArnold>OGNSDR,TCPIP*,qAC,GLIDERN3:>114610h v0.3.2.ARM CPU:1.2 RAM:414.4/971.1MB NTP:0.8ms/-1.6ppm +56.9C 0/0Acfts[1h] RF:+35+0.0ppm/+0.07dB")
        self.assertEqual(p.kind,"status");self.assertEqual(p.software_version,"0.3.2.ARM");self.assertEqual(p.cpu_load,1.2);self.assertEqual(p.ram_used_mb,414.4);self.assertEqual(p.ntp_offset_ms,0.8);self.assertEqual(p.temperature_c,56.9)
    def test_pilotaware_heartbeat(self):
        p=parse_receiver_packet("PWFirefly>APRS,TCPIP*,qAC,GLIDERN1:>114140h v20260707 OGN-R/PilotAware")
        self.assertIsNotNone(p);self.assertEqual(p.station,"PWFirefly");self.assertEqual(p.kind,"pilotaware_heartbeat");self.assertEqual(p.tocall,"APRS");self.assertEqual(p.pilotaware_version,"20260707")
    def test_generic_aprs_status_is_not_atom(self):
        self.assertIsNone(parse_receiver_packet("PWExample>APRS,TCPIP*,qAC,GLIDERN1:>114140h v20260707 SomethingElse"))
    def test_aircraft_packet_is_discarded(self):
        self.assertIsNone(parse_receiver_packet("ICA3836BC>OGFLR,qAS,LFLE:/100956h4533.58N/00558.45E'000/000/A=000964 !W85! id053836BC +020fpm"))
if __name__=="__main__":unittest.main()
