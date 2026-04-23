#!/usr/bin/env bash
#
# Local validation harness for bin/install-plugins.sh.
#
# Uses tests/tmp as the install target (no SonarQube container required):
#   1. clean install        — installs 5 plugins at PROD baseline versions
#                             (tests/fixtures/plugins-prod-baseline.json)
#   2. idempotency          — second run with untouched dir skips every plugin
#   3. hash-mismatch        — a corrupted JAR is detected and re-downloaded
#   4. version upgrade      — switching config to plugins.json.example (the
#                             latest-targets file) replaces old JARs and
#                             prunes superseded ones
#   5. post-upgrade idem    — re-run against plugins.json.example is all skips
#
# Requires network egress to downloads.sonarsource.com and github.com.
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$PROJECT_ROOT/tests/tmp"
SCRIPT="$PROJECT_ROOT/bin/install-plugins.sh"

export PLUGINS_DIR="$TMP_DIR/plugins"
export UPDATE_CENTER_CACHE="$TMP_DIR/update-center.properties"

# Prod baseline — matches plugins.json.example
declare -A PROD_EXPECTED=(
    ["checkstyle-sonar-plugin-10.26.1.jar"]="0ac86b9da1070d57b55034cde235ac1f"
    ["sonar-dependency-check-plugin-3.0.1.jar"]="a28d843dccf2c1d53db8a682552b3c76"
    ["sonar-findbugs-plugin-4.5.2.jar"]="76c77eb649ca49b8a64b6acab3d2faa7"
    ["sonar-pmd-plugin-4.1.0.jar"]="cf51268f941e3f4fac7a8fffdada5936"
    ["sonar-yaml-plugin-1.9.1.jar"]="4c4570e8374bcc74d4cf61e56d1540fd"
)

# Upgrade target — matches tests/fixtures/plugins-upgrade-target.json
declare -A UPGRADE_EXPECTED=(
    ["checkstyle-sonar-plugin-10.26.1.jar"]="0ac86b9da1070d57b55034cde235ac1f"
    ["sonar-dependency-check-plugin-6.0.0.jar"]="b07467cd5050923a252771867828274e"
    ["sonar-findbugs-plugin-v4.6.0.jar"]="a2d327cb698bc26dfd53952410929939"
    ["sonar-pmd-plugin-4.2.1.jar"]="776f54494b5e640c71d064035145396f"
    ["sonar-yaml-plugin-1.9.1.jar"]="4c4570e8374bcc74d4cf61e56d1540fd"
)

# JARs expected to be pruned after the upgrade (prod-only filenames)
PRUNE_EXPECTED=(
    sonar-dependency-check-plugin-3.0.1.jar
    sonar-findbugs-plugin-4.5.2.jar
    sonar-pmd-plugin-4.1.0.jar
)

pass=0
fail=0

step() { printf '\n=== %s ===\n' "$*"; }
ok()   { printf '  \033[32mOK\033[0m   %s\n' "$*"; pass=$((pass+1)); }
err()  { printf '  \033[31mFAIL\033[0m %s\n' "$*"; fail=$((fail+1)); }

verify_set() {
    local -n expected="$1"
    for filename in "${!expected[@]}"; do
        local target="$PLUGINS_DIR/$filename"
        if [[ ! -f "$target" ]]; then
            err "missing: $filename"
            continue
        fi
        local actual
        actual=$(md5sum "$target" | awk '{print $1}')
        if [[ "$actual" == "${expected[$filename]}" ]]; then
            ok "$filename hash=$actual"
        else
            err "$filename expected=${expected[$filename]} actual=$actual"
        fi
    done
}

step "1. Clean install (prod baseline)"
rm -rf "$TMP_DIR"
mkdir -p "$PLUGINS_DIR"
PLUGINS_FILE="$PROJECT_ROOT/tests/fixtures/plugins-prod-baseline.json" "$SCRIPT"
verify_set PROD_EXPECTED

step "2. Idempotency (re-run without changes)"
out=$(PLUGINS_FILE="$PROJECT_ROOT/tests/fixtures/plugins-prod-baseline.json" "$SCRIPT" 2>&1)
echo "$out"
if grep -Eq '^\[install-plugins\] fetch  ' <<<"$out"; then
    err "unexpected plugin-fetch lines on idempotent rerun"
else
    ok "no re-downloads performed"
fi
skip_count=$(grep -Ec '^\[install-plugins\] skip' <<<"$out" || true)
if [[ "$skip_count" -eq 5 ]]; then
    ok "all 5 plugins reported as skipped"
else
    err "expected 5 skip lines, got $skip_count"
fi
if grep -Eq '^\[install-plugins\] prune' <<<"$out"; then
    err "unexpected prune on idempotent rerun"
else
    ok "no prunes performed"
fi

step "3. Hash-mismatch recovery (corrupt yaml JAR)"
echo "corrupted" > "$PLUGINS_DIR/sonar-yaml-plugin-1.9.1.jar"
out=$(PLUGINS_FILE="$PROJECT_ROOT/tests/fixtures/plugins-prod-baseline.json" "$SCRIPT" 2>&1)
echo "$out"
if grep -Eq '^\[install-plugins\] stale.*yaml' <<<"$out"; then
    ok "stale yaml JAR detected"
else
    err "expected 'stale' log line for yaml"
fi
verify_set PROD_EXPECTED

step "4. Version upgrade (swap config, expect new JARs + prune old)"
out=$(PLUGINS_FILE="$PROJECT_ROOT/plugins.json.example" "$SCRIPT" 2>&1)
echo "$out"
verify_set UPGRADE_EXPECTED
# Assert stale JARs were pruned
for filename in "${PRUNE_EXPECTED[@]}"; do
    if [[ -f "$PLUGINS_DIR/$filename" ]]; then
        err "stale $filename still present"
    else
        ok "pruned $filename"
    fi
done
# Assert prune log lines for each changed key
for key in dependencycheck findbugs pmd; do
    if grep -Eq "^\[install-plugins\] prune  ${key}" <<<"$out"; then
        ok "prune log for $key present"
    else
        err "expected prune log line for $key"
    fi
done
# Assert unchanged plugins (checkstyle, yaml) were NOT pruned
for key in checkstyle yaml; do
    if grep -Eq "^\[install-plugins\] prune  ${key}" <<<"$out"; then
        err "unexpected prune for unchanged key $key"
    else
        ok "no prune for unchanged $key"
    fi
done

step "5. Idempotency after upgrade (re-run should be all skips, no prunes)"
out=$(PLUGINS_FILE="$PROJECT_ROOT/plugins.json.example" "$SCRIPT" 2>&1)
echo "$out"
if grep -Eq '^\[install-plugins\] fetch  ' <<<"$out"; then
    err "unexpected plugin-fetch after upgrade idempotent rerun"
else
    ok "no re-downloads after upgrade"
fi
if grep -Eq '^\[install-plugins\] prune' <<<"$out"; then
    err "unexpected prune after upgrade idempotent rerun"
else
    ok "no prunes after upgrade"
fi

step "Summary"
printf 'passed: %d, failed: %d\n' "$pass" "$fail"
exit $((fail > 0 ? 1 : 0))
