#!/usr/bin/env python3
"""ATOM Monitor OGN receiver-status diagnostic probe.

Receive-only OGN/APRS diagnostic. Aircraft packets are never printed or persisted.
Discovery mode reports aggregate traffic counters and only prints packet text when
the source callsign itself matches the requested station/prefix.
"""
from __future__ import annotations
import argparse, json, re, socket, sys, time
from collections import Counter
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from typing import Optional

DEFAULT_HOST="aprs.glidernet.org"; DEFAULT_PORT=14580
HEADER_RE=re.compile(r"^(?P<src>[^>]+)>(?P<dst>[^,>:]+)(?P<path>(?:,[^:]*)?):(?P<body>.*)$")
POSITION_RE=re.compile(r"^(?P<name>[^>]+)>(?P<tocall>OGNSDR|OGNSXR),[^:]*:/(?P<time>\d{6})h(?P<latdeg>\d{2})(?P<latmin>\d{2}\.\d{2})(?P<lathem>[NS])[A-Z](?P<londeg>\d{3})(?P<lonmin>\d{2}\.\d{2})(?P<lonhem>[EW])[^/]*/A=(?P<altfeet>\d{6})")
STATUS_HEAD_RE=re.compile(r"^(?P<name>[^>]+)>(?P<tocall>OGNSDR|OGNSXR),[^:]*:>(?P<time>\d{6})h\s+(?P<body>.*)$")
CPU_RE=re.compile(r"\bCPU:(?P<v>[+-]?\d+(?:\.\d+)?)"); RAM_RE=re.compile(r"\bRAM:(?P<used>\d+(?:\.\d+)?)/(?P<total>\d+(?:\.\d+)?)MB")
NTP_RE=re.compile(r"\bNTP:(?P<offset>[+-]?\d+(?:\.\d+)?)ms/(?P<corr>[+-]?\d+(?:\.\d+)?)ppm"); TEMP_RE=re.compile(r"(?P<v>[+-]\d+(?:\.\d+)?)C\b")
RF_RE=re.compile(r"\bRF:(?P<body>\S+)"); RF_PPM_RE=re.compile(r"(?P<v>[+-]\d+(?:\.\d+)?)ppm"); RF_DB_RE=re.compile(r"/(?P<v>[+-]?\d+(?:\.\d+)?)dB")
VOLTAGE_RE=re.compile(r"\b(?P<v>\d+(?:\.\d+)?)V\b"); UPTIME_RE=re.compile(r"\b(?P<v>\d+)_m_(?:r_)?uptime\b"); TIME_SYNC_RE=re.compile(r"\b(time_synched|time_not_synched)\b")

@dataclass
class StationObservation:
    station:str; kind:str; received_at:str; tocall:str; packet_time_utc:Optional[str]=None
    latitude:Optional[float]=None; longitude:Optional[float]=None; altitude_m:Optional[float]=None; software_version:Optional[str]=None
    cpu_load:Optional[float]=None; ram_used_mb:Optional[float]=None; ram_total_mb:Optional[float]=None; ntp_offset_ms:Optional[float]=None
    ntp_correction_ppm:Optional[float]=None; temperature_c:Optional[float]=None; rf_correction_ppm:Optional[float]=None; rf_quality_db:Optional[float]=None
    voltage_v:Optional[float]=None; uptime_minutes:Optional[int]=None; time_sync:Optional[str]=None

def aprs_coord(d,m,h):
    v=float(d)+float(m)/60; return -v if h in ('S','W') else v
def packet_time(v):
    n=datetime.now(timezone.utc); return n.replace(hour=int(v[:2]),minute=int(v[2:4]),second=int(v[4:6]),microsecond=0).isoformat()
