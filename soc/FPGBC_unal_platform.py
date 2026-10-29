#
# This file is part of LiteX-Boards.
# Tang Nano 20k
# Copyright (c) 2023 Icenowy Zheng <uwu@icenowy.me>
# SPDX-License-Identifier: BSD-2-Clause
#
# Adaptado para FPGBC unal
#

from migen import *

from litex.build.generic_platform import *
from litex.build.gowin.platform import GowinPlatform
from litex.build.gowin.programmer import GowinProgrammer
from litex.build.openfpgaloader import OpenFPGALoader


# IOs ----------------------------------------------------------------------------------------------

_io = [
    # Clk / Rst.
    ("clk40",  0, Pins("11"), IOStandard("LVCMOS33")),

    # GB Link.
    ("GB_Link", 0,
        Subsignal("serial_out", Pins("28")),
        Subsignal("serial_in", Pins("27")),
        Subsignal("clk",Pins("30")),
        Subsignal("clk_oe",Pins("29")),
        IOStandard("LVCMOS33")
    ),

    # SPIFlash.
    ("spiflash", 0,
        Subsignal("cs_n", Pins("94")),
        Subsignal("clk",  Pins("93")),
        Subsignal("miso", Pins("96")),
        Subsignal("mosi", Pins("95")),
        IOStandard("LVCMOS33")
    ),
    
    # EEPROM I2C
    ("eeprom_i2c", 0,
        Subsignal("scl", Pins("24")),
        Subsignal("sda", Pins("23")),
        IOStandard("LVCMOS33")
    ),    

    # Buttons.
    ("game_buttons",0,
        Subsignal("a", Pins("50")),
        Subsignal("b", Pins("51")),
        Subsignal("start", Pins("97")),
        Subsignal("select", Pins("98")),
        Subsignal("right", Pins("99")),
        Subsignal("up", Pins("100")),
        Subsignal("down", Pins("101")),
        Subsignal("left", Pins("102")),
        IOStandard("LVCMOS33"),
        Misc("PULL_MODE=UP")
    ),

    ("volume_buttons",0,
        Subsignal("up", Pins("119")),
        Subsignal("push", Pins("120")),
        Subsignal("down",Pins("121")),
        IOStandard("LVCMOS33"),
        Misc("PULL_MODE=UP")
    ),


    #MIPI LDC TODO

    #Cartridge TODO

    # PSRAM Interna
    # https://github.com/litex-hub/litex-boards/blob/master/litex_boards/platforms/sipeed_tang_nano_9k.py
    #("O_psram_ck",      0, Pins(2)),
    #("O_psram_ck_n",    0, Pins(2)),
    #("O_psram_cs_n",    0, Pins(2)),
    #("O_psram_reset_n", 0, Pins(2)),
    #("IO_psram_dq",     0, Pins(16)),
    #("IO_psram_rwds",   0, Pins(2)),
]

# Platform -----------------------------------------------------------------------------------------

class Platform(GowinPlatform):
    default_clk_name   = "clk40"
    default_clk_period = 1e9/40e6 # 25ns

    def __init__(self, toolchain="apicula"):

        GowinPlatform.__init__(self, "GW2AR-LV18EQ144PC8/I7", _io, toolchain=toolchain, devicename="GW2AR-18C")
        #self.toolchain.options["use_mspi_as_gpio"]  = 1
        #self.toolchain.options["use_sspi_as_gpio"]  = 1
        #self.toolchain.options["use_ready_as_gpio"] = 1
        #self.toolchain.options["use_done_as_gpio"]  = 1
        #self.toolchain.options["rw_check_on_ram"]   = 1

    def create_programmer(self, kit="openfpgaloader"):
        #if kit == "gowin":
        #    return GowinProgrammer(self.devicename)
        if kit == "openfpgaloader":
            return OpenFPGALoader(cable="ft232RL")
        else:
            raise ValueError(f"Unsupported programmer kit: {kit}")

    def do_finalize(self, fragment):
        GowinPlatform.do_finalize(self, fragment)
        self.add_period_constraint(self.lookup_request(self.default_clk_name, loose=True), self.default_clk_period)
