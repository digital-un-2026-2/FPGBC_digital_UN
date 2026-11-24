#!/usr/bin/env python3
"""Genera un wheel de apycula con los pines internos (SiP) de la PSRAM del
GW2AR-LV18EQ144PC8/I7 (paquete eLQFP144P), que apycula aún no incluye.

Añade a GW2A-18C.msgpack.xz:
    db.sip_cst["GW2AR-18C"]["eLQFP144P"] = [(net, row, col, bel, iostd), ...]
nextpnr usa esa tabla para restringir automáticamente los puertos
O_psram_* / IO_psram_* a los IOB internos (no hace falta IO_LOC).

Los pines (sip_cst_GW2AR-18C_eLQFP144P.json) se obtuvieron con el fuzzer de
apycula (chipdb_builder.run_sdram_script) sobre el PnR de Gowin IDE 1.9.12.04 y
se verificaron contra el reporte de PnR de Gowin y en hardware.

Uso (con el Python del entorno pixi, que tiene msgspec):
    python make_wheel.py <apycula-X.Y-py3-none-any.whl> <outdir> [label]
    -> <outdir>/apycula-X.Y+psram-py3-none-any.whl
"""
import sys
import os
import re
import json
import base64
import hashlib
import zipfile
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
PINS_JSON = os.path.join(HERE, 'sip_cst_GW2AR-18C_eLQFP144P.json')
DB_ARC = 'apycula/GW2A-18C.msgpack.xz'

src_whl, outdir = sys.argv[1], sys.argv[2]
label = sys.argv[3] if len(sys.argv) > 3 else 'psram'

base_ver = re.match(r'apycula-([^-]+)-py3-none-any\.whl$', os.path.basename(src_whl), re.I).group(1)
new_ver = f'{base_ver}+{label}'
old_info, new_info = f'apycula-{base_ver}.dist-info', f'apycula-{new_ver}.dist-info'

with zipfile.ZipFile(src_whl) as z:
    files = {n: z.read(n) for n in z.namelist() if not n.endswith('/')}
assert DB_ARC in files and f'{old_info}/METADATA' in files

with open(PINS_JSON) as f:
    pins = json.load(f)
variant, package, partno = pins['variant'], pins['package'], pins['partnumber']
pinlist = [(net, int(row), int(col), bel, iostd) for net, row, col, bel, iostd in pins['pins']]
assert len({p[0] for p in pinlist}) == len({p[1:4] for p in pinlist}) == len(pinlist) == 26

with tempfile.TemporaryDirectory() as tmp:
    # usar el código de la misma versión de apycula que la base
    for n, d in files.items():
        if n.startswith('apycula/') and n.endswith('.py'):
            os.makedirs(os.path.join(tmp, os.path.dirname(n)), exist_ok=True)
            with open(os.path.join(tmp, n), 'wb') as f:
                f.write(d)
    sys.path.insert(0, tmp)
    from apycula import chipdb

    orig_path = os.path.join(tmp, 'orig.msgpack.xz')
    with open(orig_path, 'wb') as f:
        f.write(files[DB_ARC])
    db = chipdb.load_chipdb(orig_path)
    assert db.packages[partno][:2] == (package, variant), db.packages[partno]
    if package in db.sip_cst.get(variant, {}):
        sys.exit(f'apycula {base_ver} ya incluye sip_cst[{variant}][{package}]: no hace falta parche')

    bonded = {loc for loc, _cfg in db.pinout[variant][package].values()}
    for net, row, col, bel, _ in pinlist:
        assert f'IOB{bel}' in db[row, col].bels, (net, row, col, bel)
        side = 'L' if col == 0 else 'R' if col == db.cols - 1 else 'T' if row == 0 else 'B'
        num = col + 1 if side in 'TB' else row + 1
        assert f'IO{side}{num}{bel}' not in bonded, f'{net}: IO{side}{num}{bel} es un pin del paquete'

    db.sip_cst.setdefault(variant, {})[package] = pinlist
    new_path = os.path.join(tmp, 'new.msgpack.xz')
    chipdb.save_chipdb(db, new_path)

    # verificación: solo cambia la entrada nueva (comparación de objetos; los
    # bytes pueden diferir por el orden de serialización de sets/dicts)
    chk = chipdb.load_chipdb(new_path)
    assert sorted(chk.sip_cst[variant][package]) == sorted(pinlist)
    del chk.sip_cst[variant][package]
    assert chk == chipdb.load_chipdb(orig_path), 'la base cambió fuera de sip_cst'
    with open(new_path, 'rb') as f:
        files[DB_ARC] = f.read()


def rec_hash(data):
    return 'sha256=' + base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b'=').decode()


files = {(new_info + n[len(old_info):] if n.startswith(old_info + '/') else n): d for n, d in files.items()}
meta_key = f'{new_info}/METADATA'
meta = files[meta_key].decode()
assert f'\nVersion: {base_ver}\n' in meta
files[meta_key] = meta.replace(f'\nVersion: {base_ver}\n', f'\nVersion: {new_ver}\n', 1).encode()
record_key = f'{new_info}/RECORD'
files.pop(record_key, None)
lines = [f'{n},{rec_hash(d)},{len(d)}' for n, d in sorted(files.items())] + [f'{record_key},,']
files[record_key] = ('\n'.join(lines) + '\n').encode()

os.makedirs(outdir, exist_ok=True)
out = os.path.join(outdir, f'apycula-{new_ver}-py3-none-any.whl')
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for n in sorted(files, key=lambda a: (a.startswith(new_info), a)):
        # fecha fija: el wheel es reproducible byte a byte salvo la base xz
        z.writestr(zipfile.ZipInfo(n, date_time=(2026, 1, 1, 0, 0, 0)), files[n], zipfile.ZIP_DEFLATED)
print(out)
print('sha256', hashlib.sha256(open(out, 'rb').read()).hexdigest())
