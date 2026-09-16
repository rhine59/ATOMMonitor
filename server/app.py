#!/usr/bin/env python3
"""Persistent ATOM ground-station registry/API. No aircraft data is accepted or stored."""
from __future__ import annotations
import os,sqlite3
from datetime import datetime,timezone
from flask import Flask,jsonify,request
DB_PATH=os.getenv("ATOM_DB","/data/atommonitor.sqlite3"); app=Flask(__name__)
def db():
 os.makedirs(os.path.dirname(DB_PATH),exist_ok=True);c=sqlite3.connect(DB_PATH);c.row_factory=sqlite3.Row
 c.execute("""CREATE TABLE IF NOT EXISTS stations(id TEXT PRIMARY KEY,name TEXT NOT NULL,isPilotAware INTEGER NOT NULL DEFAULT 0,latitude REAL,longitude REAL,altitudeMetres REAL,lastPosition TEXT,lastHeartbeat TEXT,lastTechnicalStatus TEXT,pilotAwareVersion TEXT,softwareVersion TEXT,cpuLoadPercent REAL,ramUsedMB REAL,ramTotalMB REAL,cpuTemperatureC REAL,ntpOffsetMS REAL,ntpCorrectionPPM REAL,frequencyCorrectionKHz REAL,rfCorrectionPPM REAL,signalQualityDB REAL,voltageV REAL,uptimeMinutes INTEGER,lastSeen TEXT NOT NULL)""")
 cols={r[1] for r in c.execute("PRAGMA table_info(stations)")}
 if "isPilotAware" not in cols:c.execute("ALTER TABLE stations ADD COLUMN isPilotAware INTEGER NOT NULL DEFAULT 0")
 c.commit();return c
def upsert(o):
 station=o.get("station");kind=o.get("kind")
 if not station or kind not in {"position","status","pilotaware_heartbeat"}:return False
 now=o.get("received_at") or datetime.now(timezone.utc).isoformat();v={"id":station,"name":station,"lastSeen":now}
 mp={"latitude":"latitude","longitude":"longitude","altitude_m":"altitudeMetres","software_version":"softwareVersion","cpu_load":"cpuLoadPercent","ram_used_mb":"ramUsedMB","ram_total_mb":"ramTotalMB","temperature_c":"cpuTemperatureC","ntp_offset_ms":"ntpOffsetMS","ntp_correction_ppm":"ntpCorrectionPPM","rf_correction_ppm":"rfCorrectionPPM","rf_quality_db":"signalQualityDB","voltage_v":"voltageV","uptime_minutes":"uptimeMinutes","pilotaware_version":"pilotAwareVersion"}
 for s,d in mp.items():
  if o.get(s) is not None:v[d]=o[s]
 when=o.get("packet_time_utc") or now
 if kind=="position":v["lastPosition"]=when
 elif kind=="status":v["lastTechnicalStatus"]=when
 else:v.update(lastHeartbeat=when,isPilotAware=1)
 cols=list(v);updates=','.join(f'{x}=excluded.{x}' for x in cols if x not in {'id','name'})
 with db() as c:c.execute(f"INSERT INTO stations ({','.join(cols)}) VALUES ({','.join('?'*len(cols))}) ON CONFLICT(id) DO UPDATE SET {updates}",[v[x] for x in cols])
 return True
def health_for(r):
 if not r["lastHeartbeat"]:return "unknown"
 try:
  dt=datetime.fromisoformat(r["lastHeartbeat"].replace('Z','+00:00'));age=(datetime.now(timezone.utc)-dt).total_seconds()
  return "healthy" if age<=420 else "warning" if age<=900 else "noRecentHeartbeat"
 except Exception:return "unknown"
def row_json(r):d=dict(r);d["health"]=health_for(r);return d
@app.get('/health')
def health():
 with db() as c:n=c.execute("SELECT COUNT(*) FROM stations WHERE isPilotAware=1").fetchone()[0]
 return jsonify({"status":"ok","confirmedStations":n})
@app.post('/api/v1/observations')
def observation():
 if not upsert(request.get_json(silent=True) or {}):return jsonify({"error":"invalid ground-station observation"}),400
 return jsonify({"status":"accepted"}),202
@app.get('/api/v1/stations')
def stations():
 with db() as c:rows=c.execute("SELECT * FROM stations WHERE isPilotAware=1 ORDER BY name COLLATE NOCASE").fetchall()
 return jsonify([row_json(r) for r in rows])
@app.get('/api/v1/stations/<station_id>')
def station(station_id):
 with db() as c:r=c.execute("SELECT * FROM stations WHERE id=? AND isPilotAware=1",(station_id,)).fetchone()
 return (jsonify(row_json(r)),200) if r else (jsonify({"error":"not found"}),404)
if __name__=='__main__':app.run(host='0.0.0.0',port=int(os.getenv('PORT','8080')))
