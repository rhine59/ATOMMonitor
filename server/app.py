#!/usr/bin/env python3
"""Persistent ATOM ground-station registry/API. No aircraft data is accepted or stored."""
from __future__ import annotations
import hmac,os,sqlite3,smtplib
from contextlib import contextmanager

try:
 import psycopg
 from psycopg.rows import dict_row
except ImportError:
 psycopg=None
from email.message import EmailMessage
from datetime import datetime,timezone,timedelta
from flask import Flask,jsonify,request
DB_PATH=os.getenv("ATOM_DB","/data/atommonitor.sqlite3"); DATABASE_URL=os.getenv("ATOM_DATABASE_URL","").strip(); INGEST_TOKEN=os.getenv("ATOM_INGEST_TOKEN",""); app=Flask(__name__)
MAX_FUTURE_SKEW=timedelta(minutes=5)
FEEDBACK_TO_NAME=os.getenv("FEEDBACK_TO_NAME","Richard Hine")
FEEDBACK_TO_EMAIL=os.getenv("FEEDBACK_TO_EMAIL","")
SMTP_HOST=os.getenv("SMTP_HOST",""); SMTP_PORT=int(os.getenv("SMTP_PORT","587")); SMTP_USER=os.getenv("SMTP_USER",""); SMTP_PASSWORD=os.getenv("SMTP_PASSWORD","")
STATION_COLUMNS=["id","name","isPilotAware","latitude","longitude","altitudeMetres","lastPosition","lastHeartbeat","lastTechnicalStatus","pilotAwareVersion","softwareVersion","cpuLoadPercent","ramUsedMB","ramTotalMB","cpuTemperatureC","ntpOffsetMS","ntpCorrectionPPM","frequencyCorrectionKHz","rfCorrectionPPM","signalQualityDB","voltageV","uptimeMinutes","lastSeen"]
STATION_SCHEMA="""CREATE TABLE IF NOT EXISTS stations(id TEXT PRIMARY KEY,name TEXT NOT NULL,isPilotAware INTEGER NOT NULL DEFAULT 0,latitude REAL,longitude REAL,altitudeMetres REAL,lastPosition TEXT,lastHeartbeat TEXT,lastTechnicalStatus TEXT,pilotAwareVersion TEXT,softwareVersion TEXT,cpuLoadPercent REAL,ramUsedMB REAL,ramTotalMB REAL,cpuTemperatureC REAL,ntpOffsetMS REAL,ntpCorrectionPPM REAL,frequencyCorrectionKHz REAL,rfCorrectionPPM REAL,signalQualityDB REAL,voltageV REAL,uptimeMinutes INTEGER,lastSeen TEXT NOT NULL)"""
PG_COLUMN_MAP={x:x.lower() for x in STATION_COLUMNS}
def canonical_row(r):
 d=dict(r)
 if DATABASE_URL:return {x:d.get(PG_COLUMN_MAP[x]) for x in STATION_COLUMNS}
 return d
def backend():return "postgresql" if DATABASE_URL else "sqlite"
@contextmanager
def db():
 if DATABASE_URL:
  if psycopg is None:raise RuntimeError("psycopg is required for PostgreSQL")
  c=psycopg.connect(DATABASE_URL,row_factory=dict_row)
  try:
   c.execute(STATION_SCHEMA);c.commit();yield c
  finally:c.close()
 else:
  os.makedirs(os.path.dirname(DB_PATH),exist_ok=True);c=sqlite3.connect(DB_PATH);c.row_factory=sqlite3.Row
  try:
   c.execute(STATION_SCHEMA)
   cols={r[1] for r in c.execute("PRAGMA table_info(stations)")}
   if "isPilotAware" not in cols:c.execute("ALTER TABLE stations ADD COLUMN isPilotAware INTEGER NOT NULL DEFAULT 0")
   c.commit();yield c
  finally:c.close()
def sql(q):return q.replace("?", "%s") if DATABASE_URL else q
def parse_time(value):
 if not value:return None
 try:return datetime.fromisoformat(str(value).replace('Z','+00:00')).astimezone(timezone.utc)
 except (ValueError,TypeError):return None
