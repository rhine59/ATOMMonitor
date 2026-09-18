#!/usr/bin/env python3
"""Copy ATOM ground-station registry from SQLite to PostgreSQL without modifying SQLite."""
from __future__ import annotations
import os,sqlite3,sys,hashlib,json
import psycopg
from psycopg.rows import dict_row

SQLITE_PATH=os.getenv("ATOM_DB","/data/atommonitor.sqlite3")
PG_DB=os.getenv("POSTGRES_DB","atommonitor")
PG_USER=os.getenv("POSTGRES_USER","atommonitor")
PG_PASSWORD=os.getenv("POSTGRES_PASSWORD","")
PG_HOST=os.getenv("POSTGRES_HOST","postgres")
PG_PORT=int(os.getenv("POSTGRES_PORT","5432"))
COLUMNS=["id","name","isPilotAware","latitude","longitude","altitudeMetres","lastPosition","lastHeartbeat","lastTechnicalStatus","pilotAwareVersion","softwareVersion","cpuLoadPercent","ramUsedMB","ramTotalMB","cpuTemperatureC","ntpOffsetMS","ntpCorrectionPPM","frequencyCorrectionKHz","rfCorrectionPPM","signalQualityDB","voltageV","uptimeMinutes","lastSeen"]
SCHEMA="""CREATE TABLE IF NOT EXISTS stations(id TEXT PRIMARY KEY,name TEXT NOT NULL,isPilotAware INTEGER NOT NULL DEFAULT 0,latitude REAL,longitude REAL,altitudeMetres REAL,lastPosition TEXT,lastHeartbeat TEXT,lastTechnicalStatus TEXT,pilotAwareVersion TEXT,softwareVersion TEXT,cpuLoadPercent REAL,ramUsedMB REAL,ramTotalMB REAL,cpuTemperatureC REAL,ntpOffsetMS REAL,ntpCorrectionPPM REAL,frequencyCorrectionKHz REAL,rfCorrectionPPM REAL,signalQualityDB REAL,voltageV REAL,uptimeMinutes INTEGER,lastSeen TEXT NOT NULL)"""

def fingerprint(rows):
 normalized=[]
 for row in rows:
  d=dict(row)
  normalized.append({c:d.get(c,d.get(c.lower())) for c in COLUMNS})
 return hashlib.sha256(json.dumps(normalized,sort_keys=True,separators=(",",":"),default=str).encode()).hexdigest()

def counts(conn):
 total=conn.execute("SELECT COUNT(*) FROM stations").fetchone()[0]
 confirmed=conn.execute("SELECT COUNT(*) FROM stations WHERE isPilotAware=1").fetchone()[0]
 return total,confirmed

def main():
 if not PG_PASSWORD:
  raise SystemExit("POSTGRES_PASSWORD is not set")
 src=sqlite3.connect(f"file:{SQLITE_PATH}?mode=ro",uri=True);src.row_factory=sqlite3.Row
 source_counts=counts(src)
 rows=src.execute("SELECT "+",".join(COLUMNS)+" FROM stations ORDER BY id").fetchall()
 source_fingerprint=fingerprint(rows)
 with psycopg.connect(host=PG_HOST,port=PG_PORT,dbname=PG_DB,user=PG_USER,password=PG_PASSWORD,row_factory=dict_row) as dst:
  dst.execute(SCHEMA)
  existing=dst.execute("SELECT COUNT(*) AS n FROM stations").fetchone()["n"]
  if existing:
   raise SystemExit(f"Refusing migration: PostgreSQL stations table already contains {existing} rows")
  placeholders=",".join(["%s"]*len(COLUMNS))
  updates=",".join(f"{c}=EXCLUDED.{c}" for c in COLUMNS if c!="id")
  q=f"INSERT INTO stations ({','.join(COLUMNS)}) VALUES ({placeholders}) ON CONFLICT(id) DO UPDATE SET {updates}"
  for row in rows:dst.execute(q,[row[c] for c in COLUMNS])
  dst.commit()
  dest_total=dst.execute("SELECT COUNT(*) AS n FROM stations").fetchone()["n"]
  dest_confirmed=dst.execute("SELECT COUNT(*) AS n FROM stations WHERE isPilotAware=1").fetchone()["n"]
  dest_rows=dst.execute("SELECT * FROM stations ORDER BY id").fetchall()
  dest_fingerprint=fingerprint(dest_rows)
 src.close()
 print(f"SQLite source: total={source_counts[0]} confirmed={source_counts[1]}")
 print(f"PostgreSQL destination: total={dest_total} confirmed={dest_confirmed}")
 print(f"SQLite fingerprint: {source_fingerprint}")
 print(f"PostgreSQL fingerprint: {dest_fingerprint}")
 if source_counts!=(dest_total,dest_confirmed) or source_fingerprint!=dest_fingerprint:
  print("MIGRATION CHECK: FAIL",file=sys.stderr);return 1
 print("MIGRATION CHECK: PASS")
 return 0

if __name__=="__main__":raise SystemExit(main())
