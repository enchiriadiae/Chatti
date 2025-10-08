##########################################
#
# === Nutzung
#```bash
# chmod +x scripts/make_release.sh
# scripts/make_release.sh
#  oder ohne Import-Smoketest:
# scripts/make_release.sh --no-smoke
#
##########################################


#!/usr/bin/env bash
set -Eeuo pipefail

# --- Settings ---
PROJECT_NAME="Chatti-Client"
VERSION_FILE="core/__init__.py"   # enthält __version__ = "0.9.0"
DIST_DIR="dist"
OUT_ROOT="${DIST_DIR}/release"
ZIP_NAME=""                       # wird unten gesetzt

# --- Helpers ---
say()  { printf "\033[1;36m== %s ==\033[0m\n" "$*"; }
ok()   { printf "\033[1;32m✔ %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m⚠ %s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m✖ %s\033[0m\n" "$*"; }

# --- Version ermitteln ---
if [[ -f "$VERSION_FILE" ]]; then
  VERSION=$(python - <<'PY'
import re, pathlib
p = pathlib.Path("core/__init__.py").read_text(encoding="utf-8")
m = re.search(r'__version__\s*=\s*["\']([^"\']+)["\']', p)
print(m.group(1) if m else "0.0.0")
PY
)
else
  VERSION="0.0.0"
fi
ZIP_NAME="${PROJECT_NAME}-${VERSION}.zip"

say "Version: ${VERSION}"

# --- optionaler Import-Smoketest (kannst du mit --no-smoke überspringen) ---
if [[ "${1-}" != "--no-smoke" ]]; then
  say "Import smoke"
  python - <<'PY'
mods = [
  "core.paths","core.security","core.api","core.attachments","core.history",
  "core.usage","core.pdf_utils","core.tickets","tools.chatti_doctor"
]
for m in mods:
    __import__(m)
print("imports ok")
PY
  ok "imports ok"
fi

# --- Dist vorbereiten ---
say "Prepare dist"
rm -rf "$DIST_DIR"
mkdir -p "$OUT_ROOT"

# --- Dateien kopieren (inkl. docs/scripts), aber ohne venv/git/caches ---
say "Copy sources"
rsync -a \
  --exclude '.venv' \
  --exclude '.git' \
  --exclude '__pycache__' \
  --exclude '.DS_Store' \
  --exclude '*.pyc' \
  --exclude '*.pyo' \
  --exclude 'dist' \
  ./  "$OUT_ROOT/"

# --- Minimal-Check: requirements.txt vorhanden? ---
if [[ ! -f "$OUT_ROOT/requirements.txt" ]]; then
  warn "requirements.txt fehlt – erzeuge aktuelle aus venv"
  python -m pip freeze | grep -vE 'file://|AppleInternal' > "$OUT_ROOT/requirements.txt" || warn "pip freeze fehlgeschlagen"
fi

# --- Version & kurze Info ablegen ---
printf "%s\n" "$VERSION" > "$OUT_ROOT/VERSION.txt"

cat > "$OUT_ROOT/INSTALL.md" <<'MD'
# Chatti-Client — Installation (Python 3.12+)

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -U pip setuptools wheel
python -m pip install -r requirements.txt
./chatti --help
