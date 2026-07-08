load("//tools/bazel:sv_rules.bzl", "SvInfo")

def _strip_prefix(path, prefix):
    if path.startswith(prefix):
        return path[len(prefix):]
    return path

def _copy_dest(file, root):
    short_path = file.short_path
    short_path = _strip_prefix(short_path, "../")
    short_path = _strip_prefix(short_path, "bazel-out/")
    return root + "/" + short_path

def _script_dest(file, vendor):
    return "scripts/" + vendor + "/" + file.basename

def _shell_value(value):
    if "'" in value:
        fail("FPGA package values must not contain single quotes: %s" % value)
    return "'" + value + "'"

def _fpga_package_impl(ctx):
    if ctx.attr.synthesis_mode not in ["top", "out_of_context"]:
        fail(
            "synthesis_mode must be 'top' or 'out_of_context', got %s" %
            ctx.attr.synthesis_mode,
        )
    if ctx.attr.vendor not in ["xilinx", "altera"]:
        fail("vendor must be 'xilinx' or 'altera', got %s" % ctx.attr.vendor)
    if ctx.attr.xdc and ctx.attr.sdc:
        fail("Only one of xdc or sdc may be set")
    if ctx.attr.vendor == "xilinx" and ctx.attr.sdc:
        fail("Use xdc constraints for xilinx packages")
    if ctx.attr.vendor == "altera" and ctx.attr.xdc:
        fail("Use sdc constraints for altera packages")
    if ctx.attr.virtual_pins not in ["0", "1", "false", "true", "off", "on", "no", "yes"]:
        fail(
            "virtual_pins must be one of on/off, true/false, yes/no, or 1/0, got %s" %
            ctx.attr.virtual_pins,
        )
    if ctx.attr.clean_project not in ["0", "1", "false", "true", "off", "on", "no", "yes"]:
        fail(
            "clean_project must be one of on/off, true/false, yes/no, or 1/0, got %s" %
            ctx.attr.clean_project,
        )
    if ctx.attr.device_db_check not in ["0", "1", "false", "true", "off", "on", "no", "yes"]:
        fail(
            "device_db_check must be one of on/off, true/false, yes/no, or 1/0, got %s" %
            ctx.attr.device_db_check,
        )

    rtl_infos = [dep[SvInfo] for dep in ctx.attr.rtl_deps if SvInfo in dep]
    rtl_srcs = depset(
        transitive = [info.srcs for info in rtl_infos],
        order = "postorder",
    ).to_list()
    script_files = ctx.files.scripts
    constraint_file = ctx.file.xdc if ctx.attr.vendor == "xilinx" else ctx.file.sdc

    rtl_lines = [_copy_dest(f, "rtl") for f in rtl_srcs]
    package_constraint = ""
    if constraint_file:
        package_constraint = "constraints/" + constraint_file.basename

    design_env_lines = [
        "FPGA_PACKAGE_TOP=%s" % _shell_value(ctx.attr.top_module),
        "FPGA_PACKAGE_PART=%s" % _shell_value(ctx.attr.part),
        "FPGA_PACKAGE_CLOCK_PORT=%s" % _shell_value(ctx.attr.clock_port),
        "FPGA_PACKAGE_CLOCK_PERIOD=%s" % _shell_value(ctx.attr.clock_period),
        "FPGA_PACKAGE_INPUT_DELAY=%s" % _shell_value(ctx.attr.input_delay),
        "FPGA_PACKAGE_OUTPUT_DELAY=%s" % _shell_value(ctx.attr.output_delay),
    ]
    package_lines = [
        "name: %s" % ctx.label.name,
        "vendor: %s" % ctx.attr.vendor,
        "top_module: %s" % ctx.attr.top_module,
        "part: %s" % ctx.attr.part,
    ]

    if ctx.attr.vendor == "xilinx":
        design_env_lines.extend([
            "FPGA_PACKAGE_SYNTHESIS_MODE=%s" % _shell_value(ctx.attr.synthesis_mode),
            "FPGA_PACKAGE_FILELIST='manifest/rtl.f'",
            "FPGA_PACKAGE_XDC=%s" % _shell_value(package_constraint),
        ])
        package_lines.extend([
            "clock_port: %s" % ctx.attr.clock_port,
            "clock_period_ns: %s" % ctx.attr.clock_period,
            "input_delay_ns: %s" % ctx.attr.input_delay,
            "output_delay_ns: %s" % ctx.attr.output_delay,
            "synthesis_mode: %s" % ctx.attr.synthesis_mode,
            "rtl_files: %d" % len(rtl_srcs),
            "xdc: %s" % (package_constraint if package_constraint else "<generated clock and I/O constraints>"),
            "",
            "Run after unpacking:",
            "  ./scripts/xilinx/run_vivado.sh",
            "",
            "Override settings with TOP, PART, CLOCK_PORT, CLOCK_PERIOD, INPUT_DELAY,",
            "OUTPUT_DELAY, SYNTHESIS_MODE, XDC_FILE, OUT_DIR, INCLUDE_DIRS, or",
            "VIVADO_BIN environment variables.",
            "",
        ])
    else:
        design_env_lines.extend([
            "FPGA_PACKAGE_FAMILY=%s" % _shell_value(ctx.attr.family),
            "FPGA_PACKAGE_FILELIST='manifest/rtl.f'",
            "FPGA_PACKAGE_SDC=%s" % _shell_value(package_constraint),
            "FPGA_PACKAGE_PROJECT_NAME=%s" % _shell_value(ctx.attr.project_name if ctx.attr.project_name else ctx.label.name),
            "FPGA_PACKAGE_VIRTUAL_PINS=%s" % _shell_value(ctx.attr.virtual_pins),
            "FPGA_PACKAGE_CLEAN_PROJECT=%s" % _shell_value(ctx.attr.clean_project),
            "FPGA_PACKAGE_DEVICE_DB_CHECK=%s" % _shell_value(ctx.attr.device_db_check),
        ])
        package_lines.extend([
            "family: %s" % (ctx.attr.family if ctx.attr.family else "<derived from device>"),
            "clock_port: %s" % ctx.attr.clock_port,
            "clock_period_ns: %s" % ctx.attr.clock_period,
            "input_delay_ns: %s" % ctx.attr.input_delay,
            "output_delay_ns: %s" % ctx.attr.output_delay,
            "rtl_files: %d" % len(rtl_srcs),
            "sdc: %s" % (package_constraint if package_constraint else "<generated clock and I/O constraints>"),
            "",
            "Run after unpacking:",
            "  ./scripts/altera/run_quartus.sh",
            "",
            "Override settings with TOP, PART, FAMILY, CLOCK_PORT, CLOCK_PERIOD,",
            "INPUT_DELAY, OUTPUT_DELAY, PROJECT_NAME, SDC_FILE, OUT_DIR,",
            "INCLUDE_DIRS, VIRTUAL_PINS, CLEAN_PROJECT, DEVICE_DB_CHECK,",
            "or QUARTUS_SH_BIN environment variables.",
            "",
        ])
    design_env_lines.append("")

    rtl_filelist = ctx.actions.declare_file(ctx.label.name + "_rtl.f")
    design_env = ctx.actions.declare_file(ctx.label.name + "_design.env")
    package_txt = ctx.actions.declare_file(ctx.label.name + "_README.txt")

    ctx.actions.write(rtl_filelist, "\n".join(rtl_lines) + "\n")
    ctx.actions.write(design_env, "\n".join(design_env_lines))
    ctx.actions.write(package_txt, "\n".join(package_lines))

    copies = []
    inputs = []
    for f in rtl_srcs:
        inputs.append(f)
        copies.extend([f.path, _copy_dest(f, "rtl")])
    for f in script_files:
        inputs.append(f)
        copies.extend([f.path, _script_dest(f, ctx.attr.vendor)])
    if constraint_file:
        inputs.append(constraint_file)
        copies.extend([constraint_file.path, package_constraint])

    manifest_files = [
        (rtl_filelist, "manifest/rtl.f"),
        (design_env, "manifest/design.env"),
        (package_txt, "manifest/README.txt"),
    ]
    for f, dest in manifest_files:
        inputs.append(f)
        copies.extend([f.path, dest])

    out = ctx.outputs.out
    args = ctx.actions.args()
    args.add(out.path)
    args.add_all(copies)

    ctx.actions.run_shell(
        inputs = inputs,
        outputs = [out],
        arguments = [args],
        command = """
set -euo pipefail
out="$1"
shift
tmp="${out}.staging"
rm -rf "$tmp"
mkdir -p "$tmp"
while [ "$#" -gt 0 ]; do
    src="$1"
    dest="$2"
    shift 2
    mkdir -p "$tmp/$(dirname "$dest")"
    cp "$src" "$tmp/$dest"
done
tar -C "$tmp" -czf "$out" .
rm -rf "$tmp"
""",
        mnemonic = "FpgaPackage",
    )

    return [
        DefaultInfo(files = depset([
            out,
            rtl_filelist,
            design_env,
            package_txt,
        ])),
    ]

fpga_package = rule(
    implementation = _fpga_package_impl,
    attrs = {
        "rtl_deps": attr.label_list(mandatory = True, providers = [SvInfo]),
        "scripts": attr.label_list(
            mandatory = True,
            allow_files = [".sh", ".tcl"],
        ),
        "xdc": attr.label(allow_single_file = [".xdc"]),
        "sdc": attr.label(allow_single_file = [".sdc"]),
        "vendor": attr.string(default = "xilinx"),
        "top_module": attr.string(mandatory = True),
        "part": attr.string(mandatory = True),
        "family": attr.string(default = ""),
        "clock_port": attr.string(default = "clk"),
        "clock_period": attr.string(default = "10.000"),
        "input_delay": attr.string(default = "0.000"),
        "output_delay": attr.string(default = "0.000"),
        "synthesis_mode": attr.string(default = "out_of_context"),
        "project_name": attr.string(default = ""),
        "virtual_pins": attr.string(default = "on"),
        "clean_project": attr.string(default = "on"),
        "device_db_check": attr.string(default = "on"),
        "out": attr.output(mandatory = True),
    },
)
