#!/usr/bin/env python3
"""Patch reaction sync history in device SharedPreferences."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from datetime import datetime, timedelta, timezone

DEVICE = "SXILHMB270711564"
PACKAGE = "com.stepbytestudio.room_manager2"
PREFS_KEY = "flutter.room_reaction_sync_history_v1_json"
JSON_LIST_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu!"


def adb(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["adb", "-s", DEVICE, *args],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


def pull_prefs_xml() -> str:
    proc = adb("shell", f"run-as {PACKAGE} cat shared_prefs/FlutterSharedPreferences.xml")
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "read prefs failed")
    return proc.stdout


def push_prefs_xml(content: str) -> None:
    cmd = [
        "adb",
        "-s",
        DEVICE,
        "shell",
        f"run-as {PACKAGE} sh -c 'cat > shared_prefs/FlutterSharedPreferences.xml'",
    ]
    proc = subprocess.run(
        cmd,
        input=content.encode("utf-8"),
        capture_output=True,
    )
    if proc.returncode != 0:
        err = proc.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(err or "write prefs failed")


def encode_list_value(items: list[str]) -> str:
    return JSON_LIST_PREFIX + json.dumps(items, ensure_ascii=False)


def entry(
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


def set_entries(entries: list[str]) -> None:
    xml_text = pull_prefs_xml()
    if not entries:
        import re

        xml_text = re.sub(
            rf'\s*<string name="{re.escape(PREFS_KEY)}">.*?</string>',
            "",
            xml_text,
            count=1,
            flags=re.DOTALL,
        )
    else:
        encoded = encode_list_value(entries)
        import re

        pattern = rf'(<string name="{re.escape(PREFS_KEY)}">)(.*?)(</string>)'
        if re.search(pattern, xml_text, flags=re.DOTALL):
            xml_text = re.sub(
                pattern,
                rf"\1{encoded}\3",
                xml_text,
                count=1,
                flags=re.DOTALL,
            )
        else:
            xml_text = xml_text.replace(
                "</map>",
                f'    <string name="{PREFS_KEY}">{encoded}</string>\n</map>',
                1,
            )
    push_prefs_xml(xml_text)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "mode",
        choices=["recentSync", "noHistory", "eligible", "noticeIncreased"],
    )
    args = parser.parse_args()
    now = datetime.now(timezone.utc)
    if args.mode == "recentSync":
        set_entries([entry(synced_at=now - timedelta(hours=1))])
    elif args.mode == "noHistory":
        set_entries([])
    elif args.mode == "eligible":
        set_entries([entry(synced_at=now - timedelta(hours=5))])
    elif args.mode == "noticeIncreased":
        set_entries(
            [
                entry(
                    synced_at=now - timedelta(minutes=10),
                    like_increased=2,
                    comment_increased=1,
                ),
                entry(synced_at=now - timedelta(hours=6)),
            ]
        )
    print(f"patched mode={args.mode}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
