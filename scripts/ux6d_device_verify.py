#!/usr/bin/env python3
"""Phase UX-6d device verification: UI dumps, taps, logcat."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

DEVICE = "SXILHMB270711564"
PACKAGE = "com.stepbytestudio.room_manager2"
REPO = Path(__file__).resolve().parents[1]
PATCH = REPO / "scripts" / "ux6c_patch_history.py"


def adb(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    cmd = ["adb", "-s", DEVICE, *args]
    return subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=check,
    )


def patch_history(mode: str) -> None:
    proc = subprocess.run(
        [sys.executable, str(PATCH), mode],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"patch failed: {mode}")
    print(proc.stdout.strip())


def clear_notice_dismiss_store() -> None:
    """Remove home_in_app_notice_dismissed_v1 from SharedPreferences."""
    proc = adb(
        "shell",
        f"run-as {PACKAGE} cat shared_prefs/FlutterSharedPreferences.xml",
        check=False,
    )
    if proc.returncode != 0 or not proc.stdout:
        return
    xml_text = proc.stdout
    key = "home_in_app_notice_dismissed_v1"
    xml_text = re.sub(
        rf'\s*<string name="flutter\.{re.escape(key)}">.*?</string>',
        "",
        xml_text,
        count=1,
        flags=re.DOTALL,
    )
    cmd = [
        "adb",
        "-s",
        DEVICE,
        "shell",
        f"run-as {PACKAGE} sh -c 'cat > shared_prefs/FlutterSharedPreferences.xml'",
    ]
    subprocess.run(cmd, input=xml_text.encode("utf-8"), capture_output=True, check=True)


def force_stop() -> None:
    adb("shell", "am", "force-stop", PACKAGE, check=False)


def launch_app() -> None:
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


def clear_logcat() -> None:
    adb("logcat", "-c", check=False)


def dump_logcat(out_path: Path) -> str:
    proc = adb("logcat", "-d", check=False)
    text = proc.stdout or ""
    out_path.write_text(text, encoding="utf-8")
    return text


def ui_dump(name: str, out_dir: Path) -> str:
    remote = f"/sdcard/ux6d_{name}.xml"
    adb("shell", "uiautomator", "dump", remote, check=False)
    local = out_dir / f"{name}_ui.xml"
    adb("pull", remote, str(local), check=False)
    if local.exists():
        return local.read_text(encoding="utf-8", errors="replace")
    return ""


def ui_texts(xml_text: str) -> list[str]:
    if not xml_text.strip():
        return []
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError:
        return []
    texts: list[str] = []
    for node in root.iter("node"):
        t = (node.get("text") or "").strip()
        if t:
            texts.append(t)
        desc = (node.get("content-desc") or "").strip()
        if desc:
            texts.append(desc)
    return texts


def find_bounds(xml_text: str, *needles: str) -> tuple[int, int] | None:
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError:
        return None
    for node in root.iter("node"):
        hay = f"{node.get('text') or ''} {node.get('content-desc') or ''}"
        if any(n in hay for n in needles):
            bounds = node.get("bounds") or ""
            m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", bounds)
            if m:
                x1, y1, x2, y2 = map(int, m.groups())
                return ((x1 + x2) // 2, (y1 + y2) // 2)
    return None


def tap(x: int, y: int) -> None:
    adb("shell", "input", "tap", str(x), str(y), check=False)


def scroll_down() -> None:
    adb("shell", "input", "swipe", "540", "1600", "540", "800", "400", check=False)


def go_home_tab() -> None:
    xml = ui_dump("_nav", Path("."))
    pt = find_bounds(xml, "ホーム")
    if pt:
        tap(*pt)
        time.sleep(1.0)


def extract_lines(log_text: str, *patterns: str) -> list[str]:
    lines: list[str] = []
    for ln in log_text.splitlines():
        if any(p in ln for p in patterns):
            lines.append(ln.strip())
    return lines


def run_scenario(
    name: str,
    *,
    patch_mode: str | None,
    wait_s: float,
    out_dir: Path,
    clear_dismiss: bool = False,
    extra_wait_after: float = 0,
    actions: list[tuple[str, float]] | None = None,
) -> dict:
    print(f"\n=== {name} ===")
    if clear_dismiss:
        clear_notice_dismiss_store()
    if patch_mode:
        patch_history(patch_mode)
    force_stop()
    time.sleep(0.6)
    clear_logcat()
    launch_app()
    time.sleep(wait_s)
    if actions:
        for label, delay in actions:
            xml = ui_dump(f"{name}_{label}", out_dir)
            pt = find_bounds(xml, label)
            if pt:
                tap(*pt)
                print(f"  tapped {label} at {pt}")
            else:
                print(f"  WARN: {label} not found in UI")
            time.sleep(delay)
    if extra_wait_after > 0:
        time.sleep(extra_wait_after)
    ui_name = f"{name}_final"
    xml = ui_dump(ui_name, out_dir)
    texts = ui_texts(xml)
    log_path = out_dir / f"{name}.logcat.txt"
    log_text = dump_logcat(log_path)
    return {
        "name": name,
        "texts": texts,
        "auto_lines": extract_lines(log_text, "[AUTO_REACTION_SYNC]"),
        "button_lines": extract_lines(
            log_text,
            "ROOM_SYNC_BUTTON_RENDER_DECISION",
            "ROOM_SYNC_EMPTY_BUTTON_AUDIT",
        ),
        "guard_lines": extract_lines(log_text, "[ROOM_REACTION_SYNC_START_GUARD]"),
        "errors": extract_lines(
            log_text,
            "FlutterError",
            "EXCEPTION CAUGHT",
            "Another exception",
        ),
        "dialog_snack": extract_lines(log_text, "SnackBar", "showDialog", "AlertDialog"),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", required=True)
    args = parser.parse_args()
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    results: list[dict] = []

    # 1. Normal state (auto skipped by recentSync)
    results.append(
        run_scenario(
            "1_normal",
            patch_mode="recentSync",
            wait_s=8.0,
            out_dir=out_dir,
        )
    )

    # 2. Auto sync in progress (~6s after launch)
    results.append(
        run_scenario(
            "2_auto_busy",
            patch_mode="eligible",
            wait_s=6.5,
            out_dir=out_dir,
        )
    )

    # 3. After auto sync complete
    results.append(
        run_scenario(
            "3_auto_done",
            patch_mode="eligible",
            wait_s=28.0,
            out_dir=out_dir,
        )
    )

    # 4a. Notice card visible
    results.append(
        run_scenario(
            "4_notice_show",
            patch_mode="noticeIncreased",
            wait_s=6.0,
            out_dir=out_dir,
            clear_dismiss=True,
        )
    )

    # 4b. Tap 分析で見る
    force_stop()
    time.sleep(0.5)
    clear_notice_dismiss_store()
    patch_history("noticeIncreased")
    launch_app()
    time.sleep(5.0)
    scroll_down()
    time.sleep(0.5)
    xml_before = ui_dump("4_notice_before_tap", out_dir)
    pt = find_bounds(xml_before, "分析で見る")
    if pt:
        tap(*pt)
    time.sleep(2.5)
    xml_analysis = ui_dump("4_notice_after_analyze", out_dir)
    analysis_texts = ui_texts(xml_analysis)
    results.append(
        {
            "name": "4_notice_analyze_tap",
            "texts": analysis_texts,
            "tapped": pt is not None,
        }
    )

    # 4c. Dismiss notice
    go_home_tab()
    time.sleep(1.5)
    scroll_down()
    xml_card = ui_dump("4_notice_before_dismiss", out_dir)
    close_pt = find_bounds(xml_card, "閉じる")
    if not close_pt:
        # IconButton tooltip may not appear; tap top-right of card area
        close_pt = find_bounds(xml_card, "反応がありました")
        if close_pt:
            close_pt = (close_pt[0] + 280, close_pt[1] - 10)
    if close_pt:
        tap(*close_pt)
    time.sleep(1.0)
    xml_after_dismiss = ui_dump("4_notice_after_dismiss", out_dir)
    results.append(
        {
            "name": "4_notice_dismiss",
            "before_has_card": "反応がありました" in ui_texts(xml_card),
            "after_has_card": "反応がありました" in ui_texts(xml_after_dismiss),
            "dismiss_tapped": close_pt is not None,
        }
    )

    # 4d. Restart - same notice should not reappear
    force_stop()
    time.sleep(0.8)
    launch_app()
    time.sleep(6.0)
    scroll_down()
    xml_restart = ui_dump("4_notice_after_restart", out_dir)
    results.append(
        {
            "name": "4_notice_restart",
            "after_restart_has_card": "反応がありました"
            in ui_texts(xml_restart),
        }
    )

    # 5. Manual confirm dialog
    patch_history("recentSync")
    force_stop()
    time.sleep(0.5)
    launch_app()
    time.sleep(5.0)
    scroll_down()
    time.sleep(0.5)
    xml_manual = ui_dump("5_manual_before", out_dir)
    btn_pt = find_bounds(xml_manual, "今すぐ反応を確認")
    if btn_pt:
        tap(*btn_pt)
    time.sleep(1.5)
    xml_dialog = ui_dump("5_manual_dialog", out_dir)
    dialog_texts = ui_texts(xml_dialog)
    # Cancel dialog
    cancel_pt = find_bounds(xml_dialog, "キャンセル")
    if cancel_pt:
        tap(*cancel_pt)
    log_path = out_dir / "5_manual.logcat.txt"
    log_text = dump_logcat(log_path)
    results.append(
        {
            "name": "5_manual_confirm",
            "button_tapped": btn_pt is not None,
            "dialog_texts": dialog_texts,
            "has_confirm_dialog": any(
                "反応" in t and ("確認" in t or "実行" in t or "開始" in t)
                for t in dialog_texts
            )
            or "キャンセル" in dialog_texts,
            "guard_lines": extract_lines(log_text, "[ROOM_REACTION_SYNC_START_GUARD]"),
        }
    )

    # 6. Existing nav check on home
    patch_history("recentSync")
    force_stop()
    time.sleep(0.5)
    launch_app()
    time.sleep(4.0)
    xml_nav = ui_dump("6_nav_check", out_dir)
    nav_texts = ui_texts(xml_nav)
    results.append(
        {
            "name": "6_existing_nav",
            "texts": nav_texts,
        }
    )

    summary = {
        "timestamp": datetime.now().isoformat(),
        "device": DEVICE,
        "dart_defines": {
            "RAKUTEN_APP_ID": "",
            "RAKUTEN_AFFILIATE_ID": "",
            "PRODUCT_CATALOG_ENABLED": "true",
            "SHOP_CATALOG_ENABLED": "true",
            "CATALOG_AUDIT_LOGS": "false",
        },
        "results": results,
    }
    summary_path = out_dir / "summary.json"
    summary_path.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"\nWrote {summary_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
