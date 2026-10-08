#!/usr/bin/env nix-shell
#!nix-shell -I nixpkgs=./. --pure -i bash -p bash nix git cacert curl jq common-updater-scripts
set -euo pipefail

versionPrefix=${1:-preview}
file=${2:-pkgs/godot/$versionPrefix/default.nix}
attr=godotPackages_${versionPrefix/./_}

echo "Looking up Godot preview..." >&2
api=https://api.github.com/repos/godotengine/godot-builds/releases
release=$(curl -fsSL --retry 3 "${api}${3:+/tags/$3}" | jq -ec '
    [.] | flatten
    | map(select(.draft == false and .prerelease == true)
        | select(.tag_name | test("^4\\.[0-9]+(\\.[0-9]+)?-(dev|beta|rc)[0-9]+$"))
        | .tag_name as $tag
        | select(any(.assets[]; .name == ("Godot_v" + $tag + "_export_templates.tpz")))
        | select(any(.assets[]; .name == ("Godot_v" + $tag + "_mono_export_templates.tpz"))))
    | max_by(.published_at)
') || {
    echo "Release lookup failed or no preview has both export templates." >&2
    exit 1
}

version=$(jq -er .tag_name <<< "$release")
prev_version=$(nix eval --raw -f. "$attr".godot.version)

[[ $version != "$prev_version" ]] || {
    echo "Godot $version is already current." >&2;
    exit 0;
}

echo "Updating Godot $prev_version -> $version..." >&2
rev=$(jq -er '.body | capture("Built from commit \\[(?<rev>[0-9a-f]{40})\\]") | .rev' <<< "$release")
rev_args=()
[[ $(nix eval --raw -f. "$attr".godot.src.rev) == "$rev" ]] || rev_args=(--rev="$rev")
update-source-version "$attr".godot "$version" "${rev_args[@]}" --file="$file"

echo "Regenerating NuGet dependencies..." >&2
fetch_deps=$(nix build -f. "$attr".godot-mono.fetch-deps --print-out-paths --no-link)
"$fetch_deps" "$(dirname -- "$file")/deps.json" >&2

echo "Updating export template hashes..." >&2
update-source-version "$attr".godot.export-templates-bin --ignore-same-version --file="$file"
update-source-version "$attr".godot-mono.export-templates-bin --ignore-same-version --file="$file"

nix-instantiate -A "$attr".godot -A "$attr".godot-mono >/dev/null
echo "Updated Godot to $version; both packages evaluate successfully." >&2
