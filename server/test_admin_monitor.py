import os,tempfile,unittest
os.environ["ATOM_ADMIN_TOKEN"]="test-admin-token"
_temp=tempfile.TemporaryDirectory(); os.environ["ATOM_ADMIN_DEVICE_FILE"]=_temp.name+"/devices.json"
import admin_monitor as m

class AdminMonitorTests(unittest.TestCase):
    def setUp(self):self.client=m.app.test_client(); self.headers={"Authorization":"Bearer test-admin-token"}
    def test_health_is_public(self):self.assertEqual(self.client.get("/health").status_code,200)
    def test_local_pairing_issues_one_time_device_credential(self):
        page=self.client.get("/api/v1/admin/pair")
        self.assertEqual(page.status_code,200)
        code=next(iter(m.PAIRINGS))
        paired=self.client.post("/api/v1/admin/pair/exchange",json={"code":code,"deviceName":"Test phone"})
        self.assertEqual(paired.status_code,200); token=paired.json["deviceToken"]
        self.assertEqual(self.client.post("/api/v1/admin/pair/exchange",json={"code":code}).status_code,401)
        old=m.snapshot; m.snapshot=lambda:{"status":"ok","apiReplicas":{"running":2,"healthy":2},"containers":[]}
        try:self.assertEqual(self.client.get("/api/v1/admin/summary",headers={"Authorization":f"Bearer {token}"}).status_code,200)
        finally:m.snapshot=old
    def test_pairing_page_rejects_public_source(self):
        self.assertEqual(self.client.get("/api/v1/admin/pair",headers={"X-Forwarded-For":"203.0.113.10"}).status_code,403)
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
