# Pines internos de la PSRAM — GW2AR-LV18EQ144PC8/I7 (eLQFP144P)

`sip_cst_GW2AR-18C_eLQFP144P.json` es la entrada `sip_cst["GW2AR-18C"]["eLQFP144P"]` que falta en
apycula (hasta la 0.35). Su formato es `(net, row, col, bel, iostd)`, en la base GW2A-18C (55×56).
nextpnr la usa para restringir por nombre los puertos `O_psram_*` / `IO_psram_*` a los IOB internos
(`himbaechel/uarch/gowin/cst.cc: add_sip_constraints`).

`make_wheel.py` toma el wheel oficial de apycula, añade la entrada en `GW2A-18C.msgpack.xz`, verifica
que el resto de la base no cambia y genera `apycula-X.Y+psram-py3-none-any.whl`.

## Cómo se obtuvieron

1. Se hizo un diseño con el IP PSRAM HS de Gowin (2 canales) para GW2AR-LV18EQ144PC8/I7, que pasó por
   síntesis y PnR en Gowin IDE 1.9.12.04. El reporte de PnR muestra cada puerto en un pin SiP (`pX-Y`)
   y su IOB interno.
2. El fuzzer de apycula (`chipdb_builder.run_sdram_script`) generó un diseño con un `TBUF` por señal,
   lo pasó por el PnR de Gowin y siguió el ruteo en el bitstream hasta el IOB interno.
3. Ambos métodos coinciden en 24 de 26 señales. Solo difieren en `O_psram_ck[1]` / `O_psram_ck_n[1]`,
   y se usa el resultado del fuzzer: el reporte de Gowin coloca ese par como diferencial (positivo en A),
   mientras que la conexión física es la inversa. Es el mismo caso que la entrada que ya existe en
   apycula para el GW1NR-9C.
4. Se verificó en hardware con LiteX (`GowinHyperRAM`, canal 0) en la FPGBC.

| Canal | Lado / banco | Señales |
|---|---|---|
| 0 | derecho (IOR, col 55), banco 2 | `ck[0]` IOR8A, `ck_n[0]` IOR8B, `cs_n[0]` IOR9A, `reset_n[0]` IOR12B, `rwds[0]` IOR3A, `dq[7:0]` |
| 1 | izquierdo (IOL, col 0), banco 7 | `ck[1]` IOL11B, `ck_n[1]` IOL11A, `cs_n[1]` IOL9B, `reset_n[1]` IOL3A, `rwds[1]` IOL15B, `dq[15:8]` |
