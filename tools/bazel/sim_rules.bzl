load("@hdl_rules//verilog:defs.bzl", "VerilogContext")


def _vcs_sim_package_impl(ctx):
    rtl_infos = [dep[VerilogContext] for dep in ctx.attr.rtl_deps]
    rtl_sources = depset(
        transitive = [info.srcs for info in rtl_infos],
        order = "postorder",
    ).to_list()

    rtl_entries = []
    for source in rtl_sources:
        short_path = source.short_path
        if not short_path.startswith(ctx.attr.rtl_strip_prefix):
            fail("RTL source %s is outside %s" % (short_path, ctx.attr.rtl_strip_prefix))
        destination = "rtl/%s" % short_path[len(ctx.attr.rtl_strip_prefix):]
        rtl_entries.extend([source.path, destination])

    tb_entries = []
    for source in ctx.files.testbench:
        destination = "tb/%s" % source.basename
        tb_entries.extend([source.path, destination])

    model = ctx.file.model
    model_destination = "model/%s" % model.basename
    script_entries = []
    for source in ctx.files.scripts:
        script_entries.extend([source.path, "scripts/%s" % source.basename])

    copy_entries = (
        rtl_entries +
        tb_entries +
        [model.path, model_destination] +
        script_entries
    )

    inputs = (
        rtl_sources +
        ctx.files.testbench +
        [model] +
        ctx.files.scripts
    )
    out = ctx.outputs.out
    args = ctx.actions.args()
    args.add(out.path)
    args.add(len(rtl_sources))
    args.add(len(ctx.files.testbench))
    args.add_all(copy_entries)

    ctx.actions.run_shell(
        inputs = inputs,
        outputs = [out],
        arguments = [args],
        command = """
set -euo pipefail
out="$1"
rtl_count="$2"
tb_count="$3"
shift 3
tmp="${out}.staging"
rm -rf "$tmp"
mkdir -p "$tmp/filelist"
: > "$tmp/filelist/rtl.f"
: > "$tmp/filelist/tb.f"
index=0
while [ "$#" -gt 0 ]; do
    src="$1"
    dest="$2"
    shift 2
    mkdir -p "$tmp/$(dirname "$dest")"
    cp "$src" "$tmp/$dest"
    if [ "$index" -lt "$rtl_count" ]; then
        printf '%s\n' "$dest" >> "$tmp/filelist/rtl.f"
    elif [ "$index" -lt "$((rtl_count + tb_count))" ]; then
        printf '%s\n' "$dest" >> "$tmp/filelist/tb.f"
    fi
    index="$((index + 1))"
done
tar -C "$tmp" -czf "$out" .
rm -rf "$tmp"
""",
        mnemonic = "VcsSimPackage",
    )

    return [DefaultInfo(files = depset([out]))]


vcs_sim_package = rule(
    implementation = _vcs_sim_package_impl,
    attrs = {
        "rtl_deps": attr.label_list(
            mandatory = True,
            providers = [VerilogContext],
        ),
        "testbench": attr.label_list(
            mandatory = True,
            allow_files = [".sv", ".v"],
        ),
        "model": attr.label(
            mandatory = True,
            allow_single_file = [".py"],
        ),
        "scripts": attr.label_list(allow_files = [".sh"]),
        "rtl_strip_prefix": attr.string(mandatory = True),
        "top_module": attr.string(mandatory = True),
        "sim_top": attr.string(mandatory = True),
        "out": attr.output(mandatory = True),
    },
)
