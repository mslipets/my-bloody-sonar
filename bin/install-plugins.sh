#!/usr/bin/env bash
#
# install-plugins.sh — resolve and install SonarQube plugins from a JSON config
# and/or ad-hoc CLI specs, with MD5 integrity verification.
#
# Inputs (in order of precedence):
#   1. $PLUGINS_FILE  — JSON config (see plugins.json.example)
#   2. positional args — "key@version" tokens (used by entrypoint.sh for
#      $SONAR_ENV_PLUGINS passthrough)
#
# Download URL resolution for each (key, version):
#   1. entry.downloadUrl from the JSON config, if set
#   2. <key>.<version>.downloadUrl from the public SonarQube update center
#   3. otherwise: fail loudly
#
set -euo pipefail

PLUGINS_FILE="${PLUGINS_FILE:-${SONARQUBE_HOME:-/opt/sonarqube}/plugins.json}"
PLUGINS_DIR="${PLUGINS_DIR:-${SONARQUBE_HOME:-/opt/sonarqube}/extensions/plugins}"
UPDATE_CENTER_URL="${UPDATE_CENTER_URL:-https://downloads.sonarsource.com/sonarqube/update/update-center.properties}"
UPDATE_CENTER_CACHE="${UPDATE_CENTER_CACHE:-/tmp/sonarqube-update-center.properties}"
# shellcheck disable=SC2086
CURL_OPTS=${CURL_OPTIONS:--sSfL}

log() { echo "[install-plugins] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }

for bin in jq curl md5sum unzip; do
    command -v "$bin" >/dev/null 2>&1 || die "required tool missing: $bin"
done

mkdir -p "$PLUGINS_DIR"

declare -A INSTALLED_FILENAMES=()

fetch_update_center() {
    [[ -s "$UPDATE_CENTER_CACHE" ]] && return 0
    log "fetching update center: $UPDATE_CENTER_URL"
    curl $CURL_OPTS -o "$UPDATE_CENTER_CACHE" "$UPDATE_CENTER_URL" \
        || die "failed to fetch update center properties"
}

# Look up <key>.<version>.downloadUrl in the update center properties file.
# Prints URL on stdout, empty string if not found.
resolve_url() {
    local key="$1" version="$2"
    fetch_update_center
    local esc="${version//./\\.}"
    local line
    line=$(grep -E "^${key}\.${esc}\.downloadUrl=" "$UPDATE_CENTER_CACHE" || true)
    [[ -z "$line" ]] && return 0
    # Strip key=, then undo Java properties `\:` colon escape.
    printf '%s\n' "${line#*=}" | sed 's|\\:|:|g'
}

verify_hash() {
    local file="$1" expected="$2"
    [[ "$(md5sum "$file" | awk '{print $1}')" == "$expected" ]]
}

# Read Plugin-Key from META-INF/MANIFEST.MF inside a JAR.
# Empty string if the file isn't a readable ZIP or lacks the header.
read_plugin_key() {
    unzip -p "$1" META-INF/MANIFEST.MF 2>/dev/null \
        | awk '/^[Pp]lugin-[Kk]ey:/ { sub(/^[^:]*:[[:space:]]*/, ""); gsub(/\r/, ""); print; exit }'
}

install_one() {
    local key="$1" version="$2" hash="${3:-}" override_url="${4:-}"
    local url filename target

    if [[ -n "$override_url" ]]; then
        url="$override_url"
    else
        url=$(resolve_url "$key" "$version")
    fi
    [[ -n "$url" ]] || die "cannot resolve URL for ${key}@${version} (not in update center, no downloadUrl override)"

    filename="${url##*/}"
    target="${PLUGINS_DIR}/${filename}"
    INSTALLED_FILENAMES["$key"]="$filename"

    if [[ -f "$target" ]]; then
        if [[ -n "$hash" ]] && verify_hash "$target" "$hash"; then
            log "skip   ${key}@${version} (present, hash ok)"
            return 0
        fi
        if [[ -z "$hash" ]]; then
            log "skip   ${key}@${version} (present, no hash to verify)"
            return 0
        fi
        log "stale  ${key}@${version} (hash mismatch) — re-downloading"
        rm -f "$target"
    fi

    log "fetch  ${key}@${version} <- $url"
    curl $CURL_OPTS -o "$target" "$url" \
        || die "download failed: ${key}@${version} from $url"

    if [[ -n "$hash" ]]; then
        verify_hash "$target" "$hash" \
            || { rm -f "$target"; die "hash mismatch for ${key}@${version} (expected $hash)"; }
        log "ok     ${key}@${version} (verified)"
    else
        log "ok     ${key}@${version} (unverified, no hash provided)"
    fi
}

# Remove older-version JARs of plugin keys that we just (re)installed.
# A JAR is pruned only if its Plugin-Key is in INSTALLED_FILENAMES and its
# filename differs from the target. Bundled / unmanaged plugins are left alone.
prune_superseded() {
    shopt -s nullglob
    local jar name key target
    for jar in "$PLUGINS_DIR"/*.jar; do
        name="${jar##*/}"
        key=$(read_plugin_key "$jar")
        [[ -z "$key" ]] && continue
        target="${INSTALLED_FILENAMES[$key]:-}"
        [[ -z "$target" ]] && continue
        if [[ "$name" != "$target" ]]; then
            log "prune  ${key} at ${name} (superseded by ${target})"
            rm -f "$jar"
        fi
    done
    shopt -u nullglob
}

if [[ -r "$PLUGINS_FILE" ]]; then
    log "reading $PLUGINS_FILE"
    while IFS=$'\t' read -r key version hash url; do
        [[ -z "${key:-}" ]] && continue
        install_one "$key" "$version" "$hash" "$url"
    done < <(jq -r '.plugins[] | [.key, .version, (.hash // ""), (.downloadUrl // "")] | @tsv' "$PLUGINS_FILE")
else
    log "no plugins file at $PLUGINS_FILE (skipping config-file install)"
fi

for spec in "$@"; do
    [[ -z "$spec" ]] && continue
    if [[ "$spec" != *"@"* ]]; then
        log "WARN: ignoring '$spec' (expected format: key@version)"
        continue
    fi
    install_one "${spec%@*}" "${spec#*@}" "" ""
done

prune_superseded

log "done"
