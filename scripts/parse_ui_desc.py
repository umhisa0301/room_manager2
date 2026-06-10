import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
for m in re.finditer(r'content-desc="([^"]+)"', text):
    d = m.group(1)
    if any(k in d for k in ("反応", "分析", "おすすめ", "ROOM", "確認", "閉じ")):
        print(d)
