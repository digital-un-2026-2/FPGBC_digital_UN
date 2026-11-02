#ifndef __IRQ_H
#define __IRQ_H

#include <system.h>
#include <generated/csr.h>
#include <generated/soc.h>

static inline unsigned int irq_getie(void)
{
    unsigned int mstatus;//CSR Interno a conseguir
    asm volatile("csrr %0, mstatus" : "=r"(mstatus));
    return (mstatus & 0x8) !=0;
}

static inline void irq_setie(unsigned int ie)
{
    if (ie)
        asm volatile("csrrs zero, mstatus, 0x8");//Activar interrupciones
    else 
        asm volatile("csrrc zero, mstatus, 0x8");
}

static inline unsigned int irq_getmask(void)
{
#ifdef CSR_CPU_IRQ_MASK_ADDR
    return cpu_irq_mask_read();//en csr.h
#else
    return 0;
#endif
}
static inline void irq_setmask(unsigned int mask)
{
#ifdef CSR_CPU_IRQ_MASK_ADDR
    cpu_irq_mask_write(mask);
#endif
}

static inline unsigned int irq_pending(void)
{
#ifdef CSR_CPU_IRQ_PENDING_ADDR
    return cpu_irq_pending_read();
#else
    return 0;
#endif
}

#endif /* __IRQ_H */