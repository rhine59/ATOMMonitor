#!/usr/bin/env python3
"""ATOM Monitor SQLite backup/recovery utility.

Backs up the ground-station registry using SQLite's online backup API, verifies
integrity, records a SHA-256 sidecar, applies retention, and can verify or
restore a backup into a controlled copy. No aircraft data is handled.
"""
from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import shutil
import sqlite3
import sys
import tempfile
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DB = Path(os.getenv("ATOM_DB", ROOT / "server/data/atommonitor.sqlite3"))
DEFAULT_BACKUP_DIR = Path(os.getenv("ATOM_BACKUP_DIR", ROOT.parent / "ATOMMonitor-backups"))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def inspect_db(path: Path) -> tuple[str, int, int]:
    if not path.is_file():
        raise FileNotFoundError(path)
    with sqlite3.connect(f"file:{path}?mode=ro", uri=True) as connection:
        integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
        if integrity != "ok":
            raise RuntimeError(f"SQLite integrity_check failed: {integrity}")
        table = connection.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='stations'"
        ).fetchone()
        if not table:
            raise RuntimeError("stations table is missing")
        total = connection.execute("SELECT COUNT(*) FROM stations").fetchone()[0]
        confirmed = connection.execute(
            "SELECT COUNT(*) FROM stations WHERE isPilotAware=1"
        ).fetchone()[0]
    return integrity, total, confirmed


def write_checksum(path: Path) -> str:
    digest = sha256(path)
    path.with_suffix(path.suffix + ".sha256").write_text(
        f"{digest}  {path.name}\n", encoding="utf-8"
    )
    return digest


def check_checksum(path: Path) -> str:
    sidecar = path.with_suffix(path.suffix + ".sha256")
    if not sidecar.is_file():
        raise RuntimeError(f"checksum sidecar missing: {sidecar}")
    expected = sidecar.read_text(encoding="utf-8").split()[0]
    actual = sha256(path)
    if actual != expected:
        raise RuntimeError(f"SHA-256 mismatch for {path.name}")
    return actual


def prune(directory: Path, keep: int) -> None:
    if keep < 1:
        raise ValueError("retention must be at least 1")
    backups = sorted(directory.glob("atommonitor-*.sqlite3"), reverse=True)
    for old in backups[keep:]:
        sidecar = old.with_suffix(old.suffix + ".sha256")
        old.unlink(missing_ok=True)
        sidecar.unlink(missing_ok=True)
        print(f"Pruned {old}")


def backup(source: Path, directory: Path, keep: int) -> Path:
    inspect_db(source)
    directory.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    final = directory / f"atommonitor-{stamp}.sqlite3"
    partial = final.with_suffix(".sqlite3.partial")
    partial.unlink(missing_ok=True)
    try:
        with sqlite3.connect(f"file:{source}?mode=ro", uri=True) as src:
            with sqlite3.connect(partial) as dst:
                src.backup(dst)
        integrity, total, confirmed = inspect_db(partial)
        partial.replace(final)
        digest = write_checksum(final)
        prune(directory, keep)
    except Exception:
        partial.unlink(missing_ok=True)
        raise
    print(f"Backup: {final}")
    print(f"Integrity: {integrity}")
    print(f"Stations: {total}; confirmed PilotAware: {confirmed}")
    print(f"SHA-256: {digest}")
    return final


def verify(path: Path) -> None:
    digest = check_checksum(path)
    with tempfile.TemporaryDirectory(prefix="atommonitor-restore-test-") as temp:
        restored = Path(temp) / "restored.sqlite3"
        shutil.copy2(path, restored)
        integrity, total, confirmed = inspect_db(restored)
    print(f"Verified backup: {path}")
    print(f"Integrity: {integrity}")
    print(f"Stations: {total}; confirmed PilotAware: {confirmed}")
    print(f"SHA-256: {digest}")
    print("Controlled restore verification: PASS")


def sqlite_sidecars(path: Path) -> tuple[Path, Path, Path]:
    """Return SQLite sidecars that must not survive a replacement database."""
    return tuple(Path(str(path) + suffix) for suffix in ("-wal", "-shm", "-journal"))


def restore(path: Path, target: Path, force: bool) -> None:
    check_checksum(path)
    inspect_db(path)
    sidecars = sqlite_sidecars(target)
    existing_sidecars = [sidecar for sidecar in sidecars if sidecar.exists()]
    if (target.exists() or existing_sidecars) and not force:
        detail = ", ".join(str(item) for item in ([target] if target.exists() else []) + existing_sidecars)
        raise RuntimeError(
            f"target database state exists: {detail}; use --force only after stopping services"
        )
    target.parent.mkdir(parents=True, exist_ok=True)
    temp = target.with_suffix(target.suffix + ".restore-partial")
    temp.unlink(missing_ok=True)
    shutil.copy2(path, temp)
    inspect_db(temp)

    # A WAL/SHM/journal belongs to the previous database generation.  It must
    # never be presented to SQLite beside the replacement database.  --force
    # is deliberately required and the recovery runbook requires services to
    # be stopped before this point.
    for sidecar in sidecars:
        sidecar.unlink(missing_ok=True)

    temp.replace(target)
    integrity, total, confirmed = inspect_db(target)
    print(f"Restored: {target}")
    print(f"Integrity: {integrity}")
    print(f"Stations: {total}; confirmed PilotAware: {confirmed}")


def latest(directory: Path) -> Path:
    matches = sorted(directory.glob("atommonitor-*.sqlite3"), reverse=True)
    if not matches:
        raise RuntimeError(f"no backups found in {directory}")
    return matches[0]


def main() -> int:
    parser = argparse.ArgumentParser(description="ATOM Monitor SQLite backup/recovery")
    sub = parser.add_subparsers(dest="command", required=True)

    create = sub.add_parser("backup", help="create and verify an online SQLite backup")
    create.add_argument("--db", type=Path, default=DEFAULT_DB)
    create.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)
    create.add_argument("--keep", type=int, default=int(os.getenv("ATOM_BACKUP_KEEP", "14")))

    check = sub.add_parser("verify", help="verify checksum, integrity and a controlled restore copy")
    check.add_argument("backup", nargs="?", type=Path)
    check.add_argument("--backup-dir", type=Path, default=DEFAULT_BACKUP_DIR)

    recover = sub.add_parser("restore", help="restore a verified backup to an explicit target")
    recover.add_argument("backup", type=Path)
    recover.add_argument("--target", type=Path, required=True)
    recover.add_argument("--force", action="store_true")

    args = parser.parse_args()
    try:
        if args.command == "backup":
            backup(args.db.resolve(), args.backup_dir.resolve(), args.keep)
        elif args.command == "verify":
            chosen = args.backup.resolve() if args.backup else latest(args.backup_dir.resolve())
            verify(chosen)
        else:
            restore(args.backup.resolve(), args.target.resolve(), args.force)
        return 0
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
