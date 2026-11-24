#!/bin/bash
# Compila nextpnr-himbaechel (Gowin) localmente en $PIXI_PROJECT_ROOT/.nextpnr
#
# nextpnr no lee la base de apycula en tiempo de ejecución: la convierte en su
# propia chipdb al compilarse. Como se usa una apycula modificada (pines internos
# de la PSRAM del GW2AR-18 eLQFP144P, ver vendor/ y scripts/apycula_psram/), nextpnr
# debe compilarse contra la apycula de este entorno y recompilarse cuando cambie.
#
# Se ejecuta desde `pixi run setup-env` o `pixi run build-nextpnr`.
#   FORCE=1 pixi run build-nextpnr   -> recompila aunque esté al día
set -euo pipefail

: "${PIXI_PROJECT_ROOT:?Ejecutar dentro del entorno pixi (pixi run build-nextpnr)}"
: "${CONDA_PREFIX:?Ejecutar dentro del entorno pixi (pixi run build-nextpnr)}"

# nextpnr-0.11.1 es el nextpnr de la toolchain "stable" de apicula 0.36 (con yosys 0.71)
NEXTPNR_VERSION="nextpnr-0.11.1"
NEXTPNR_REPO="https://github.com/YosysHQ/nextpnr.git"
# GW2A-18C: FPGA de la FPGBC (GW2AR-18C). GW1N-9C: Tang Nano 9K (pixi run test-EDA)
NEXTPNR_GOWIN_DEVICES="GW1N-9C;GW2A-18C"
NEXTPNR_DIR="$PIXI_PROJECT_ROOT/.nextpnr"
NEXTPNR_BIN="$NEXTPNR_DIR/bin/nextpnr-himbaechel"
STAMP_FILE="$NEXTPNR_DIR/.build-stamp"

# Identifica la apycula instalada y sus bases para decidir si hay que recompilar
APYCULA_ID="$(python - "$NEXTPNR_GOWIN_DEVICES" <<'EOF'
import sys, hashlib, importlib.metadata as m, importlib.resources as r
h = hashlib.sha256()
for dev in sys.argv[1].split(';'):
    h.update((r.files('apycula') / f'{dev}.msgpack.xz').read_bytes())
print(f"apycula={m.version('apycula')} db={h.hexdigest()[:16]}")
EOF
)"
STAMP="$NEXTPNR_VERSION devices=$NEXTPNR_GOWIN_DEVICES $APYCULA_ID"

# Enlace antiguo a yowasp (instalaciones previas), ya no existe ese paquete
OLD_LINK="$CONDA_PREFIX/bin/nextpnr-himbaechel-gowin"
if [ -L "$OLD_LINK" ] && [ ! -e "$OLD_LINK" ]; then
    rm -f "$OLD_LINK"
fi

if [ -z "${FORCE:-}" ] && [ -x "$NEXTPNR_BIN" ] && "$NEXTPNR_BIN" --version >/dev/null 2>&1 \
   && [ "$(cat "$STAMP_FILE" 2>/dev/null)" = "$STAMP" ]; then
    echo "✅ nextpnr al día en $NEXTPNR_DIR ($STAMP)"
    exit 0
fi

echo "⚙️  Compilando $NEXTPNR_VERSION para Gowin ($NEXTPNR_GOWIN_DEVICES) con $APYCULA_ID"
WORK_DIR="$(mktemp -d -t fpgbc-nextpnr-XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

git clone --quiet --depth 1 --branch "$NEXTPNR_VERSION" \
    --recurse-submodules --shallow-submodules "$NEXTPNR_REPO" "$WORK_DIR/src"

# Todo desde el entorno pixi (compilador, Boost, Eigen, Python con apycula)
cmake -G Ninja -S "$WORK_DIR/src" -B "$WORK_DIR/build" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-gcc" \
    -DCMAKE_CXX_COMPILER="$CONDA_PREFIX/bin/x86_64-conda-linux-gnu-c++" \
    -DCMAKE_PREFIX_PATH="$CONDA_PREFIX" \
    -DBoost_ROOT="$CONDA_PREFIX" \
    -DPython3_EXECUTABLE="$CONDA_PREFIX/bin/python" \
    -DAPYCULA_INSTALL_PREFIX="$CONDA_PREFIX" \
    -DARCH=himbaechel \
    -DHIMBAECHEL_UARCH=gowin \
    -DHIMBAECHEL_GOWIN_DEVICES="$NEXTPNR_GOWIN_DEVICES" \
    -DBUILD_PYTHON=OFF -DBUILD_GUI=OFF -DBUILD_TESTS=OFF \
    -DCMAKE_INSTALL_PREFIX="$NEXTPNR_DIR" \
    -DCMAKE_INSTALL_RPATH="$CONDA_PREFIX/lib" \
    -Wno-dev
cmake --build "$WORK_DIR/build" --parallel "$(nproc)"

rm -rf "$NEXTPNR_DIR"
cmake --install "$WORK_DIR/build" --strip
# Nombre que buscan LiteX y test/env/min_soc/Makefile
ln -sf nextpnr-himbaechel "$NEXTPNR_DIR/bin/nextpnr-himbaechel-gowin"
echo "$STAMP" > "$STAMP_FILE"

"$NEXTPNR_BIN" --version
echo "✅ nextpnr instalado en $NEXTPNR_DIR"
