#!/usr/bin/env bash
# Count UTF-8 file tokens with tiktoken's o200k_base encoding.
# Usage: tiktoken <file_path>

set -euo pipefail

if [[ $# -ne 1 || "$1" == "-h" || "$1" == "--help" ]]; then
    printf 'Usage: tiktoken <file_path>\n' >&2
    exit 64
fi

file_path=$1

if [[ ! -f "$file_path" ]]; then
    printf 'tiktoken: not a regular file: %s\n' "$file_path" >&2
    exit 66
fi

if ! command -v python3 >/dev/null 2>&1; then
    printf 'tiktoken: python3 is required\n' >&2
    exit 69
fi

if ! python3 -c 'import tiktoken' >/dev/null 2>&1; then
    printf 'tiktoken: Python package missing; install with: python3 -m pip install tiktoken\n' >&2
    exit 69
fi

python3 - "$file_path" <<'PY'
from pathlib import Path
import sys
import warnings

try:
    text = Path(sys.argv[1]).read_text(encoding="utf-8")
except UnicodeDecodeError:
    print(f"tiktoken: file is not valid UTF-8: {sys.argv[1]}", file=sys.stderr)
    raise SystemExit(65)
except OSError as error:
    print(f"tiktoken: cannot read {sys.argv[1]}: {error}", file=sys.stderr)
    raise SystemExit(66)

# macOS's system Python emits this unrelated SSL warning while importing tiktoken.
warnings.filterwarnings("ignore", message="urllib3 v2 only supports OpenSSL 1.1.1+")
import tiktoken

encoding = tiktoken.get_encoding("o200k_base")
print(f"{len(encoding.encode(text))} tokens (o200k_base)")
PY
