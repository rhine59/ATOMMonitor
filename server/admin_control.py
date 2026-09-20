#!/usr/bin/env python3
"""Private, allow-listed Docker control boundary for atom-api scaling only."""
from __future__ import annotations
import datetime as dt, hmac, json, os, socket, threading, time
from urllib.parse import quote
from flask import Flask, jsonify, request

app=Flask(__name__)
TOKEN=os.getenv("ATOM_ADMIN_CONTROL_TOKEN","")
SOCKET=os.getenv("DOCKER_SOCKET","/var/run/docker.sock")
PROJECT=os.getenv("COMPOSE_PROJECT_NAME","server")
MIN_REPLICAS=int(os.getenv("ATOM_API_MIN_REPLICAS","1")); MAX_REPLICAS=int(os.getenv("ATOM_API_MAX_REPLICAS","4"))
TIMEOUT=int(os.getenv("ATOM_SCALE_TIMEOUT_SECONDS","60")); AUDIT=os.getenv("ATOM_ADMIN_AUDIT_FILE","/audit/admin-events.jsonl")
LOCK=threading.Lock(); API_PREFIX=os.getenv("DOCKER_API_PREFIX","")
LAST_SCALE_AT=0.0; MIN_SCALE_INTERVAL=float(os.getenv("ATOM_SCALE_MIN_INTERVAL_SECONDS","2"))

def auth():
    expected=f"Bearer {TOKEN}" if TOKEN else ""
    return bool(expected) and hmac.compare_digest(request.headers.get("Authorization",""),expected)

def docker(method,path,body=None,ok=(200,201,204)):
    payload=b"" if body is None else json.dumps(body).encode(); s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM); s.settimeout(10)
    try:
        s.connect(SOCKET)
        headers=f"{method} {API_PREFIX}{path} HTTP/1.1\r\nHost: docker\r\nConnection: close\r\nContent-Length: {len(payload)}\r\nContent-Type: application/json\r\n\r\n".encode()
        s.sendall(headers+payload); chunks=[]
        while True:
            b=s.recv(65536)
            if not b:break
            chunks.append(b)
    finally:s.close()
    raw=b"".join(chunks); head,data=raw.split(b"\r\n\r\n",1); status=int(head.split(b" ",2)[1])
    if b"transfer-encoding: chunked" in head.lower():
        out=b""
        while data:
            line,data=data.split(b"\r\n",1); n=int(line.split(b";",1)[0],16)
            if n==0:break
            out+=data[:n]; data=data[n+2:]
        data=out
    parsed=json.loads(data) if data.strip() else None
    if status not in ok:raise RuntimeError(f"Docker API HTTP {status}: {parsed}")
    return parsed

def api_containers():
    filters=json.dumps({"label":[f"com.docker.compose.project={PROJECT}","com.docker.compose.service=atom-api"]})
    return docker("GET",f"/containers/json?all=1&filters={quote(filters,safe='')}")

def replica_number(c):
    labels=c.get("Labels") or {}
    try:return int(labels.get("com.docker.compose.container-number","0"))
    except ValueError:return 0

def inspect(cid):return docker("GET",f"/containers/{quote(cid,safe='')}/json")

def clone_config(source,number):
    cfg=dict(source["Config"]); host=dict(source["HostConfig"])
    for key in ("Hostname","Domainname"):cfg.pop(key,None)
    labels=dict(cfg.get("Labels") or {}); labels["com.docker.compose.container-number"]=str(number); cfg["Labels"]=labels
    for key in ("AutoRemove","Binds","Links","NetworkMode","PortBindings","RestartPolicy","LogConfig","Mounts"):
        if key in source["HostConfig"]:host[key]=source["HostConfig"][key]
    networking={"EndpointsConfig":{}}
    for network,endpoint in (source.get("NetworkSettings",{}).get("Networks") or {}).items():
        aliases=["atom-api",f"{PROJECT}-atom-api-{number}"]
        networking["EndpointsConfig"][network]={"Aliases":aliases}
    cfg["HostConfig"]=host; cfg["NetworkingConfig"]=networking
    return cfg

