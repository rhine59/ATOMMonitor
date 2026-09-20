import os,unittest
os.environ["ATOM_ADMIN_TOKEN"]="test-admin-token"
import admin_monitor as m

class AdminMonitorTests(unittest.TestCase):
    def setUp(self):self.client=m.app.test_client(); self.headers={"Authorization":"Bearer test-admin-token"}
    def test_health_is_public(self):self.assertEqual(self.client.get("/health").status_code,200)
    def test_admin_routes_require_token(self):
        for path in ("/api/v1/admin/summary","/api/v1/admin/containers","/api/v1/admin/events"):
            self.assertEqual(self.client.get(path).status_code,401)
        self.assertEqual(self.client.post("/api/v1/admin/api-scale",json={"replicas":2,"confirmed":True}).status_code,401)
    def test_scale_requires_explicit_confirmation(self):
        self.assertEqual(self.client.post("/api/v1/admin/api-scale",json={"replicas":2},headers=self.headers).status_code,400)
    def test_scale_rejects_invalid_type_before_control_service(self):
        self.assertEqual(self.client.post("/api/v1/admin/api-scale",json={"replicas":"2","confirmed":True},headers=self.headers).status_code,400)
    def test_confirmed_scale_is_forwarded(self):
        old=m.control_request; m.control_request=lambda path,payload:(200,{"requestedReplicas":payload["replicas"]})
        try:
            r=self.client.post("/api/v1/admin/api-scale",json={"replicas":3,"confirmed":True},headers={**self.headers,"X-ATOM-Admin-Actor":"ios-admin"})
            self.assertEqual(r.status_code,200); self.assertEqual(r.json["requestedReplicas"],3)
        finally:m.control_request=old

if __name__=="__main__":unittest.main()
