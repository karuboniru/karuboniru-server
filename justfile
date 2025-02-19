# This is a justfile. See https://github.com/casey/just
# This is only used for local development. The builds made on the Fedora
# infrastructure are run via Pungi in a Koji runroot.

# Set a default for some recipes
default_variant := "fedora-iot"
default_arch := "default"
# Current default in Pungi
force_nocache := "true"

# Just doesn't have a native dict type, but quoted bash dictionary works fine
pretty_names := '(
    [fedora-iot]="IoT"
)'

# Default is to only validate the manifests
all: validate

# Basic validation to make sure the manifests are not completely broken
validate:
    ./ci/validate

# Output the processed manifest for a given variant (defaults to Silverblue)
manifest variant=default_variant:
    #!/bin/bash
    set -euo pipefail

    rpm-ostree compose tree --print-only --repo=repo {{variant}}.yaml

# Perform dependency resolution for a given variant (defaults to Silverblue)
compose-dry-run variant=default_variant:
    #!/bin/bash
    set -euxo pipefail

    mkdir -p repo cache logs
    if [[ ! -f "repo/config" ]]; then
        pushd repo > /dev/null || exit 1
        ostree init --repo . --mode=bare-user
        popd > /dev/null || exit 1
    fi

    rpm-ostree compose tree --unified-core --repo=repo --dry-run {{variant}}.yaml

# Alias/shortcut for compose-image command
compose variant=default_variant: (compose-image variant)

# Compose a variant using the legacy non container path (defaults to Silverblue)
compose-legacy variant=default_variant:
    #!/bin/bash
    set -euxo pipefail

    declare -A pretty_names={{pretty_names}}
    variant={{variant}}
    variant_pretty=${pretty_names[$variant]-}
    if [[ -z $variant_pretty ]]; then
        echo "Unknown variant"
        exit 1
    fi

    ./ci/validate > /dev/null || (echo "Failed manifest validation" && exit 1)

    mkdir -p repo cache logs
    if [[ ! -f "repo/config" ]]; then
        pushd repo > /dev/null || exit 1
        ostree init --repo . --mode=bare-user
        popd > /dev/null || exit 1
    fi
    # Set option to reduce fsync for transient builds
    ostree --repo=repo config set 'core.fsync' 'false'

    buildid="$(date '+%Y%m%d.0')"
    timestamp="$(date --iso-8601=sec)"
    echo "${buildid}" > .buildid

    version="$(rpm-ostree compose tree --print-only --repo=repo ${variant}.yaml | jq -r '."mutate-os-release"')"
    echo "Composing ${variant_pretty} ${version}.${buildid} ..."

    ARGS="--repo=repo --cachedir=cache"
    ARGS+=" --unified-core"
    if [[ {{force_nocache}} == "true" ]]; then
        ARGS+=" --force-nocache"
    fi
    CMD="rpm-ostree"
    if [[ ${EUID} -ne 0 ]]; then
        CMD="sudo rpm-ostree"
    fi

    ${CMD} compose tree ${ARGS} \
        --add-metadata-string="version=${variant_pretty} ${version}.${buildid}" \
        "${variant}-ostree.yaml" \
            |& tee "logs/${variant}_${version}_${buildid}.${timestamp}.log"

    if [[ ${EUID} -ne 0 ]]; then
        sudo chown --recursive "$(id --user --name):$(id --group --name)" repo cache
    fi

    ostree summary --repo=repo --update

# Compose an Ostree Native Container OCI image
compose-image variant=default_variant:
    #!/bin/bash
    set -euxo pipefail

    declare -A pretty_names={{pretty_names}}
    variant={{variant}}
    variant_pretty=${pretty_names[$variant]-}
    if [[ -z $variant_pretty ]]; then
        echo "Unknown variant"
        exit 1
    fi

    ./ci/validate > /dev/null || (echo "Failed manifest validation" && exit 1)

    mkdir -p repo cache
    if [[ ! -f "repo/config" ]]; then
        pushd repo > /dev/null || exit 1
        ostree init --repo . --mode=bare-user
        popd > /dev/null || exit 1
    fi
    # Set option to reduce fsync for transient builds
    ostree --repo=repo config set 'core.fsync' 'false'

    buildid="$(date '+%Y%m%d.0')"
    timestamp="$(date --iso-8601=sec)"
    echo "${buildid}" > .buildid

    version="$(rpm-ostree compose tree --print-only --repo=repo ${variant}.yaml | jq -r '."mutate-os-release"')"
    echo "Composing ${variant_pretty} ${version}.${buildid} ..."

    ARGS="--cachedir=cache --initialize"
    if [[ {{force_nocache}} == "true" ]]; then
        ARGS+=" --force-nocache"
    fi
    # To debug with gdb, use: gdb --args ...
    CMD="rpm-ostree"
    if [[ ${EUID} -ne 0 ]]; then
        CMD="sudo rpm-ostree"
    fi

    ${CMD} compose image ${ARGS} \
         --label="quay.expires-after=4w" \
        "${variant}.yaml" \
        "${variant}.ociarchive"

# Clean up everything
clean-all:
    just clean-repo
    just clean-cache

# Only clean the ostree repo
clean-repo:
    rm -rf ./repo

# Only clean the package and repo caches
clean-cache:
    rm -rf ./cache
