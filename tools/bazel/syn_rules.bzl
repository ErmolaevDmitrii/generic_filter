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

def _pdk_dest(file):
    short_path = file.short_path
    short_path = _strip_prefix(short_path, "../")
    short_path = _strip_prefix(short_path, "syn/pdks/")
    return "pdk/" + short_path

def _script_dest(file):
    return "scripts/genus/" + file.basename

def _genus_package_impl(ctx):
    rtl_infos = [dep[SvInfo] for dep in ctx.attr.rtl_deps if SvInfo in dep]
    rtl_srcs = depset(transitive = [info.srcs for info in rtl_infos], order = "postorder").to_list()

    liberty_files = ctx.files.liberty
    lef_files = ctx.files.lefs
    verilog_models = ctx.files.verilog_models
    cdl_netlists = ctx.files.cdl_netlists
    gds_files = ctx.files.gds
    script_files = ctx.files.scripts

    rtl_lines = [_copy_dest(f, "rtl") for f in rtl_srcs]
    pdk_tcl_lines = [
        "set _manifest_dir [file dirname [file normalize [info script]]]",
        "set PACKAGE_ROOT [file dirname $_manifest_dir]",
        "set PDK_CORNER {%s}" % ctx.attr.corner,
        "",
    ]

    pdk_sets = [
        ("PDK_LIBERTY_FILES", liberty_files),
        ("PDK_LEF_FILES", lef_files),
        ("PDK_VERILOG_MODELS", verilog_models),
        ("PDK_CDL_NETLISTS", cdl_netlists),
        ("PDK_GDS_FILES", gds_files),
    ]

    for name, files in pdk_sets:
        pdk_tcl_lines.append("set %s [list \\" % name)
        for f in files:
            pdk_tcl_lines.append("    [file join $PACKAGE_ROOT %s] \\" % _pdk_dest(f))
        pdk_tcl_lines.append("]")
        pdk_tcl_lines.append("")

    package_lines = [
        "name: %s" % ctx.label.name,
        "top_module: %s" % ctx.attr.top_module,
        "corner: %s" % ctx.attr.corner,
        "rtl_files: %d" % len(rtl_srcs),
        "liberty_files: %d" % len(liberty_files),
        "lef_files: %d" % len(lef_files),
        "verilog_models: %d" % len(verilog_models),
        "cdl_netlists: %d" % len(cdl_netlists),
        "gds_files: %d" % len(gds_files),
        "",
        "Run after unpacking:",
        "  ./scripts/genus/run_genus.sh",
        "",
    ]
    design_tcl_lines = [
        "set GENUS_PACKAGE_TOP {%s}" % ctx.attr.top_module,
        "set GENUS_PACKAGE_CORNER {%s}" % ctx.attr.corner,
        "",
    ]

    rtl_filelist = ctx.actions.declare_file(ctx.label.name + "_rtl.f")
    pdk_tcl = ctx.actions.declare_file(ctx.label.name + "_pdk_tt.tcl")
    design_tcl = ctx.actions.declare_file(ctx.label.name + "_design.tcl")
    package_txt = ctx.actions.declare_file(ctx.label.name + "_README.txt")

    ctx.actions.write(rtl_filelist, "\n".join(rtl_lines) + "\n")
    ctx.actions.write(pdk_tcl, "\n".join(pdk_tcl_lines) + "\n")
    ctx.actions.write(design_tcl, "\n".join(design_tcl_lines))
    ctx.actions.write(package_txt, "\n".join(package_lines))

    copies = []
    inputs = []
    for f in rtl_srcs:
        inputs.append(f)
        copies.extend([f.path, _copy_dest(f, "rtl")])
    for f in liberty_files + lef_files + verilog_models + cdl_netlists + gds_files:
        inputs.append(f)
        copies.extend([f.path, _pdk_dest(f)])
    for f in script_files:
        inputs.append(f)
        copies.extend([f.path, _script_dest(f)])
    manifest_files = [
        (rtl_filelist, "manifest/rtl.f"),
        (pdk_tcl, "manifest/pdk.tcl"),
        (design_tcl, "manifest/design.tcl"),
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
        mnemonic = "GenusPackage",
    )

    return [
        DefaultInfo(files = depset([
            out,
            rtl_filelist,
            pdk_tcl,
            design_tcl,
            package_txt,
        ])),
    ]

genus_package = rule(
    implementation = _genus_package_impl,
    attrs = {
        "rtl_deps": attr.label_list(mandatory = True, providers = [SvInfo]),
        "liberty": attr.label_list(allow_files = [".lib"]),
        "lefs": attr.label_list(allow_files = [".lef"]),
        "verilog_models": attr.label_list(allow_files = [".v"]),
        "cdl_netlists": attr.label_list(allow_files = [".cdl"]),
        "gds": attr.label_list(allow_files = [".gds"]),
        "scripts": attr.label_list(allow_files = [".sh", ".tcl"]),
        "top_module": attr.string(mandatory = True),
        "corner": attr.string(default = "tt"),
        "out": attr.output(mandatory = True),
    },
)
