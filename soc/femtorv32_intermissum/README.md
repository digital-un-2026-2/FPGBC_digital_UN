# Soporte para interrupciones
Soporte para interrupciones de el [FemtoRV Intermissum](https://github.com/BrunoLevy/learn-fpga/blob/master/FemtoRV/RTL/PROCESSOR/femtorv32_intermissum.v), este procesador tiene una sola linea de interrupción mientras que LiteX espera hasta 32.

Se identifica la capacidad de interrupción con un atributo `interrupt` en la clase de Python asociada al procesador, sin embargo esto no es suficiente y se debe ofrecer una capa que permita habilitar y identificar la fuente de la interrupción además de ejecutar el Interrupt Service Routine adecuado.
## Lado hardware
### Procesador
El FemtoRV Intermissum utiliza Control & Status Registers(CSR) internos :
- `mtvec` Para guardar la dirección del Interrupt Service Routine
- `mstatus` Para habilitar las interrupciones
- `mepc` Para guardar el Contador de Programa

`mtvec` debe ser configurado, LiteX utiliza [`crt0.S`](https://github.com/enjoy-digital/litex/blob/master/litex/soc/cores/cpu/femtorv/crt0.S) para hacer esto.

### Wrap para LiteX
Desde el hardware se crea el atributo `interrupt = Signal(32)` el cual permite al ecosistema de LiteX identificar que el procesador soporta interrupciones y asignar interrupciones desde los periféricos como UART o Timer.

Para la habilitación y identificación se utilizan CSR externos al procesador, sean `cpu_irq_mask` y `cpu_irq_pending`. Estos son accesibles desde software y LiteX genera las funciones en C básicas para su manejo.

Estos registros y la señal de interrupciones se componen para enviar una única señal al procesador mediante su pin `i_interrupt_request` cuando sucede alguna interrupción.

## Lado Software
### IRQ (Interrupt Request)
Se debe ofrecer una capa de software para utilizar las interrupciones, por ejemplo para el procesador VexRiscv se ofrece [irq.h](https://github.com/enjoy-digital/litex/blob/master/litex/soc/cores/cpu/vexriscv/irq.h) que ofrece funciones para habilitar y identificar las interrupciones, para esto se accede a CSR internos de el procesador que son los encargados de las interrupciones.

Para el caso de FemtoRV LiteX no ofrece esta abstracción, sin embargo, se puede seguir un enfoque similar con los CSR internos y externos ya creados.

Así se implementan las funciones :
- `irq_getie` Utiliza `mstatus` para conocer si están activas las interrupciones
- `irq_setie(ie)` Utiliza `mstatus` como habilitador global de interrupciones
- `irq_getmask` Utiliza `cpu_irq_mask` para obtener las interrupciones habilitadas
- `irq_setmask(mask)` Utiliza `cpu_irq_mask` para habilitar las interrupciones
- `irq_pending` Utiliza `cpu_irq_pending`para conocer la interrupción/es pendientes

Estas funciones son utilizadas en otras piezas de código donde se necesite acceder o modificar información de interrupciones.

### ISR (Interrupt Service Routine)
Tambien se debe ofrecer una capa para registrar y ejecutar rutinas según se necesite, LiteX ofrece [`isr.c`](https://github.com/enjoy-digital/litex/blob/master/litex/soc/software/libbase/isr.c) para realizar esto.

LiteX utiliza un arreglo donde almacena la dirección de las ISR y lo itera mientras alguna interrupción este pendiente.

Se ofrecen las funciones:
- `irq_attach(n_irq,addr)` Se asigna la dirección de la rutina objetivo a cierto número de interrupción, esto no habilita la interrupción asociada.
- `irq_detach(n_irq)` Elimina la rutina asociada al número de interrupción, esto no deshabilita la interrupción asociada.
- `isr` Función principal para ejecutar las ISR, llamada en `crt0.S`, utiliza `irq_pending` y `irq_getmask` para saber que interrupciones tiene que ejecutar, itera de menor a mayor numero de interrupción y deshabilita interrupciones que no tengan ISR asociada.

## Ejemplo UART
Cuando se tiene soporte para interrupciones el periférico UART de LiteX las usa por defecto, ver [`uart.c`](https://github.com/enjoy-digital/litex/blob/master/litex/soc/software/libbase/uart.c) 


## Uso
En general cuando se añada un periférico de LiteX(ej. Timer, GPIO, ...) este se conectara por hardware a la señal de interrupción, se le asignara un número de interrupción y se generan otros CSR relacionados al periférico. Desde el lado de software el usuario implementa el ISR asociado al periférico y lo registra con `irq_attach`.