def state():
    cs=api_containers(); running=[c for c in cs if c.get("State")=="running"]
    healthy=[c for c in running if "(healthy)" in c.get("Status","")]
    return cs,len(running),len(healthy)

def audit(event):
    event={"timestamp":dt.datetime.now(dt.timezone.utc).isoformat(),**event}; os.makedirs(os.path.dirname(AUDIT),exist_ok=True)
    line=json.dumps(event,separators=(",",":"))
    with open(AUDIT,"a",encoding="utf-8") as f:f.write(line+"\n")

def recent_events(limit=100):
    try:
        with open(AUDIT,encoding="utf-8") as f:lines=f.readlines()[-limit:]
        return [json.loads(x) for x in reversed(lines)]
    except FileNotFoundError:return []

def wait_for(target):
    deadline=time.monotonic()+TIMEOUT
    while time.monotonic()<deadline:
        _,running,healthy=state()
        if running==target and healthy==target:return running,healthy
        time.sleep(1)
    _,running,healthy=state(); raise TimeoutError(f"timed out with {running} running and {healthy} healthy")

def scale_to(target):
    containers,running,_=state(); old=running
    if target>running:
        if not containers:raise RuntimeError("no existing atom-api container to clone")
        source=inspect(sorted(containers,key=replica_number)[0]["Id"]); used={replica_number(c) for c in containers}
        for number in [n for n in range(1,MAX_REPLICAS+1) if n not in used][:target-running]:
            created=docker("POST",f"/containers/create?name={quote(f'{PROJECT}-atom-api-{number}',safe='')}",clone_config(source,number),ok=(201,))
            docker("POST",f"/containers/{created['Id']}/start",ok=(204,304))
    elif target<running:
        victims=sorted([c for c in containers if c.get("State")=="running"],key=replica_number,reverse=True)[:running-target]
        for c in victims:
            docker("POST",f"/containers/{c['Id']}/stop?t=20",ok=(204,304)); docker("DELETE",f"/containers/{c['Id']}?v=1",ok=(204,))
    final_running,healthy=wait_for(target)
    return old,final_running,healthy

@app.get("/health")
def health():return jsonify({"status":"ok","service":"atommonitor-admin-control"})
@app.get("/events")
def events():
    if not auth():return jsonify({"error":"unauthorized"}),401
    return jsonify({"events":recent_events()})
@app.post("/scale")
def scale():
    global LAST_SCALE_AT
    if not auth():return jsonify({"error":"unauthorized"}),401
    body=request.get_json(silent=True) or {}; target=body.get("replicas"); actor=str(body.get("actor","admin"))[:80]
    if isinstance(target,bool) or not isinstance(target,int):return jsonify({"error":"replicas must be an integer"}),400
    if not MIN_REPLICAS<=target<=MAX_REPLICAS:return jsonify({"error":f"replicas must be between {MIN_REPLICAS} and {MAX_REPLICAS}"}),400
    if not LOCK.acquire(blocking=False):return jsonify({"error":"scale operation already in progress"}),409
    event={"type":"api-scale","actor":actor,"requestedReplicas":target}
    try:
        if time.monotonic()-LAST_SCALE_AT<MIN_SCALE_INTERVAL:return jsonify({"error":"scale requests are rate limited"}),429
        LAST_SCALE_AT=time.monotonic()
        old,running,healthy=scale_to(target); result={"status":"ok","previousReplicas":old,"requestedReplicas":target,"runningReplicas":running,"healthyReplicas":healthy}
        audit({**event,"previousReplicas":old,"result":"succeeded","runningReplicas":running,"healthyReplicas":healthy}); return jsonify(result)
    except Exception as exc:
        app.logger.exception("API scale failed"); audit({**event,"result":"failed","error":type(exc).__name__})
        return jsonify({"error":"scale operation failed","requestedReplicas":target}),503
    finally:LOCK.release()

if __name__=="__main__":app.run(host="0.0.0.0",port=int(os.getenv("PORT","8091")))