def parse_receiver_packet(line):
    received=datetime.now(timezone.utc).isoformat(); m=POSITION_RE.match(line)
    if m:
        return StationObservation(m['name'],'position',received,m['tocall'],packet_time(m['time']),aprs_coord(m['latdeg'],m['latmin'],m['lathem']),aprs_coord(m['londeg'],m['lonmin'],m['lonhem']),round(int(m['altfeet'])*.3048,1))
    m=STATUS_HEAD_RE.match(line)
    if not m:return None
    b=m['body']; o=StationObservation(m['name'],'status',received,m['tocall'],packet_time(m['time'])); first=b.split(maxsplit=1)[0] if b else ''
    if first.startswith('v'):o.software_version=first[1:]
    if x:=CPU_RE.search(b):o.cpu_load=float(x['v'])
    if x:=RAM_RE.search(b):o.ram_used_mb,o.ram_total_mb=float(x['used']),float(x['total'])
    if x:=NTP_RE.search(b):o.ntp_offset_ms,o.ntp_correction_ppm=float(x['offset']),float(x['corr'])
    if x:=TEMP_RE.search(b):o.temperature_c=float(x['v'])
    if x:=VOLTAGE_RE.search(b):o.voltage_v=float(x['v'])
    if x:=UPTIME_RE.search(b):o.uptime_minutes=int(x['v'])
    if x:=TIME_SYNC_RE.search(b):o.time_sync=x.group(1)
    if x:=RF_RE.search(b):
        r=x['body']
        if p:=RF_PPM_RE.search(r):o.rf_correction_ppm=float(p['v'])
        if q:=RF_DB_RE.search(r):o.rf_quality_db=float(q['v'])
    return o

def source_wanted(src,station,prefix):
    if station and src.casefold()!=station.casefold():return False
    if prefix and not src.casefold().startswith(prefix.casefold()):return False
    return bool(station or prefix)
def wanted(obs,station,prefix): return source_wanted(obs.station,station,prefix)
def effective_filter(args):
    if args.filter:return args.filter
    if args.station:return f"b/{args.station}"
    if args.prefix:return f"p/{args.prefix}"
    return None

def print_stats(args,started,last,total,comments,matched_sources,parsed,dests):
    now=time.monotonic()
    if args.discovery and now-last>=args.stats_interval:
        top=', '.join(f'{k}:{v}' for k,v in dests.most_common(8)) or 'none'
        print(f"STATS seconds={int(now-started)} packets={total} server_comments={comments} matching_sources={matched_sources} parsed_receiver_packets={parsed} top_destinations=[{top}]",file=sys.stderr,flush=True)
        return now
    return last

def run(args):
    while True:
      try:
        aprs_filter=effective_filter(args)
        print(f"Connecting to {args.host}:{args.port} …",file=sys.stderr,flush=True)
        with socket.create_connection((args.host,args.port),timeout=30) as sock:
          sock.settimeout(None); login=f"user {args.user} pass -1 vers ATOMMonitor 0.3"
          if aprs_filter:login+=f" filter {aprs_filter}"
          sock.sendall((login+'\n').encode('ascii')); print("Connected read-only; aircraft packets will be discarded.",file=sys.stderr,flush=True)
          if aprs_filter:print(f"APRS server filter: {aprs_filter}",file=sys.stderr,flush=True)
          total=comments=matched_sources=parsed=0; dests=Counter(); started=time.monotonic(); last=started
          with sock.makefile('r',encoding='utf-8',errors='replace',newline='\n') as stream:
            for raw in stream:
              line=raw.rstrip('\r\n')
              if not line:continue
              if line.startswith('#'):
                comments+=1
                if args.discovery: print(f"SERVER {line}",file=sys.stderr,flush=True)
                last=print_stats(args,started,last,total,comments,matched_sources,parsed,dests)
                continue
              total+=1; h=HEADER_RE.match(line)
              if h:
                dests[h['dst']]+=1
                if args.discovery and source_wanted(h['src'],args.station,args.prefix):
                  matched_sources+=1
                  print(f"CANDIDATE source={h['src']} destination={h['dst']} packet={line}",flush=True)
              obs=parse_receiver_packet(line)
              if obs and wanted(obs,args.station,args.prefix):
                parsed+=1
                if not args.discovery: print(json.dumps(asdict(obs),separators=(',',':')),flush=True)
              last=print_stats(args,started,last,total,comments,matched_sources,parsed,dests)
      except KeyboardInterrupt:return
      except Exception as e:
        print(f"OGN connection error: {e}; retrying in {args.retry}s",file=sys.stderr,flush=True);time.sleep(args.retry)

def main():
    p=argparse.ArgumentParser(description='Observe OGN ground-station status only'); p.add_argument('--host',default=DEFAULT_HOST);p.add_argument('--port',type=int,default=DEFAULT_PORT);p.add_argument('--user',default='ATOMMON');p.add_argument('--station');p.add_argument('--prefix');p.add_argument('--filter');p.add_argument('--retry',type=int,default=10);p.add_argument('--discovery',action='store_true',help='Show safe aggregate diagnostics and matching source packets');p.add_argument('--stats-interval',type=int,default=30);run(p.parse_args())
if __name__=='__main__':main()
