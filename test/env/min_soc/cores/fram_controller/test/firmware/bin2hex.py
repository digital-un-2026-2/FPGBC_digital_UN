#!/usr/bin/env python3
"""Convierte un binario plano en el formato que lee bram.v ($readmemh):
una palabra de 32 bits (little-endian) por línea, completando con ceros
hasta el tamaño de la BRAM."""

import sys

PALABRAS = 1024  # bram.v (digital_UN): reg [31:0] MEM [0:1023]


def main():
    if len(sys.argv) != 3:
        sys.exit(f"uso: {sys.argv[0]} entrada.bin salida.hex")

    with open(sys.argv[1], "rb") as f:
        datos = f.read()

    if len(datos) > PALABRAS * 4:
        sys.exit(f"el firmware ocupa {len(datos)} bytes, la BRAM tiene {PALABRAS * 4}")

    datos += bytes(PALABRAS * 4 - len(datos))
    with open(sys.argv[2], "w") as f:
        for i in range(PALABRAS):
            f.write(f"{int.from_bytes(datos[4 * i:4 * i + 4], 'little'):08x}\n")

    print(f"{sys.argv[2]}: {len(datos.rstrip(bytes(1)))} bytes de firmware")


if __name__ == "__main__":
    main()
