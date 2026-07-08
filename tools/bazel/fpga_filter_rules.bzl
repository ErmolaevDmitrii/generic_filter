load("//tools/bazel:sv_rules.bzl", "sv_jinja_inline_template", "sv_library")

def fpga_filter_rtl(
        top_template,
        top_config,
        multiplier_config,
        adder_config,
        multiplier_pkg,
        multiplier_deps = [],
        top_deps = []):
    fpga_multiplier_config = dict(multiplier_config, TARGET = "FPGA")
    fpga_adder_config = dict(adder_config, TARGET = "FPGA")
    multiplier_module = multiplier_config["MODULE_NAME"]
    adder_module = adder_config["MODULE_NAME"]
    top_module = top_config["MODULE_NAME"]

    sv_jinja_inline_template(
        name = "fpga_multiplier_wrapper",
        template = "//src/common/multiplier_layer:src/multiplier_wrapper.sv.j2",
        config = fpga_multiplier_config,
        deps = [
            multiplier_pkg,
            "//tools/jinja2:jinja2_utils",
        ],
        out = "fpga/%s_multiplier_wrapper.sv" % multiplier_module,
    )

    sv_jinja_inline_template(
        name = "fpga_multiplier_layer",
        template = "//src/common/multiplier_layer:src/multiplier_layer.sv.j2",
        config = fpga_multiplier_config,
        deps = [
            multiplier_pkg,
            ":fpga_multiplier_wrapper",
            "//tools/jinja2:jinja2_utils",
        ] + multiplier_deps,
        out = "fpga/%s_multiplier_layer.sv" % multiplier_module,
    )

    sv_jinja_inline_template(
        name = "fpga_adder_wrapper",
        template = "//src/common/adder_tree:src/adder_wrapper.sv.j2",
        config = fpga_adder_config,
        deps = ["//tools/jinja2:jinja2_utils"],
        out = "fpga/%s_adder_wrapper.sv" % adder_module,
    )

    sv_jinja_inline_template(
        name = "fpga_adder_tree",
        template = "//src/common/adder_tree:src/adder_tree.sv.j2",
        config = fpga_adder_config,
        deps = [
            ":fpga_adder_wrapper",
            "//tools/jinja2:jinja2_utils",
        ],
        out = "fpga/%s_adder_tree.sv" % adder_module,
    )

    sv_jinja_inline_template(
        name = "fpga_top",
        template = top_template,
        config = top_config,
        deps = [
            ":fpga_adder_tree",
            ":fpga_multiplier_layer",
            "//tools/jinja2:jinja2_utils",
        ] + top_deps,
        out = "fpga/%s.sv" % top_module,
    )

    sv_library(
        name = "fpga_rtl",
        deps = [":fpga_top"],
    )
