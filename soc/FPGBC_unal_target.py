#!/usr/bin/env python3

#
# This file is part of LiteX-Boards.
# Tang Nano 20k
# Copyright (c) 2022 Icenowy Zheng <icenowy@aosc.io>
# Copyright (c) 2022 Florent Kermarrec <florent@enjoy-digital.fr>
# SPDX-License-Identifier: BSD-2-Clause
# Tang Nano 9k
# Copyright (c) 2022 Icenowy Zheng <icenowy@aosc.io>
# SPDX-License-Identifier: BSD-2-Clause
#
# Adaptado para FPGBC unal
#
from migen import *

from litex.gen import *

from litex.soc.cores.clock.gowin_gw2a import GW2APLL
from litex.soc.integration.soc import *
from litex.soc.integration.soc import SoCRegion
from litex.soc.integration.builder import *
from litex.soc.cores.gpio import GPIOIn

from litex.soc.cores.ram.gowin_hyperram import GowinHyperRAM

import FPGBC_unal_platform
# CRG ----------------------------------------------------------------------------------------------

class _CRG(LiteXModule):
    def __init__(self, platform, sys_clk_freq, with_hyperram):
        self.rst      = Signal()#Litex resuelve por detras
        self.cd_sys   = ClockDomain()
        self.cd_por   = ClockDomain()
        # Clk
        clk40 = platform.request("clk40")

        # Power on reset
        por_count = Signal(16, reset=2**16-1)
        por_done  = Signal()
        self.comb += self.cd_por.clk.eq(clk40)
        self.comb += por_done.eq(por_count == 0)
        self.sync.por += If(~por_done, por_count.eq(por_count - 1))

        # PLL
        self.pll = pll = GW2APLL(devicename=platform.devicename, device=platform.device)
        self.comb += pll.reset.eq(~por_done)
        pll.register_clkin(clk40, 40e6)
        pll.create_clkout(self.cd_sys, sys_clk_freq)

        # HyperRAM Clock.
        if with_hyperram:
            self.cd_sys4x = ClockDomain()
            pll.create_clkout(self.cd_sys4x, 4*sys_clk_freq)


# BaseSoC ------------------------------------------------------------------------------------------

class BaseSoC(SoCCore):
    def __init__(self, toolchain="apicula", sys_clk_freq=40e6,
        with_spi_flash       = False,
        with_game_buttons = False,
        with_volume_buttons = False,
        **kwargs):

        platform = FPGBC_unal_platform.Platform(toolchain=toolchain)
        # CRG --------------------------------------------------------------------------------------
        with_hyperram = not kwargs.get("integrated_main_ram_size", 0)

        self.crg = _CRG(platform, sys_clk_freq,with_hyperram)

        # SoCCore ----------------------------------------------------------------------------------
        class GB_Link_UART_Pads:
                pass
        gb_link_uart_pads = GB_Link_UART_Pads()
        gb_link_pads = platform.request("GB_Link")
        gb_link_uart_pads.tx = gb_link_pads.serial_out
        gb_link_uart_pads.rx = gb_link_pads.serial_in
        
        SoCCore.__init__(self, platform, sys_clk_freq, ident="LiteX SoC on FPGBC", uart_pads=gb_link_uart_pads, **kwargs)

        # SPI Flash: 25Q16JVSIQ ----------------------------------------------------------------------
        if with_spi_flash:
            from litespi.modules import W25Q16JV as SpiFlashModule
            from litespi.opcodes import SpiNorFlashOpCodes as Codes
            self.add_spi_flash(mode="1x", module=SpiFlashModule(Codes.READ_1_1_1))
        
        #HyperRAM/PSRAM ---------------------------------------------------------------------------------
        #https://github.com/litex-hub/litex-boards/blob/master/litex_boards/targets/sipeed_tang_nano_9k.py
        #if with_hyperram:
        #    class HyperRAMPads:
        #        pass
        #    hyperram_pads = HyperRAMPads()
        #    hyperram_pads.clk    = platform.request("O_psram_ck")
        #    hyperram_pads.clk_n  = platform.request("O_psram_ck_n")
        #    hyperram_pads.cs_n   = platform.request("O_psram_cs_n")
        #    hyperram_pads.rst_n  = platform.request("O_psram_reset_n")
        #    hyperram_pads.dq     = platform.request("IO_psram_dq")
        #    hyperram_pads.rwds   = platform.request("IO_psram_rwds")
        #    self.hyperram = GowinHyperRAM(hyperram_pads, sys_clk_freq=sys_clk_freq, clk_ratio="4:1")
        #    #Por que se usa ese clk ratio? Por velocidad, se puede acceder a los datos de la ram antes de que el procesador los necesite
        #    self.bus.add_slave("main_ram", slave=self.hyperram.bus, region=SoCRegion(origin=self.mem_map["main_ram"], size=4 * MEGABYTE, mode="rwx"))
        
        #La ram correcta es PSRAM https://github.com/YosysHQ/apicula/issues/332
        # que considerando instrucciones y datos de 32 bits se considera un _tamaño_ de $\frac{64e6}{8} \frac{1}{2} = 4MB$,

        # Buttons ----------------------------------------------------------------------------------
        if with_game_buttons:
            self.game_buttons = GPIOIn(pads=platform.request("game_buttons"))
        if with_volume_buttons:    
            self.volume_buttons = GPIOIn(pads=platform.request("volume_buttons"))
# Build --------------------------------------------------------------------------------------------

def main():
    from litex.build.parser import LiteXArgumentParser
    parser = LiteXArgumentParser(platform=FPGBC_unal_platform.Platform, description="LiteX SoC on Tang Nano 20K.")
    parser.add_target_argument("--flash",          action="store_true",      help="Flash bitstream.")
    #parser.add_target_argument("--prog-kit",       default="openfpgaloader", help="Programmer select from Gowin/openFPGALoader.")
    parser.add_target_argument("--sys-clk-freq",   default=40e6, type=float, help="System clock frequency.")
    #parser.add_target_argument("--with-spi-flash", action="store_true",      help="Enable memory-mapped SPI flash.")
    #parser.add_argument("--with-gb-link-uart",action="store_true",default=True,help="UART via GB Link Port")
    parser.set_defaults(
        cpu_type="femtorv",
        cpu_variant="quark",
        no_uart=False,
        toolchain="apicula")
    args = parser.parse_args()

    soc = BaseSoC(
        toolchain            = args.toolchain,
        sys_clk_freq         = args.sys_clk_freq,
        #with_spi_flash       = args.with_spi_flash,
        **parser.soc_argdict
    )

    builder = Builder(soc, **parser.builder_argdict)
    if args.build:
        builder.build(**parser.toolchain_argdict)

    if args.load:
        prog = soc.platform.create_programmer(kit=args.prog_kit)
        prog.load_bitstream(builder.get_bitstream_filename(mode="sram"))

    if args.flash:
        prog = soc.platform.create_programmer(kit=args.prog_kit)
        prog.flash(0, builder.get_bitstream_filename(mode="flash", ext=".fs"), external=True)

if __name__ == "__main__":
    main()
