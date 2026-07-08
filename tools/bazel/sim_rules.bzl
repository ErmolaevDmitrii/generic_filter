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

def _script_dest(file):
    return "scripts/vcs/" + file.basename

def _tb_dest(file):
    return "tb/" + file.basename

def _model_dest(file):
    return "model/" + file.basename

def _shell_value(value):
    if "'" in value:
        fail("Simulation package values must not contain single quotes: %s" % value)
    return "'" + value + "'"

def _vcs_sim_package_impl(ctx):
    rtl_infos = [dep[SvInfo] for dep in ctx.attr.rtl_deps if SvInfo in dep]
    rtl_srcs = depset(
        transitive = [info.srcs for info in rtl_infos],
        order = "postorder",
    ).to_list()
    tb_srcs = ctx.files.testbench
    script_files = ctx.files.scripts
    model_file = ctx.file.model

    rtl_lines = [_copy_dest(f, "rtl") for f in rtl_srcs]
    tb_lines = [_tb_dest(f) for f in tb_srcs]
    design_env_lines = [
        "SIM_PACKAGE_TOP=%s" % _shell_value(ctx.attr.top_module),
        "SIM_PACKAGE_TB=%s" % _shell_value(ctx.attr.sim_top),
        "SIM_PACKAGE_RTL_FILELIST='manifest/rtl.f'",
        "SIM_PACKAGE_TB_FILELIST='manifest/tb.f'",
        "SIM_PACKAGE_MODEL=%s" % _shell_value(_model_dest(model_file)),
        "SIM_PACKAGE_SAMPLE_COUNT=%s" % _shell_value(ctx.attr.sample_count),
        "SIM_PACKAGE_ENABLE_FSDB=%s" % _shell_value(ctx.attr.enable_fsdb),
        "",
    ]
    package_lines = [
        "name: %s" % ctx.label.name,
        "top_module: %s" % ctx.attr.top_module,
        "testbench: %s" % ctx.attr.sim_top,
        "rtl_files: %d" % len(rtl_srcs),
        "testbench_files: %d" % len(tb_srcs),
        "sample_count: %s" % ctx.attr.sample_count,
        "",
        "Run after unpacking on a VCS host:",
        "  ./scripts/vcs/run_vcs.sh",
        "",
        "Open waveforms after a run:",
        "  ./scripts/vcs/run_verdi.sh",
        "",
        "Override settings with VCS_BIN, VERDI_BIN, PYTHON_BIN, SAMPLE_COUNT,",
        "ENABLE_FSDB, VERDI_PLI_ROOT, VERDI_EXTRA_LD_LIBRARY_PATH, OUT_DIR,",
        "VCS_ARGS, SIMV_ARGS, or FSDB_FILE.",
        "",
    ]

    rtl_filelist = ctx.actions.declare_file(ctx.label.name + "_rtl.f")
    tb_filelist = ctx.actions.declare_file(ctx.label.name + "_tb.f")
    design_env = ctx.actions.declare_file(ctx.label.name + "_design.env")
    package_txt = ctx.actions.declare_file(ctx.label.name + "_README.txt")

    ctx.actions.write(rtl_filelist, "\n".join(rtl_lines) + "\n")
    ctx.actions.write(tb_filelist, "\n".join(tb_lines) + "\n")
    ctx.actions.write(design_env, "\n".join(design_env_lines))
    ctx.actions.write(package_txt, "\n".join(package_lines))

    copies = []
    inputs = []
    for f in rtl_srcs:
        inputs.append(f)
        copies.extend([f.path, _copy_dest(f, "rtl")])
    for f in tb_srcs:
        inputs.append(f)
        copies.extend([f.path, _tb_dest(f)])
    for f in script_files:
        inputs.append(f)
        copies.extend([f.path, _script_dest(f)])
    inputs.append(model_file)
    copies.extend([model_file.path, _model_dest(model_file)])

    manifest_files = [
        (rtl_filelist, "manifest/rtl.f"),
        (tb_filelist, "manifest/tb.f"),
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
        mnemonic = "VcsSimPackage",
    )

    return [
        DefaultInfo(files = depset([
            out,
            rtl_filelist,
            tb_filelist,
            design_env,
            package_txt,
        ])),
    ]

vcs_sim_package = rule(
    implementation = _vcs_sim_package_impl,
    attrs = {
        "rtl_deps": attr.label_list(mandatory = True, providers = [SvInfo]),
        "testbench": attr.label_list(
            mandatory = True,
            allow_files = [".sv", ".v", ".svh", ".vh"],
        ),
        "model": attr.label(mandatory = True, allow_single_file = [".py"]),
        "scripts": attr.label_list(
            mandatory = True,
            allow_files = [".sh"],
        ),
        "top_module": attr.string(mandatory = True),
        "sim_top": attr.string(mandatory = True),
        "sample_count": attr.string(default = "192"),
        "enable_fsdb": attr.string(default = "on"),
        "out": attr.output(mandatory = True),
    },
)
