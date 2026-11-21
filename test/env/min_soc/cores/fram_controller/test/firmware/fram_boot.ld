/* Linker script de la prueba FRAM, basado en bram.ld de digital_UN
 * (basic_circuits/test_peripherals/firmware/asm).
 *
 * Cambios respecto a bram.ld:
 *   - fram_boot.o (.text) va primero, en la dirección 0 (arranque).
 *   - Se define calculator_inicio justo antes de calculator.o (.text), para
 *     que fram_boot.S sepa a dónde saltar en la FRAM.
 */
MEMORY {
   BRAM (RWX) : ORIGIN = 0x0000, LENGTH = 0x1000  /* 4 KiB, igual que bram.ld */
}
SECTIONS
{
    everything :
    {
        . = ALIGN(4);
        fram_boot.o (.text)
        . = ALIGN(4);
        calculator_inicio = .;
        calculator.o (.text)
        *(.*)
    } >BRAM
}
