#!/usr/bin/env python3
"""Phase UX-6c device verification helper: patch SharedPreferences and capture logcat."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from pathlib import Path

DEVICE = "SXILHMB270711564"
PACKAGE = "com.stepbytestudio.room_manager2"
PREFS_KEY = "flutter.room_reaction_sync_history_v1_json"
LIST_PREFIX = "This is the prefix for a list!"


def adb(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    cmd = ["adb", "-s", DEVICE, *args]
    return subprocess.run(cmd, capture_output=True, text=True, check=check)


def pull_prefs_xml() -> str:
    proc = adb(
        "shell",
        f"run-as {PACKAGE} cat shared_prefs/FlutterSharedPreferences.xml",
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "failed to read prefs")
    return proc.stdout


def push_prefs_xml(content: str) -> None:
    # Write via stdin to avoid temp file permission issues on device.
    cmd = [
        "adb",
        "-s",
        DEVICE,
        "shell",
        f"run-as {PACKAGE} sh -c 'cat > shared_prefs/FlutterSharedPreferences.xml'",
    ]
    proc = subprocess.run(cmd, input=content, text=True, capture_output=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "failed to write prefs")


def decode_list_value(raw: str) -> list[str]:
    if not raw.startswith(LIST_PREFIX):
        raise ValueError("unexpected shared_preferences list encoding")
    payload = raw[len(LIST_PREFIX) :]
    items = json.loads(payload)
    if not isinstance(items, list):
        raise ValueError("list payload is not a JSON array")
    return [str(x) for x in items]


def encode_list_value(items: list[str]) -> str:
    return LIST_PREFIX + json.dumps(items, ensure_ascii=False)


def entry_template(
    *,
    synced_at: datetime,
    like_increased: int = 0,
    comment_increased: int = 0,
    checked: int = 1,
) -> str:
    obj = {
        "syncedAt": synced_at.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
        "checkedItems": checked,
        "updatedItems": 0,
        "likeIncreasedItems": like_increased,
        "commentIncreasedItems": comment_increased,
        "unchangedItems": checked,
        "hasReactionItems": 1,
        "commentedItems": 0,
        "stopReason": "maxDurationReached",
        "hasNextCursor": False,
        "topReactedProducts": [],
    }
    return json.dumps(obj, ensure_ascii=False)


def set_history_entries(entries: list[str]) -> None:
    xml_text = pull_prefs_xml()
    root = ET.fromstring(xml_text)
    if not entries:
        for child in list(root):
            if child.get("name") == PREFS_KEY:
                root.remove(child)
    else:
        encoded = encode_list_value(entries)
        found = False
        for child in root:
            if child.get("name") == PREFS_KEY:
                child.text = encoded
                found = True
                break
        if not found:
            el = ET.SubElement(root, "string", {"name": PREFS_KEY})
            el.text = encoded
    push_prefs_xml(ET.tostring(root, encoding="unicode"))


def force_stop() -> None:
    adb("shell", "am", "force-stop", PACKAGE, check=False)


def start_app() -> None:
    adb(
        "shell",
        "monkey",
        "-p",
        PACKAGE,
        "-c",
        "android.intent.category.LAUNCHER",
        "1",
        check=False,
    )


def capture_logcat(seconds: float, out_file: Path) -> str:
    proc = subprocess.Popen(
        [
            "adb",
            "-s",
            DEVICE,
            "logcat",
            "-v",
            "time",
            "-s",
            "flutter",
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    assert proc.stdout is not None
    lines: list[str] = []
    end = time.time() + seconds
    try:
        while time.time() < end:
            line = proc.stdout.readline()
            if not line:
                break
            lines.append(line)
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
    text = "".join(lines)
    out_file.write_text(text, encoding="utf-8")
    return text


def extract_auto_sync_lines(log_text: str) -> list[str]:
    return [
        ln.strip()
        for ln in log_text.splitlines()
        if "[AUTO_REACTION_SYNC]" in ln
    ]


def run_scenario(name: str, entries: list[str] | None, wait_s: float, out_dir: Path) -> dict:
    print(f"\n=== Scenario: {name} ===")
    if entries is None:
        set_history_entries([])
    else:
        set_history_entries(entries)
    force_stop()
    time.sleep(0.5)
    start_app()
    log_path = out_dir / f"{name}.logcat.txt"
    log_text = capture_logcat(wait_s, log_path)
    auto_lines = extract_auto_sync_lines(log_text)
    for ln in auto_lines:
        print(ln)
    return {
        "name": name,
        "auto_lines": auto_lines,
        "log_path": str(log_path),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", required=True)
    parser.add_argument(
        "--scenario",
        choices=["recentSync", "noHistory", "eligible", "noticeIncreased", "all"],
        default="all",
    )
    args = parser.parse_args()
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    now = datetime.now(timezone.utc)
    recent = now - timedelta(hours=1)
    old = now - timedelta(hours=5)

    base_old = entry_template(synced_at=old)
    base_recent = entry_template(synced_at=recent)
    increased_latest = entry_template(
        synced_at=now - timedelta(minutes=10),
        like_increased=2,
        comment_increased=1,
    )
    increased_prev = entry_template(synced_at=old)

    scenarios: list[tuple[str, list[str] | None]] = []
    if args.scenario in ("recentSync", "all"):
        scenarios.append(("1_recentSync", [base_recent, base_old]))
    if args.scenario in ("noHistory", "all"):
        scenarios.append(("2_noHistory", None))
    if args.scenario in ("eligible", "all"):
        scenarios.append(("3_eligible", [base_old]))
    if args.scenario in ("noticeIncreased", "all"):
        scenarios.append(
            ("5_noticeIncreased", [increased_latest, increased_prev])
        )

    results = []
    for name, entries in scenarios:
        results.append(run_scenario(name, entries, wait_s=12.0, out_dir=out_dir))

    summary_path = out_dir / "summary.json"
    summary_path.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nWrote {summary_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