def upsert(o):
 station=o.get("station");kind=o.get("kind")
 if not station or kind not in {"position","status","pilotaware_heartbeat"}:return False
 now=o.get("received_at") or datetime.now(timezone.utc).isoformat();received=parse_time(now)
 if not received:return False
 packet_value=o.get("packet_time_utc");incoming=parse_time(packet_value) if packet_value else received
 # A bad station/packet clock must never poison ordering for later legitimate observations.
 if not incoming or incoming > received + MAX_FUTURE_SKEW:return False
 when=packet_value if packet_value else now
 category={"position":"lastPosition","status":"lastTechnicalStatus","pilotaware_heartbeat":"lastHeartbeat"}[kind]
 with db() as c:
  existing=c.execute(sql("SELECT * FROM stations WHERE id=?"),(station,)).fetchone()
  if existing:
   existing=canonical_row(existing)
   current=parse_time(existing[category])
   if current and incoming < current:return True
  v={"id":station,"name":station,"lastSeen":now}
  mp={"latitude":"latitude","longitude":"longitude","altitude_m":"altitudeMetres","software_version":"softwareVersion","cpu_load":"cpuLoadPercent","ram_used_mb":"ramUsedMB","ram_total_mb":"ramTotalMB","temperature_c":"cpuTemperatureC","ntp_offset_ms":"ntpOffsetMS","ntp_correction_ppm":"ntpCorrectionPPM","rf_correction_ppm":"rfCorrectionPPM","rf_quality_db":"signalQualityDB","voltage_v":"voltageV","uptime_minutes":"uptimeMinutes","pilotaware_version":"pilotAwareVersion"}
  for s,d in mp.items():
   if o.get(s) is not None:v[d]=o[s]
  if kind=="position":v["lastPosition"]=when
  elif kind=="status":v["lastTechnicalStatus"]=when
  else:v.update(lastHeartbeat=when,isPilotAware=1)
  cols=list(v);updates=','.join(f'{x}=excluded.{x}' for x in cols if x not in {'id','name'})
  placeholders=",".join(["?"]*len(cols))
  c.execute(sql(f"INSERT INTO stations ({','.join(cols)}) VALUES ({placeholders}) ON CONFLICT(id) DO UPDATE SET {updates}"),[v[x] for x in cols])
 return True
def health_for(r):
 if not r["lastHeartbeat"]:return "unknown"
 try:
  dt=datetime.fromisoformat(r["lastHeartbeat"].replace('Z','+00:00'));age=(datetime.now(timezone.utc)-dt).total_seconds()
  return "healthy" if age<=420 else "warning" if age<=900 else "noRecentHeartbeat"
 except Exception:return "unknown"
def row_json(r):d=canonical_row(r);d["health"]=health_for(d);return d
@app.get('/health')
def health():return jsonify({"status":"ok","service":"atommonitor-api"})
@app.get('/ready')
def ready():
 try:
  with db() as c:c.execute("SELECT 1").fetchone();row=c.execute("SELECT COUNT(*) AS confirmed FROM stations WHERE isPilotAware=1").fetchone();n=row["confirmed"] if DATABASE_URL else row[0]
  return jsonify({"status":"ready","service":"atommonitor-api","database":"ok","databaseBackend":backend(),"confirmedStations":n})
 except Exception:
  app.logger.exception("readiness database check failed");return jsonify({"status":"not_ready","service":"atommonitor-api","database":"unavailable"}),503
@app.post('/api/v1/observations')
def observation():
 supplied=request.headers.get("Authorization","");expected=f"Bearer {INGEST_TOKEN}" if INGEST_TOKEN else ""
 if not expected or not hmac.compare_digest(supplied,expected):return jsonify({"error":"unauthorized"}),401
 if not upsert(request.get_json(silent=True) or {}):return jsonify({"error":"invalid ground-station observation"}),400
 return jsonify({"status":"accepted"}),202
@app.post('/api/v1/feedback')
def feedback():
 data=request.get_json(silent=True) or {}
 try: rating=int(data.get("rating",0))
 except (TypeError,ValueError): rating=0
 comments=str(data.get("comments","")).strip()
 platform=str(data.get("platform","Unknown")).strip()[:80]
 version=str(data.get("version","Unknown")).strip()[:80]
 os_version=str(data.get("osVersion","Unknown")).strip()[:120]
 if rating not in range(1,6):return jsonify({"error":"rating must be 1 to 5"}),400
 if len(comments)>4000:return jsonify({"error":"comments too long"}),400
 if not all([FEEDBACK_TO_EMAIL,SMTP_HOST,SMTP_USER,SMTP_PASSWORD]):
  app.logger.error("feedback mail is not configured");return jsonify({"error":"feedback service unavailable"}),503
 msg=EmailMessage()
 msg["Subject"]=f"ATOM Monitor feedback - {rating}/5 stars"
 msg["From"]=SMTP_USER
 msg["To"]=FEEDBACK_TO_EMAIL
 msg.set_content(f"ATOM Monitor feedback\n\nRating: {rating}/5\nPlatform: {platform}\nApp version: {version}\nOS: {os_version}\n\nComments / suggestions:\n{comments or '(none)'}\n")
 try:
  with smtplib.SMTP(SMTP_HOST,SMTP_PORT,timeout=15) as smtp:
   smtp.starttls();smtp.login(SMTP_USER,SMTP_PASSWORD);smtp.send_message(msg)
 except Exception:
  app.logger.exception("feedback email failed");return jsonify({"error":"unable to send feedback"}),502
 return jsonify({"status":"sent","recipient":FEEDBACK_TO_NAME}),202
@app.get('/api/v1/stations')
def stations():
 with db() as c:rows=c.execute("SELECT * FROM stations WHERE isPilotAware=1 ORDER BY lower(name)").fetchall()
 return jsonify([row_json(r) for r in rows])
@app.get('/api/v1/stations/<station_id>')
def station(station_id):
 with db() as c:r=c.execute(sql("SELECT * FROM stations WHERE id=? AND isPilotAware=1"),(station_id,)).fetchone()
 return (jsonify(row_json(r)),200) if r else (jsonify({"error":"not found"}),404)
if __name__=='__main__':app.run(host='0.0.0.0',port=int(os.getenv('PORT','8080')))
