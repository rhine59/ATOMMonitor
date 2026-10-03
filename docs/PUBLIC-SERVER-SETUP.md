# Public DNS and HTTPS setup for ATOM Monitor

## Goal

Expose the ATOM Monitor REST API through a stable DNS name over HTTPS instead of configuring the iPhone with the Synology LAN address `192.168.1.99:8088`.

Target architecture:

    iPhone ATOM Monitor
        |
        | HTTPS 443
        v
    atom.<your-domain>
        |
        | DNS -> public WAN address
        v
    router / firewall
        |
        | TCP 443 only
        v
    Synology DSM reverse proxy
        |
        | HTTP on NAS loopback/LAN
        v
    http://127.0.0.1:8088
        |
        v
    atommonitor-api container :8080

The Docker API remains on host port 8088. Do not expose Docker port 8088 directly to the Internet. TLS terminates at the Synology reverse proxy and only HTTPS/443 is published externally.

## 1. Choose a DNS name

Use a hostname you control, for example:

    atom.example.net

Do not use the literal example hostname in production. If you already own a domain, create an `A` record for the ATOM hostname pointing to the site's current public IPv4 address. Add an `AAAA` record only if IPv6 is deliberately configured and firewalled.

If the ISP changes the public address, configure DDNS so the hostname follows it. Synology DSM can maintain supported DDNS providers, or the DNS provider's own update client/API can be used.

Verify externally:

    dig +short atom.example.net

The result should be the current public address.

## 2. Router/firewall

Forward inbound TCP port **443** to the Synology HTTPS/reverse-proxy service. Do not forward 8088 and do not publish PostgreSQL/SQLite or Docker management ports.

If the router supports firewall source restrictions and this service is intended for a limited audience, apply them where practical. If the API is to be broadly reachable, authentication/rate limiting should be added before treating it as an Internet production service; the current API is unauthenticated.

## 3. Obtain a trusted TLS certificate in DSM

In DSM, obtain/import a certificate for the chosen DNS hostname using **Control Panel -> Security -> Certificate**. A publicly trusted certificate (for example Let's Encrypt) is preferred for iPhone clients because no private CA profile is then required on the phone.

The certificate name must cover the exact hostname used by the app.

## 4. Configure DSM reverse proxy

In DSM's reverse-proxy configuration create a rule equivalent to:

    Description: ATOM Monitor API
    Source protocol: HTTPS
    Source hostname: atom.example.net
    Source port: 443
    Destination protocol: HTTP
    Destination hostname: 127.0.0.1
    Destination port: 8088

Assign the certificate for `atom.example.net` to this virtual host/service.

The backend remains HTTP because this hop stays on the NAS; the externally exposed connection is HTTPS.

## 5. Test from the LAN and Internet

First ensure the existing backend is healthy on the Synology:

    curl -s http://localhost:8088/health

Expected shape:

    {"confirmedStations":301,"status":"ok"}

Then test the DNS/TLS endpoint from a Mac:

    curl -i https://atom.example.net/health

and:

    curl -s https://atom.example.net/api/v1/stations | python3 -c 'import sys,json; print(len(json.load(sys.stdin)))'

Finally disable Wi-Fi on the iPhone and use **Settings -> Server -> Test Connection**. Testing over cellular proves that the result is not merely LAN DNS/NAT behaviour.

## 6. Configure the iPhone app

Open ATOM Monitor -> Settings -> Server.

Enter:

    https://atom.example.net/

`https://` is added automatically if the scheme is omitted. Tap **Test Connection**. A successful test calls `/health` and displays the service status and confirmed station count when supplied by the API.

Tap **Save** to persist the base URL. Saving immediately reloads stations using the newly configured endpoint. The setting is stored in app UserDefaults and survives app restarts.

The production preference is HTTPS DNS. Local HTTP addresses can still be used temporarily for LAN diagnosis while `NSAllowsLocalNetworking` remains enabled.

## 7. Apple transport security

The public endpoint should use HTTPS with a certificate trusted by iOS. This allows normal App Transport Security protection instead of adding a broad insecure-HTTP exception. The project retains local-network permission for development/LAN diagnostics, but the public service should not depend on that exception.

On a Mac, ATS problems can be investigated with:

    /usr/bin/nscurl --ats-diagnostics --verbose https://atom.example.net

## 8. Security before wider publication

The current ATOM API is read-only for station queries but the service also has an observation ingestion endpoint used by the collector. Publishing the entire Flask service through an Internet-facing reverse proxy exposes that endpoint too. Before considering the DNS endpoint a general public production API, add an authentication/control boundary for ingestion and review rate limiting, request-size limits, logging and a production WSGI server.

A stronger deployment pattern is to expose only read endpoints (`/health`, `/api/v1/stations`, station detail) publicly and keep observation ingestion reachable only by the internal collector.

## 9. DNS/NAT caveat

Some routers do not support NAT loopback/hairpinning. If the public hostname works on cellular but not while the iPhone is on the home Wi-Fi, use split DNS/local DNS so `atom.example.net` resolves to the Synology LAN address internally, or enable NAT loopback if the router supports it. Keep the same HTTPS hostname so certificate validation remains correct.

## 10. Failure checklist

- DNS resolves to the wrong public address: fix A/AAAA/DDNS.
- Port 443 closed: check router forwarding/firewall and ISP restrictions.
- Certificate warning: confirm certificate covers the exact DNS hostname and is assigned to the reverse-proxy host.
- `502 Bad Gateway`: verify `curl http://localhost:8088/health` on the Synology and reverse-proxy destination.
- Works on Wi-Fi but not cellular: check public DNS/443 forwarding/firewall.
- Works on cellular but not Wi-Fi: investigate NAT loopback or split DNS.
- iPhone says ATS/secure connection required: use the HTTPS hostname and inspect the TLS configuration rather than weakening ATS globally.

## Repository/runtime separation

DNS records, router rules and certificates contain site-specific operational configuration and are not committed as secrets to Git. This document, app configuration UI and test procedure are version controlled. Record non-secret deployment decisions and test results in the project documentation as the public endpoint is commissioned.
\n\n## Checkpoint synchronization — 18 September 2026\n\nPublic HTTPS remains DSM Reverse Proxy at `https://granvillehouse.synology.me:8445/`, forwarding to Nginx on host port 8088. Behind Nginx the current tested stack has two stateless API replicas sharing PostgreSQL. The API replicas and PostgreSQL are not host-published. See `CHECKPOINT-2026-09-18.md`.\n

## Current public Admin routing

DSM Reverse Proxy forwards the public HTTPS origin to Nginx on host port 8088. Nginx sends only `/api/v1/admin/*` to `atom-admin-monitor`; all other paths remain on the replicated station API. Pairing is additionally restricted by source network. `atom-admin-control` has no published host port.

Nginx Admin requests allow 105 seconds so the internal 90-second scaling readiness operation can finish. Clean rebuilds must recreate `atom-lb` to reload routing and timeout changes.
