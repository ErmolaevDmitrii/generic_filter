ICS55_ROOT = "55"

ICS55_STD_CELL_ROOT = ICS55_ROOT + "/IP/STD_cell/ics55_LLSC_H7C_V1p10C100"
ICS55_STD_CELL_H7CH_ROOT = ICS55_STD_CELL_ROOT + "/ics55_LLSC_H7CH"

ICS55_IO_ROOT = ICS55_ROOT + "/IP/IO/ICsprout_55LLULP1233_IO_251013"
ICS55_PRTECH_ROOT = ICS55_ROOT + "/prtech"

ICS55_TT_CORNER = struct(
    name = "tt",
    process = "typ_tt",
    core_voltage = "1p2",
    io_voltage = "3p3",
    temperature = "25c",
)

ICS55_TT_STD_CELL_LIBS = [
    ICS55_STD_CELL_H7CH_ROOT + "/liberty/ics55_LLSC_H7CH_typ_tt_1p2_25_nldm.lib",
]

ICS55_TT_IO_LIBS = [
    ICS55_IO_ROOT + "/liberty/ICSIOA_N55_3P3_tt_1p2_3p3_25c.lib",
]

ICS55_TECH_LEFS = [
    ICS55_PRTECH_ROOT + "/techLEF/N551P6M.lef",
]

ICS55_STD_CELL_LEFS = [
    ICS55_STD_CELL_H7CH_ROOT + "/lef/ics55_LLSC_H7CH.lef",
    ICS55_STD_CELL_H7CH_ROOT + "/lef/ics55_LLSC_H7CH_ant.lef",
]

ICS55_IO_LEFS = [
    ICS55_IO_ROOT + "/lef/ICSIOA_N55_3P3_1P6M1TM.lef",
]

ICS55_VERILOG_MODELS = [
    ICS55_STD_CELL_H7CH_ROOT + "/verilog/ics55_LLSC_H7CH.v",
    ICS55_IO_ROOT + "/verilog/icsIOA_N55_3P3.v",
]

ICS55_CDL_NETLISTS = [
    ICS55_STD_CELL_H7CH_ROOT + "/cdl/ics55_LLSC_H7CH.cdl",
    ICS55_IO_ROOT + "/cdl/ICSIOA_N55_3P3.cdl",
]

ICS55_GDS_FILES = [
    ICS55_STD_CELL_H7CH_ROOT + "/gds/ics55_LLSC_H7CH.gds",
    ICS55_STD_CELL_H7CH_ROOT + "/gds/ics55_LLSC_H7CH_M2.gds",
    ICS55_IO_ROOT + "/gds/ICSIOA_N55_3P3_1P6M1TM.gds",
]

ICS55_TT_FILES = struct(
    corner = ICS55_TT_CORNER,
    std_cell_libs = ICS55_TT_STD_CELL_LIBS,
    io_libs = ICS55_TT_IO_LIBS,
    liberty = ICS55_TT_STD_CELL_LIBS + ICS55_TT_IO_LIBS,
    tech_lefs = ICS55_TECH_LEFS,
    std_cell_lefs = ICS55_STD_CELL_LEFS,
    io_lefs = ICS55_IO_LEFS,
    lefs = ICS55_TECH_LEFS + ICS55_STD_CELL_LEFS + ICS55_IO_LEFS,
    verilog_models = ICS55_VERILOG_MODELS,
    cdl_netlists = ICS55_CDL_NETLISTS,
    gds = ICS55_GDS_FILES,
    all_files = (
        ICS55_TT_STD_CELL_LIBS +
        ICS55_TT_IO_LIBS +
        ICS55_TECH_LEFS +
        ICS55_STD_CELL_LEFS +
        ICS55_IO_LEFS +
        ICS55_VERILOG_MODELS +
        ICS55_CDL_NETLISTS +
        ICS55_GDS_FILES
    ),
)
