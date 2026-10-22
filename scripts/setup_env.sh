#!/bin/bash

BIN_DIR="$CONDA_PREFIX/bin"
ln -sf "$BIN_DIR/yowasp-nextpnr-himbaechel-gowin" "$BIN_DIR/nextpnr-himbaechel-gowin"

# Definir versión y ubicación de instalación local (carpeta oculta en el proyecto)
TOOLCHAIN_VERSION="15.2.0-1"
TOOLCHAIN_NAME="xpack-riscv-none-elf-gcc-${TOOLCHAIN_VERSION}"
TOOLCHAIN_DIR="$PIXI_PROJECT_ROOT/.toolchain"
TOOLCHAIN_BIN="$TOOLCHAIN_DIR/bin/riscv-none-elf-gcc"
URL="https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v${TOOLCHAIN_VERSION}/${TOOLCHAIN_NAME}-linux-x64.tar.gz"

# 1. Verificar si el binario ya existe y es ejecutable
if [ ! -x "$TOOLCHAIN_BIN" ]; then
    #echo "⚙️  Toolchain RISC-V no encontrado. Descargando..."
    mkdir -p "$TOOLCHAIN_DIR"
    
    # Descargar y extraer al vuelo. Si falla, aborta limpiamente sin cerrar la terminal
    if curl -L -s "$URL" | tar -xz -C "$TOOLCHAIN_DIR"; then
        echo "✅ Toolchain instalado en $TOOLCHAIN_DIR"
    else
        #echo "❌ Error al descargar o extraer el toolchain."
        exit 1 
    fi
fi

# 2. Configurar variables de entorno
export PATH="$TOOLCHAIN_DIR/bin:$PATH"

#export CROSS_COMPILE="riscv-none-elf-"