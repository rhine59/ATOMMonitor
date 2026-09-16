#!/usr/bin/env python3
"""ATOM Monitor persistent station registry and REST API.

Consumes only parsed ATOM ground-station observations from stdin, persists the
latest station state in SQLite, and exposes it to the iPhone app. No aircraft
identity, position, movement or track data is accepted or stored.
"""
from __future__ import annotations
import json, os, sqlite3, sys, threading
from datetime import datetime, timezone
from flask import Flask, jsonify

DB_PATH=os.getenv("ATOM_DB","/data/atommonitor.sqlite3")
app=Flask(__name__)

def db():
    os.makedirs(os.path.dirname(DB_PATH),exist_ok=True)
    c=sqlite3.connect(DB_PATH); c.row_factory=sqlite3.Row
    c.execute("""CREATE TABLE IF NOT EXISTS stations(
      id TEXT PRIMARY KEY,name TEXT NOT NULL,latitude REAL,longitude REAL,altitudeMetres REAL,
      lastPosition TEXT,lastHeartbeat TEXT,lastTechnicalStatus TEXT,pilotAwareVersion TEXT,softwareVersion TEXT,
      cpuLoadPercent REAL,ramUsedMB REAL,ramTotalMB REAL,cpuTemperatureC REAL,ntpOffsetMS REAL,
      ntpCorrectionPPM REAL,frequencyCorrectionKHz REAL,rfCorrectionPPM REAL,signalQualityDB REAL,
      voltageV REAL,uptimeMinutes INTEGER,lastSeen TEXT NOT NULL)"""); c.commit(); return c

def upsert(o):
    station=o.get("station"); kind=o.get("kind")
    if not station or kind not in {"position","status","pilotaware_heartbeat"}: return
    now=o.get("received_at") or datetime.now(timezone.utc).isoformat()
    values={"id":station,"name":station,"lastSeen":now}
    mapping={"latitude":"latitude","longitude":"longitude","altitude_m":"altitudeMetres","software_version":"softwareVersion","cpu_load":"cpuLoadPercent","ram_used_mb":"ramUsedMB","ram_total_mb":"ramTotalMB","temperature_c":"cpuTemperatureC","ntp_offset_ms":"ntpOffsetMS","ntp_correction_ppm":"ntpCorrectionPPM","rf_correction_ppm":"rfCorrectionPPM","rf_quality_db":"signalQualityDB","voltage_v":"voltageV","uptime_minutes":"uptimeMinutes","pilotaware_version":"pilotAwareVersion"}
    for src,dst in mapping.items():
        if o.get(src) is not None: values[dst]=o[src]
    if kind=="position": values["lastPosition"]=o.get("packet_time_utc") or now
    elif kind=="status": values["lastTechnicalStatus"]=o.get("packet_time_utc") or now
    else: values["lastHeartbeat"]=o.get("packet_time_utc") or now
    cols=list(values); placeholders=','.join('?'*len(cols)); updates=','.join(f'{x}=excluded.{x}' for x in cols if x not in {'id','name'})
    with db() as c: c.execute(f"INSERT INTO stations ({','.join(cols)}) VALUES ({placeholders}) ON CONFLICT(id) DO UPDATE SET {updates}",[values[x] for x in cols])

def row_json(r):
    d=dict(r); d["health"]="unknown"  # iPhone/server health thresholds will be finalised from measured cadence.
    return d

@app.get('/health')
def health(): return jsonify({"status":"ok"})
@app.get('/api/v1/stations')
def stations():
    with db() as c: return jsonify([row_json(r) for r in c.execute("SELECT * FROM stations ORDER BY name COLLATE NOCASE")])
@app.get('/api/v1/stations/<station_id>')
def station(station_id):
    with db() as c: r=c.execute("SELECT * FROM stations WHERE id=?",(station_id,)).fetchone()
    return (jsonify(row_json(r)),200) if r else (jsonify({"error":"not found"}),404)

def consume_stdin():
    for line in sys.stdin:
        try: upsert(json.loads(line))
        except Exception as e: print(f"registry input error: {e}",file=sys.stderr,flush=True)

if __name__=='__main__':
    threading.Thread(target=consume_stdin,daemon=True).start(); app.run(host='0.0.0.0',port=int(os.getenv('PORT','8080')))
