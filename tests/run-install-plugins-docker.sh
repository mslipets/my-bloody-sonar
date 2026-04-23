#!/usr/bin/env bash
#
# Docker-level validation of the plugin-injection contract added in entrypoint.sh.
# Runs the sequence described in Tests A + B of the design doc:
#
#   A. baked-in default            — image ships plugins.json.example as
#                                    $SONARQUBE_HOME/plugins.json; with no env
#                                    override the reconciled dir matches it.
#   B. SONAR_ENV_PLUGINS_JSON      — env body overwrites the baked-in file on
#                                    boot; reconciled dir matches the env body
#                                    (uses tests/fixtures/plugins-prod-baseline.json).
#
# FROM_TAG build-arg is derived from the latest git tag, stripped of the "v"
# prefix and combined with SQ_RELEASE (default: enterprise), matching
# .github/workflows/main.yml and the deployed config.yaml tag convention.
#
# Requires: docker, git, jq, md5sum. Network egress to sonarqube base image
# registry, downloads.sonarsource.com and github.com.
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SQ_RELEASE="${SQ_RELEASE:-enterprise}"
IMAGE_NAME="${IMAGE_NAME:-my-bloody-sonar}"

# Resolve FROM_TAG from the latest git tag, same rule the CI workflow uses.
LATEST_TAG=$(git -C "$PROJECT_ROOT" tag --sort=-v:refname | head -n 1)
[[ -n "$LATEST_TAG" ]] || { echo "no git tags found" >&2; exit 1; }
VERSION="${LATEST_TAG#v}"
FROM_TAG="${VERSION}-${SQ_RELEASE}"
IMAGE_TAG="${IMAGE_NAME}:test-${FROM_TAG}"

# Expected reconciled contents for each scenario (filename -> md5).
declare -A BAKED_EXPECTED=(
    ["checkstyle-sonar-plugin-10.26.1.jar"]="0ac86b9da1070d57b55034cde235ac1f"
    ["sonar-dependency-check-plugin-6.0.0.jar"]="b07467cd5050923a252771867828274e"
    ["sonar-findbugs-plugin-v4.6.0.jar"]="a2d327cb698bc26dfd53952410929939"
    ["sonar-pmd-plugin-4.2.1.jar"]="776f54494b5e640c71d064035145396f"
    ["sonar-yaml-plugin-1.9.1.jar"]="4c4570e8374bcc74d4cf61e56d1540fd"
)
declare -A ENV_EXPECTED=(
    ["checkstyle-sonar-plugin-10.26.1.jar"]="0ac86b9da1070d57b55034cde235ac1f"
    ["sonar-dependency-check-plugin-3.0.1.jar"]="a28d843dccf2c1d53db8a682552b3c76"
    ["sonar-findbugs-plugin-4.5.2.jar"]="76c77eb649ca49b8a64b6acab3d2faa7"
    ["sonar-pmd-plugin-4.1.0.jar"]="cf51268f941e3f4fac7a8fffdada5936"
    ["sonar-yaml-plugin-1.9.1.jar"]="4c4570e8374bcc74d4cf61e56d1540fd"
)
# Filenames that MUST NOT be present in the env-override scenario (they would
# indicate the baked-in default leaked through).
ENV_FORBIDDEN=(
    sonar-dependency-check-plugin-6.0.0.jar
    sonar-findbugs-plugin-v4.6.0.jar
    sonar-pmd-plugin-4.2.1.jar
)

pass=0
fail=0

step() { printf '\n=== %s ===\n' "$*"; }
ok()   { printf '  \033[32mOK\033[0m   %s\n' "$*"; pass=$((pass+1)); }
err()  { printf '  \033[31mFAIL\033[0m %s\n' "$*"; fail=$((fail+1)); }

# Run the reconciliation inside a fresh container, capture plugin dir listing
# as "md5  filename" lines on stdout. Stderr (install-plugins logs) is echoed
# so the user can see what happened.
reconcile_in_container() {
    local setup_cmd="$1"
    docker run --rm \
        -e SONARQUBE_HOME=/opt/sonarqube \
        --entrypoint bash "$IMAGE_TAG" -c "
            set -euo pipefail
            ${setup_cmd}
            install-plugins.sh >&2
            cd \$SONARQUBE_HOME/extensions/plugins
            md5sum *.jar 2>/dev/null || true
        "
}

verify_listing() {
    local -n expected="$1"
    local listing="$2"
    local forbidden_name="${3:-}"
    declare -A got=()
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local md5="${line%% *}"
        local name="${line##* }"
        got["$name"]="$md5"
    done <<<"$listing"

    for filename in "${!expected[@]}"; do
        if [[ -z "${got[$filename]:-}" ]]; then
            err "missing: $filename"
            continue
        fi
        if [[ "${got[$filename]}" == "${expected[$filename]}" ]]; then
            ok "$filename md5=${got[$filename]}"
        else
            err "$filename expected=${expected[$filename]} actual=${got[$filename]}"
        fi
    done

    if [[ -n "$forbidden_name" ]]; then
        local -n forbidden="$forbidden_name"
        for filename in "${forbidden[@]}"; do
            if [[ -n "${got[$filename]:-}" ]]; then
                err "leaked baked-in file: $filename"
            else
                ok "absent (as expected): $filename"
            fi
        done
    fi
}

step "Build image (FROM_TAG=${FROM_TAG}) -> ${IMAGE_TAG}"
docker build \
    --build-arg "FROM_TAG=${FROM_TAG}" \
    -t "$IMAGE_TAG" \
    "$PROJECT_ROOT"

step "A. Baked-in plugins.json (no SONAR_ENV_PLUGINS_JSON)"
listing=$(reconcile_in_container ":")
verify_listing BAKED_EXPECTED "$listing"

step "B. SONAR_ENV_PLUGINS_JSON override (baseline fixture)"
# The env body is piped in over stdin to keep the command short and avoid
# shell-quoting pain in the container-side script.
ENV_JSON=$(cat "$PROJECT_ROOT/tests/fixtures/plugins-prod-baseline.json")
listing=$(docker run --rm -i \
    -e SONARQUBE_HOME=/opt/sonarqube \
    -e SONAR_ENV_PLUGINS_JSON="$ENV_JSON" \
    --entrypoint bash "$IMAGE_TAG" -c '
        set -euo pipefail
        : "${PLUGINS_FILE:=$SONARQUBE_HOME/plugins.json}"
        printf "%s" "$SONAR_ENV_PLUGINS_JSON" > "$PLUGINS_FILE"
        install-plugins.sh >&2
        cd $SONARQUBE_HOME/extensions/plugins
        md5sum *.jar 2>/dev/null || true
    ')
verify_listing ENV_EXPECTED "$listing" ENV_FORBIDDEN

step "Summary"
printf 'passed: %d, failed: %d\n' "$pass" "$fail"
exit $((fail > 0 ? 1 : 0))
