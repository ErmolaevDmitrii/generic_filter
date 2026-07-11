load("@hdl_rules//verilog:defs.bzl", "VerilogContext")

SvInfo = VerilogContext

def _merge_sv_info(ctx, direct_srcs = [], direct_incdirs = [], direct_defines = []):
    dep_infos = [dep[SvInfo] for dep in ctx.attr.deps if SvInfo in dep]
    return SvInfo(
        srcs = depset(
            direct = direct_srcs,
            transitive = [info.srcs for info in dep_infos],
            order = "postorder",
        ),
        incdirs = depset(
            direct = direct_incdirs,
            transitive = [info.incdirs for info in dep_infos],
            order = "postorder",
        ),
        defines = depset(
            direct = direct_defines,
            transitive = [info.defines for info in dep_infos],
            order = "postorder",
        ),
    )

def _sv_jinja_inline_template_impl(ctx):
    template = ctx.file.template
    out_file = ctx.actions.declare_file(ctx.attr.out if ctx.attr.out else ctx.label.name + ".sv")

    config_json_file = ctx.actions.declare_file(ctx.label.name + "_config.json")
    ctx.actions.write(
        output  = config_json_file,
        content = json.encode(ctx.attr.config),
    )

    args = ctx.actions.args()
    args.add("-t", template.path)
    args.add("-c", config_json_file.path)
    args.add("-o", out_file.path)

    inputs = [template, config_json_file] + ctx.files.deps

    ctx.actions.run(
        outputs    = [out_file],
        inputs     = inputs,
        executable = ctx.executable._renderer,
        arguments  = [args],
        mnemonic   = "JinjaInlineRender",
    )

    sv_info = _merge_sv_info(
        ctx,
        direct_srcs = [out_file],
        direct_incdirs = [out_file.dirname] + ctx.attr.incdirs,
        direct_defines = ctx.attr.defines,
    )

    return [
        DefaultInfo(files = depset([out_file])),
        sv_info,
    ]

sv_jinja_inline_template = rule(
    implementation = _sv_jinja_inline_template_impl,
    attrs = {
        "template":  attr.label(allow_single_file = [".j2", ".sv.j2"], mandatory = True),
        "config":    attr.string_dict(mandatory = True),
        "deps":      attr.label_list(allow_files = True),
        "out":       attr.string(),
        "incdirs":   attr.string_list(),
        "defines":   attr.string_list(),
        "_renderer": attr.label(
            default = Label("//tools/scripts:render_script"),
            executable = True,
            cfg = "exec"
        ),
    },
)

def _sv_library_impl(ctx):
    direct_srcs = ctx.files.srcs
    direct_incdirs = [src.dirname for src in direct_srcs] + ctx.attr.incdirs
    sv_info = _merge_sv_info(
        ctx,
        direct_srcs = direct_srcs,
        direct_incdirs = direct_incdirs,
        direct_defines = ctx.attr.defines,
    )

    return [
        DefaultInfo(files = sv_info.srcs),
        sv_info,
    ]

sv_library = rule(
    implementation = _sv_library_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".sv", ".v", ".svh", ".vh"]),
        "deps": attr.label_list(),
        "incdirs": attr.string_list(),
        "defines": attr.string_list(),
    },
)

def _sv_filelist_impl(ctx):
    sv_info = _merge_sv_info(ctx)
    lines = []

    for incdir in sv_info.incdirs.to_list():
        lines.append("+incdir+%s" % incdir)

    for define in sv_info.defines.to_list():
        lines.append("+define+%s" % define)

    for src in sv_info.srcs.to_list():
        lines.append(src.path)

    ctx.actions.write(
        output = ctx.outputs.out,
        content = "\n".join(lines) + "\n",
    )

    return [DefaultInfo(files = depset([ctx.outputs.out]))]

sv_filelist = rule(
    implementation = _sv_filelist_impl,
    attrs = {
        "deps": attr.label_list(mandatory = True),
        "out": attr.output(mandatory = True),
    },
)
