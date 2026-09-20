#!/usr/bin/env python3
"""Restricted infrastructure administration API for ATOM Monitor."""
from __future__ import annotations
import hmac, json, os, socket, urllib.error, urllib.request
from urllib.parse import quote
from flask import Flask, jsonify, request

app=Flask(__name__)
ADMIN_TOKEN=os.getenv("ATOM_ADMIN_TOKEN","")
DOCKER_SOCKET=os.getenv("DOCKER_SOCKET","/var/run/docker.sock")
PROJECT=os.getenv("COMPOSE_PROJECT_NAME","server")
CONTROL_URL=os.getenv("ATOM_ADMIN_CONTROL_URL","http://atom-admin-control:8091")
CONTROL_TOKEN=os.getenv("ATOM_ADMIN_CONTROL_TOKEN","")
ALLOWED_SERVICES=("postgres","atom-api","atom-lb","ogn-station-probe")

def authorized():
    supplied=request.headers.get("Authorization","")
    expected=f"Bearer {ADMIN_TOKEN}" if ADMIN_TOKEN else ""
    return bool(expected) and hmac.compare_digest(supplied,expected)

def docker_get(path):
    s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM); s.settimeout(5)
    try:
        s.connect(DOCKER_SOCKET)
        s.sendall(f"GET {path} HTTP/1.1\r\nHost: docker\r\nConnection: close\r\n\r\n".encode())
        chunks=[]
        while True:
            b=s.recv(65536)
            if not b: break
            chunks.append(b)
    finally:s.close()
    raw=b"".join(chunks); head,body=raw.split(b"\r\n\r\n",1)
    status=int(head.split(b" ",2)[1])
    if status != 200: raise RuntimeError(f"Docker API HTTP {status}")
    if b"transfer-encoding: chunked" in head.lower():
        out=b""
        while body:
            line,body=body.split(b"\r\n",1); n=int(line.split(b";",1)[0],16)
            if n==0: break
            out+=body[:n]; body=body[n+2:]
        body=out
    return json.loads(body)

def service_name(c): return (c.get("Labels") or {}).get("com.docker.compose.service")
def allowed(c): return (c.get("Labels") or {}).get("com.docker.compose.project")==PROJECT and service_name(c) in ALLOWED_SERVICES
def health(c):
    status=c.get("Status","")
    if "(healthy)" in status:return "healthy"
    if "(unhealthy)" in status:return "unhealthy"
    if "(health: starting)" in status:return "starting"
    return c.get("State","unknown")

def container_stats(cid):
    d=docker_get(f"/containers/{quote(cid,safe='')}/stats?stream=false")
    cpu=d.get("cpu_stats") or {}; pre=d.get("precpu_stats") or {}
    cpu_delta=(cpu.get("cpu_usage") or {}).get("total_usage",0)-(pre.get("cpu_usage") or {}).get("total_usage",0)
    sys_delta=cpu.get("system_cpu_usage",0)-pre.get("system_cpu_usage",0)
    ncpu=cpu.get("online_cpus") or len((cpu.get("cpu_usage") or {}).get("percpu_usage") or []) or 1
    mem=d.get("memory_stats") or {}; usage=mem.get("usage",0); limit=mem.get("limit",0); nets=d.get("networks") or {}
    return {"cpuPercent":round(cpu_delta/sys_delta*ncpu*100.0,2) if cpu_delta>0 and sys_delta>0 else 0.0,
            "memoryUsedBytes":usage,"memoryLimitBytes":limit,"memoryPercent":round(usage/limit*100.0,2) if limit else None,
            "networkRxBytes":sum(v.get("rx_bytes",0) for v in nets.values()),"networkTxBytes":sum(v.get("tx_bytes",0) for v in nets.values())}

def snapshot():
    containers=[c for c in docker_get("/containers/json?all=1") if allowed(c)]; rows=[]
    for c in containers:
        row={"service":service_name(c),"name":(c.get("Names") or [""])[0].lstrip("/"),"image":c.get("Image"),
             "state":c.get("State"),"health":health(c),"status":c.get("Status")}
        if c.get("State")=="running":
            try:row.update(container_stats(c["Id"]))
            except Exception:app.logger.exception("stats unavailable for %s",row["name"])
        rows.append(row)
    info=docker_get("/info"); api=[r for r in rows if r["service"]=="atom-api"]
    return {"status":"ok","scope":"atommonitor","apiReplicas":{"running":sum(r["state"]=="running" for r in api),"healthy":sum(r["health"]=="healthy" for r in api)},
            "services":{s:{"containers":sum(r["service"]==s for r in rows),"running":sum(r["service"]==s and r["state"]=="running" for r in rows),"healthy":sum(r["service"]==s and r["health"]=="healthy" for r in rows)} for s in ALLOWED_SERVICES},
            "host":{"cpuCount":info.get("NCPU"),"memoryTotalBytes":info.get("MemTotal"),"dockerContainers":info.get("Containers"),"dockerContainersRunning":info.get("ContainersRunning")},
            "containers":sorted(rows,key=lambda x:(x["service"],x["name"]))}

def control_request(path,payload=None):
    data=None if payload is None else json.dumps(payload).encode()
    req=urllib.request.Request(CONTROL_URL+path,data=data,method="GET" if data is None else "POST",
        headers={"Authorization":f"Bearer {CONTROL_TOKEN}","Content-Type":"application/json"})
    try:
        with urllib.request.urlopen(req,timeout=70) as r:return r.status,json.loads(r.read())
    except urllib.error.HTTPError as e:
        try:body=json.loads(e.read())
        except Exception:body={"error":"control request failed"}
        return e.code,body

@app.get("/health")
def health_endpoint():return jsonify({"status":"ok","service":"atommonitor-admin-monitor"})
@app.get("/api/v1/admin/summary")
def summary():
    if not authorized():return jsonify({"error":"unauthorized"}),401
    try:return jsonify(snapshot())
    except Exception:app.logger.exception("admin monitoring failed"); return jsonify({"error":"monitoring unavailable"}),503
@app.get("/api/v1/admin/containers")
def containers():
    if not authorized():return jsonify({"error":"unauthorized"}),401
    try:return jsonify(snapshot()["containers"])
    except Exception:app.logger.exception("admin monitoring failed"); return jsonify({"error":"monitoring unavailable"}),503
@app.get("/api/v1/admin/events")
def events():
    if not authorized():return jsonify({"error":"unauthorized"}),401
    code,body=control_request("/events"); return jsonify(body),code
@app.post("/api/v1/admin/api-scale")
def api_scale():
    if not authorized():return jsonify({"error":"unauthorized"}),401
    body=request.get_json(silent=True) or {}
    if body.get("confirmed") is not True:return jsonify({"error":"confirmation required"}),400
    replicas=body.get("replicas")
    if isinstance(replicas,bool) or not isinstance(replicas,int):return jsonify({"error":"replicas must be an integer"}),400
    code,result=control_request("/scale",{"replicas":replicas,"actor":request.headers.get("X-ATOM-Admin-Actor","admin")[:80]})
    return jsonify(result),code

if __name__=="__main__":app.run(host="0.0.0.0",port=int(os.getenv("PORT","8090")))
