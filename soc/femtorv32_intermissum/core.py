import os

from migen import *

from litex.gen import *

from litex.soc.cores.cpu.femtorv import FemtoRV
from litex.soc.cores.cpu import CPUS
from litex.soc.interconnect.csr import CSRStorage,CSRStatus,AutoCSR

# Soporte para interrupciones del FemtoRV Intermissum
class FemtoRVIntermissumIRQ(FemtoRV, AutoCSR):
    def __init__(self,platform,variant="intermissum"):
        FemtoRV.__init__(self,platform,variant="intermissum")

        self.interrupt = Signal(32)
        self._irq_mask = CSRStorage(32)
        self._irq_pending = CSRStatus(32)

        irq_wire = Signal()
        self.comb += [
            self._irq_pending.status.eq(self.interrupt),
            irq_wire.eq((self.interrupt & self._irq_mask.storage)!=0)
        ]

        self.cpu_params.update(i_interrupt_request=irq_wire)

    @staticmethod
    def add_sources(platform, variant):
        src_dir = os.path.abspath(os.path.dirname(__file__))
        #platform.add_verilog_include_path(src_dir)
        platform.add_source(os.path.join(src_dir,"femtorv32_intermissum.v"))

CPUS["femtorv"] = FemtoRVIntermissumIRQ