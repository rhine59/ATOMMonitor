#!/usr/bin/env python3
"""Receive-only ATOM ground-station collector. Aircraft packets are discarded."""
from __future__ import annotations
import argparse,json,os,re,socket,sys,time,urllib.request
from collections import Counter
from dataclasses import asdict,dataclass
from datetime import datetime,timezone
from typing import Optional
DEFAULT_HOST="aprs.glidernet.org";DEFAULT_PORT=14580
HEADER_RE=re.compile(r"^(?P<src>[^>]+)>(?P<dst>[^,>:]+)(?P<path>(?:,[^:]*)?):(?P<body>.*)$")
POSITION_RE=re.compile(r"^(?P<name>[^>]+)>(?P<tocall>OGNSDR|OGNSXR),[^:]*:/(?P<time>\d{6})h(?P<latdeg>\d{2})(?P<latmin>\d{2}\.\d{2})(?P<lathem>[NS])[A-Z](?P<londeg>\d{3})(?P<lonmin>\d{2}\.\d{2})(?P<lonhem>[EW])[^/]*/A=(?P<altfeet>\d{6})")
STATUS_RE=re.compile(r"^(?P<name>[^>]+)>(?P<tocall>OGNSDR|OGNSXR),[^:]*:>(?P<time>\d{6})h\s+(?P<body>.*)$")
PA_RE=re.compile(r"^(?P<name>[^>]+)>APRS,[^:]*:>(?P<time>\d{6})h\s+v(?P<version>\S+)\s+OGN-R/PilotAware(?:\s.*)?$")
CPU_RE=re.compile(r"\bCPU:(?P<v>[+-]?\d+(?:\.\d+)?)");RAM_RE=re.compile(r"\bRAM:(?P<u>\d+(?:\.\d+)?)/(?P<t>\d+(?:\.\d+)?)MB");NTP_RE=re.compile(r"\bNTP:(?P<o>[+-]?\d+(?:\.\d+)?)ms/(?P<c>[+-]?\d+(?:\.\d+)?)ppm");TEMP_RE=re.compile(r"(?P<v>[+-]\d+(?:\.\d+)?)C\b");RF_RE=re.compile(r"\bRF:(?P<body>\S+)");PPM_RE=re.compile(r"(?P<v>[+-]\d+(?:\.\d+)?)ppm");DB_RE=re.compile(r"/(?P<v>[+-]?\d+(?:\.\d+)?)dB");V_RE=re.compile(r"\b(?P<v>\d+(?:\.\d+)?)V\b");UP_RE=re.compile(r"\b(?P<v>\d+)_m_(?:r_)?uptime\b")
@dataclass
class StationObservation:
 station:str;kind:str;received_at:str;tocall:str;packet_time_utc:Optional[str]=None;latitude:Optional[float]=None;longitude:Optional[float]=None;altitude_m:Optional[float]=None;software_version:Optional[str]=None;pilotaware_version:Optional[str]=None;cpu_load:Optional[float]=None;ram_used_mb:Optional[float]=None;ram_total_mb:Optional[float]=None;ntp_offset_ms:Optional[float]=None;ntp_correction_ppm:Optional[float]=None;temperature_c:Optional[float]=None;rf_correction_ppm:Optional[float]=None;rf_quality_db:Optional[float]=None;voltage_v:Optional[float]=None;uptime_minutes:Optional[int]=None
def coord(d,m,h):v=float(d)+float(m)/60;return -v if h in('S','W') else v
def ptime(v):
 n=datetime.now(timezone.utc);candidate=n.replace(hour=int(v[:2]),minute=int(v[2:4]),second=int(v[4:6]),microsecond=0)
 if (candidate-n).total_seconds()>43200:candidate=candidate.replace(day=n.day)-__import__('datetime').timedelta(days=1)
 elif (n-candidate).total_seconds()>43200:candidate=candidate+__import__('datetime').timedelta(days=1)
 return candidate.isoformat()
