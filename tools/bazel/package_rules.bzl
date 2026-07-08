def _package_bundle_impl(ctx):
    package_entries = []
    archive_inputs = []

    for package, destination in ctx.attr.packages.items():
        archives = [
            f
            for f in package[DefaultInfo].files.to_list()
            if f.basename.endswith(".tar.gz")
        ]
        if len(archives) != 1:
            fail(
                "%s must provide exactly one .tar.gz archive, found %d" %
                (package.label, len(archives)),
            )

        archive = archives[0]
        archive_inputs.append(archive)
        package_entries.extend([archive.path, destination])

    out = ctx.outputs.out
    args = ctx.actions.args()
    args.add(out.path)
    args.add(ctx.attr.description)
    args.add_all(package_entries)

    ctx.actions.run_shell(
        inputs = archive_inputs,
        outputs = [out],
        arguments = [args],
        command = """
set -euo pipefail
out="$1"
description="$2"
shift 2
tmp="${out}.staging"
rm -rf "$tmp"
mkdir -p "$tmp"
{
    printf '%s\\n\\n' "$description"
    printf 'Included filter packages:\\n'
    while [ "$#" -gt 0 ]; do
        archive="$1"
        destination="$2"
        shift 2
        mkdir -p "$tmp/$destination"
        tar -xzf "$archive" -C "$tmp/$destination"
        printf '  %s/\\n' "$destination"
    done
} > "$tmp/README.txt"
tar -C "$tmp" -czf "$out" .
rm -rf "$tmp"
""",
        mnemonic = "PackageBundle",
    )

    return [DefaultInfo(files = depset([out]))]

package_bundle = rule(
    implementation = _package_bundle_impl,
    attrs = {
        "packages": attr.label_keyed_string_dict(mandatory = True),
        "description": attr.string(mandatory = True),
        "out": attr.output(mandatory = True),
    },
)
