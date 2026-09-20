import os,unittest
os.environ["ATOM_ADMIN_TOKEN"]="test-admin-token"
import admin_monitor as m

class AdminMonitorTests(unittest.TestCase):
    def setUp(self): self.client=m.app.test_client()
    def test_health_is_public_and_contains_no_metrics(self):
        r=self.client.get("/health"); self.assertEqual(r.status_code,200)
        self.assertEqual(r.json["service"],"atommonitor-admin-monitor")
    def test_summary_requires_admin_token(self):
        self.assertEqual(self.client.get("/api/v1/admin/summary").status_code,401)
        self.assertEqual(self.client.get("/api/v1/admin/summary",headers={"Authorization":"Bearer wrong"}).status_code,401)
    def test_containers_requires_admin_token(self):
        self.assertEqual(self.client.get("/api/v1/admin/containers").status_code,401)
    def test_summary_filters_to_allowlisted_project_services(self):
        old=m.docker_get
        def fake(path):
            if path.startswith("/containers/json"):
                return [
                    {"Id":"1","Names":["/server-atom-api-1"],"Image":"atom-api","State":"running","Status":"Up 1m (healthy)","Labels":{"com.docker.compose.project":"server","com.docker.compose.service":"atom-api"}},
                    {"Id":"2","Names":["/other"],"Image":"secret","State":"running","Status":"Up 1m","Labels":{"com.docker.compose.project":"other","com.docker.compose.service":"secret"}},
                ]
            if path.startswith("/containers/1/stats"):
                return {"cpu_stats":{"cpu_usage":{"total_usage":20},"system_cpu_usage":100,"online_cpus":2},"precpu_stats":{"cpu_usage":{"total_usage":10},"system_cpu_usage":50},"memory_stats":{"usage":100,"limit":1000},"networks":{"eth0":{"rx_bytes":10,"tx_bytes":20}}}
            if path=="/info": return {"NCPU":4,"MemTotal":10000,"Containers":9,"ContainersRunning":8}
            raise AssertionError(path)
        m.docker_get=fake
        try:
            r=self.client.get("/api/v1/admin/summary",headers={"Authorization":"Bearer test-admin-token"})
            self.assertEqual(r.status_code,200); self.assertEqual(len(r.json["containers"]),1)
            self.assertEqual(r.json["containers"][0]["service"],"atom-api")
            self.assertEqual(r.json["apiReplicas"]["healthy"],1)
        finally:m.docker_get=old

if __name__=="__main__": unittest.main()