def parse_receiver_packet(line):
 received=datetime.now(timezone.utc).isoformat();m=PA_RE.match(line)
 if m:return StationObservation(m['name'],'pilotaware_heartbeat',received,'APRS',ptime(m['time']),pilotaware_version=m['version'])
 m=POSITION_RE.match(line)
 if m:return StationObservation(m['name'],'position',received,m['tocall'],ptime(m['time']),coord(m['latdeg'],m['latmin'],m['lathem']),coord(m['londeg'],m['lonmin'],m['lonhem']),round(int(m['altfeet'])*.3048,1))
 m=STATUS_RE.match(line)
 if not m:return None
 b=m['body'];o=StationObservation(m['name'],'status',received,m['tocall'],ptime(m['time']));first=b.split(maxsplit=1)[0] if b else ''
 if first.startswith('v'):o.software_version=first[1:]
 if x:=CPU_RE.search(b):o.cpu_load=float(x['v'])
 if x:=RAM_RE.search(b):o.ram_used_mb,o.ram_total_mb=float(x['u']),float(x['t'])
 if x:=NTP_RE.search(b):o.ntp_offset_ms,o.ntp_correction_ppm=float(x['o']),float(x['c'])
 if x:=TEMP_RE.search(b):o.temperature_c=float(x['v'])
 if x:=V_RE.search(b):o.voltage_v=float(x['v'])
 if x:=UP_RE.search(b):o.uptime_minutes=int(x['v'])
 if x:=RF_RE.search(b):
  if p:=PPM_RE.search(x['body']):o.rf_correction_ppm=float(p['v'])
  if q:=DB_RE.search(x['body']):o.rf_quality_db=float(q['v'])
 return o
def touch_health(path):
 if not path:return
 with open(path,"w",encoding="ascii") as f:f.write(str(int(time.time())))
def wanted(src,a):return (not a.station or src.casefold()==a.station.casefold()) and (not a.prefix or src.casefold().startswith(a.prefix.casefold()))
def send(obs,url,token):
 if not url:return
 headers={'Content-Type':'application/json'}
 if token:headers['Authorization']=f'Bearer {token}'
 data=json.dumps(asdict(obs)).encode();req=urllib.request.Request(url,data=data,headers=headers,method='POST')
 try:urllib.request.urlopen(req,timeout=5).read()
 except Exception as e:print(f"API publish error: {e}",file=sys.stderr,flush=True)
def run(a):
 while True:
  try:
   filt=a.filter or (f"b/{a.station}" if a.station else f"p/{a.prefix}" if a.prefix else None);print(f"Connecting to {a.host}:{a.port} …",file=sys.stderr,flush=True)
   with socket.create_connection((a.host,a.port),timeout=30) as s:
    s.settimeout(None);touch_health(a.health_file);login=f"user {a.user} pass -1 vers ATOMMonitor 0.4"+(f" filter {filt}" if filt else '');s.sendall((login+'\n').encode());print("Connected read-only; aircraft packets will be discarded.",file=sys.stderr,flush=True)
    if filt:print(f"APRS server filter: {filt}",file=sys.stderr,flush=True)
    with s.makefile('r',encoding='utf-8',errors='replace') as stream:
     for raw in stream:
      touch_health(a.health_file)
      line=raw.rstrip('\r\n')
      if not line or line.startswith('#'):continue
      h=HEADER_RE.match(line)
      if a.discovery and h and wanted(h['src'],a):print(f"CANDIDATE source={h['src']} destination={h['dst']} packet={line}",flush=True)
      obs=parse_receiver_packet(line)
      if obs and wanted(obs.station,a):
       send(obs,a.api_url,a.api_token)
       if not a.discovery:print(json.dumps(asdict(obs),separators=(',',':')),flush=True)
  except KeyboardInterrupt:return
  except Exception as e:print(f"OGN connection error: {e}; retrying in {a.retry}s",file=sys.stderr,flush=True);time.sleep(a.retry)
def main():
 p=argparse.ArgumentParser();p.add_argument('--host',default=DEFAULT_HOST);p.add_argument('--port',type=int,default=DEFAULT_PORT);p.add_argument('--user',default='ATOMMON');p.add_argument('--station');p.add_argument('--prefix');p.add_argument('--filter');p.add_argument('--api-url');p.add_argument('--api-token',default=os.getenv('ATOM_INGEST_TOKEN'));p.add_argument('--retry',type=int,default=10);p.add_argument('--health-file',default=os.getenv('ATOM_COLLECTOR_HEALTH_FILE','/tmp/ogn-probe-health'));p.add_argument('--discovery',action='store_true');p.add_argument('--stats-interval',type=int,default=30);run(p.parse_args())
if __name__=='__main__':main()
