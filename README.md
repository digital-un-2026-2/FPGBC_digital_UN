# FPGBC digital UN

Repositorio principal para la ingeniería inversa de la [FPGBC](https://funnyplaying.com/products/fpgbc-kit) y el desarrollo propio en hardware y software.

## Herramientas
Para el proyecto se utilizan las siguientes herramientas
- [Yosys](https://github.com/YosysHQ/yosys)
- [nextpnr](https://github.com/YosysHQ/nextpnr) en su versión para [Gowin](https://www.gowinsemi.com/) via [YoWASP](https://yowasp.org/)
- [Project Apicula](https://github.com/YosysHQ/apicula)
- [openFPGALoader](https://github.com/trabucayre/openFPGALoader)
- [LiteX](https://github.com/enjoy-digital/litex/)
- [gtkwave](https://github.com/gtkwave/gtkwave)
- [RISC-V GNU Compiler Toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain)

## Instalación de Herramientas
Para facilitar la instalación y evitar problemas asociados a rutas y dependencias se utiliza [Pixi](https://pixi.prefix.dev/v0.82.0/)

1. Instalar Pixi con [oneliner](https://pixi.prefix.dev/v0.82.0/installation/)

```bash
curl -fsSL https://pixi.sh/install.sh | sh
```

2. Copiar este repositorio y entrar a la carpeta
```bash
git clone https://github.com/digital-un-2026-2/FPGBC_digital_UN.git
cd FPGBC_digital_UN
```

3. Instalar el espacio de trabajo
```bash
[ FPGBC_digital_UN]$ pixi install
```

4. Probar que se han instalado las herramientas(ser paciente)
```bash
[ FPGBC_digital_UN]$ pixi run test-EDA
```

## Diagrama de bloques
![bloques](/blocks/out.svg)

## Conexiones por integrado
### FPGA
### Memoria Flash
### Memoria EEPROM
### MCU
### Convertidores de nivel
### Amplificador de audio

