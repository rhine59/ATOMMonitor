import os,tempfile,unittest
os.environ["ATOM_ADMIN_CONTROL_TOKEN"]="control-test"; os.environ["ATOM_SCALE_TIMEOUT_SECONDS"]="1"
import admin_control as c

class AdminControlTests(unittest.TestCase):
    def setUp(self):
        self.client=c.app.test_client(); self.headers={"Authorization":"Bearer control-test"}
        self.old_scale=c.scale_to; self.old_audit=c.AUDIT
        fd,c.AUDIT=tempfile.mkstemp(); os.close(fd)
    def tearDown(self):c.scale_to=self.old_scale; os.unlink(c.AUDIT); c.AUDIT=self.old_audit
    def test_auth_required(self):self.assertEqual(self.client.post("/scale",json={"replicas":2}).status_code,401)
    def test_bounds_and_types(self):
        for value in (0,5,True,"2",None):self.assertEqual(self.client.post("/scale",json={"replicas":value},headers=self.headers).status_code,400)
    def test_success_is_audited(self):
        c.scale_to=lambda target:(2,target,target)
        r=self.client.post("/scale",json={"replicas":3,"actor":"ios-admin"},headers=self.headers)
        self.assertEqual(r.status_code,200); self.assertEqual(r.json["healthyReplicas"],3)
        events=self.client.get("/events",headers=self.headers).json["events"]
        self.assertEqual(events[0]["result"],"succeeded"); self.assertEqual(events[0]["actor"],"ios-admin")
    def test_concurrent_operation_rejected(self):
        c.LOCK.acquire()
        try:self.assertEqual(self.client.post("/scale",json={"replicas":2},headers=self.headers).status_code,409)
        finally:c.LOCK.release()
    def test_audit_is_bounded(self):
        old=c.AUDIT_MAX_EVENTS; c.AUDIT_MAX_EVENTS=2
        try:
            for n in range(3):c.audit({"type":"test","number":n})
            self.assertEqual([e["number"] for e in reversed(c.recent_events())],[1,2])
        finally:c.AUDIT_MAX_EVENTS=old

if __name__=="__main__":unittest.main()
