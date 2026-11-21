# Arranque de la prueba en hardware del controlador FRAM.
#
# Se enlaza en la dirección 0 (antes de calculator.S):
#   1. Copia toda la BRAM (4 KB, tamaño de bram.v) a la FRAM del cartucho.
#   2. Verifica la copia palabra por palabra e imprime por la UART, para
#      todo el contenido, la dirección de la FRAM, la palabra esperada
#      (BRAM) y la palabra leída (FRAM); marca las que no coinciden.
#   3. Si no hay errores, salta a FRAM_BASE + calculator_inicio, es decir, a
#      la copia de calculator.S en la FRAM: desde ahí el procesador busca las
#      instrucciones en la FRAM.
#
# calculator_inicio lo define el linker script (fram_boot.ld) justo antes de
# calculator.o (.text), porque la etiqueta "calculator" no es global.
#
# Las rutinas de impresión de este archivo (uart_tx, print_str, print_hex)
# no usan la pila: la pila está en la BRAM que se compara, y putchar /
# putstring de digital_UN guardan registros en ella, lo que cambiaría las
# últimas palabras de la BRAM y daría falsos errores en la verificación.
#
# Salida por la UART (57600 baudios, ~30 caracteres por palabra, ~5 s):
#   BRAM -> FRAM: copiando 4 KB... listo
#   Verificando la copia
#   direccion  esperada  leida
#   00480000   00001137  00001137
#   ...
#   00480FFC   00000000  00000000
#   Palabras con error: 0x0000 de 0x0400
#   OK: ejecutando calculator desde la FRAM

.equ FRAM_BASE,    0x480000   # FRAM: 0x00480000 - 0x0049FFFF
.equ BRAM_SIZE,    0x1000     # bram.v: 1024 palabras de 32 bits

.equ UART_BASE,    0x400000   # igual que putchar.S
.equ IO_UART_DAT,  8
.equ IO_UART_CNTL, 16
.equ UART_TX_BUSY, 1 << 9     # bit tx_busy de IO_UART_CNTL

.equ ASCII_0,      48         # '0'
.equ ASCII_9,      57         # '9'
.equ HEX_LETRA,    7          # 'A' - '9' - 1

.section .text
.globl fram_boot

# Registros que conservan su valor a través de las llamadas:
#   s1  ra de print_hex      s2  ra de print_str
#   s3  dirección BRAM       s4  dirección FRAM
#   s5  fin (BRAM_SIZE)      s6  número de palabras con error
#   s7  palabra esperada     s8  palabra leída

fram_boot:
    li   sp, 0x1000            # para calculator (aquí no se usa la pila)
    la   a0, msg_copia
    jal  ra, print_str

    # ---- Copia BRAM -> FRAM ----
    li   t2, 0
    li   t3, FRAM_BASE
    li   t4, BRAM_SIZE
copia:
    lw   t5, 0(t2)
    sw   t5, 0(t3)
    addi t2, t2, 4
    addi t3, t3, 4
    bltu t2, t4, copia

    la   a0, msg_verifica
    jal  ra, print_str

    # ---- Verificación de todo el contenido ----
    li   s3, 0
    li   s4, FRAM_BASE
    li   s5, BRAM_SIZE
    li   s6, 0
verifica:
    lw   s7, 0(s3)             # esperada (BRAM)
    lw   s8, 0(s4)             # leída (FRAM)

    mv   a0, s4                # dirección en la FRAM
    li   a1, 8
    jal  ra, print_hex
    la   a0, msg_sep_dir
    jal  ra, print_str
    mv   a0, s7
    li   a1, 8
    jal  ra, print_hex
    la   a0, msg_sep
    jal  ra, print_str
    mv   a0, s8
    li   a1, 8
    jal  ra, print_hex

    beq  s7, s8, verifica_sig
    addi s6, s6, 1
    la   a0, msg_marca
    jal  ra, print_str
verifica_sig:
    la   a0, msg_nl
    jal  ra, print_str
    addi s3, s3, 4
    addi s4, s4, 4
    bltu s3, s5, verifica

    # ---- Resumen ----
    la   a0, msg_resumen
    jal  ra, print_str
    mv   a0, s6
    li   a1, 4
    jal  ra, print_hex
    la   a0, msg_de
    jal  ra, print_str
    li   a0, BRAM_SIZE / 4
    li   a1, 4
    jal  ra, print_hex
    la   a0, msg_nl
    jal  ra, print_str
    bnez s6, error_copia

    la   a0, msg_salto
    jal  ra, print_str

    # ---- Salto a calculator en la FRAM ----
    la   t0, calculator_inicio # dirección en la BRAM
    li   t1, FRAM_BASE
    add  t0, t0, t1
    jr   t0

error_copia:
    la   a0, msg_error
    jal  ra, print_str
fin_error:
    j    fin_error

# ---- uart_tx: envía el byte a0 (misma secuencia que putchar.S) ----
# Usa t0, t1, gp. Hoja: no llama a otras rutinas ni usa la pila.
uart_tx:
    li   gp, UART_BASE
    sw   a0, IO_UART_DAT(gp)
    li   t0, 1
    sw   t0, IO_UART_CNTL(gp)  # tx_wr = 1
    sw   zero, IO_UART_CNTL(gp) # tx_wr = 0
    li   t0, UART_TX_BUSY
uart_tx_espera:
    lw   t1, IO_UART_CNTL(gp)
    and  t1, t1, t0
    bnez t1, uart_tx_espera
    ret

# ---- print_str: envía la cadena terminada en 0 que apunta a0 ----
# Usa a0, a1, t0, t1, gp; guarda ra en s2.
print_str:
    mv   s2, ra
    mv   a1, a0
print_str_sig:
    lbu  a0, 0(a1)
    beqz a0, print_str_fin
    jal  ra, uart_tx
    addi a1, a1, 1
    j    print_str_sig
print_str_fin:
    mv   ra, s2
    ret

# ---- print_hex: envía en hexadecimal los a1 nibbles bajos de a0 ----
# (a1 = 1..8, del más significativo al menos). Usa a0-a3, t0, t1, gp;
# guarda ra en s1.
print_hex:
    mv   s1, ra
    mv   a2, a0
    slli a3, a1, 2             # desplazamiento inicial = 4 * a1
print_hex_sig:
    addi a3, a3, -4
    srl  a0, a2, a3
    andi a0, a0, 0xF
    addi a0, a0, ASCII_0
    li   t0, ASCII_9
    ble  a0, t0, print_hex_tx
    addi a0, a0, HEX_LETRA     # 10..15 -> 'A'..'F'
print_hex_tx:
    jal  ra, uart_tx
    bnez a3, print_hex_sig
    mv   ra, s1
    ret

.section .data
msg_copia:
    .asciz "\n\rBRAM -> FRAM: copiando 4 KB..."
msg_verifica:
    .asciz " listo\n\rVerificando la copia\n\rdireccion  esperada  leida\n\r"
msg_sep_dir:
    .asciz "   "
msg_sep:
    .asciz "  "
msg_marca:
    .asciz "  <- ERROR"
msg_nl:
    .asciz "\n\r"
msg_resumen:
    .asciz "Palabras con error: 0x"
msg_de:
    .asciz " de 0x"
msg_salto:
    .asciz "OK: ejecutando calculator desde la FRAM\n\r"
msg_error:
    .asciz "ERROR: la copia no coincide, no se ejecuta desde la FRAM\n\r"
