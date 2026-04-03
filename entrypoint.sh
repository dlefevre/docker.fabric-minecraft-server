#!/bin/bash
set -euo pipefail

SERVER_DIR=/opt/minecraft-server
PROPERTIES_DEFAULT="${SERVER_DIR}/server.properties.default"
PROPERTIES_FILE="${SERVER_DIR}/server.properties"
CONFIG_DIR="/data/config"

# ---------------------------------------------------------------------------
# 1. server.properties — start from baked-in defaults, apply MC_* overrides
# ---------------------------------------------------------------------------
cp "${PROPERTIES_DEFAULT}" "${PROPERTIES_FILE}"

while IFS='=' read -r key value; do
  # Only process MC_* vars, skip MC_JSON_* (handled below)
  case "${key}" in
    MC_JSON_*) continue ;;
    MC_*)      ;;
    *)         continue ;;
  esac

  # Transform env var name → property key
  #   1. Strip MC_ prefix
  #   2. Lowercase
  #   3. __ → .   (MC_QUERY__PORT → query.port)
  #   4. _  → -   (MC_MAX_PLAYERS → max-players)
  prop_key="${key#MC_}"
  prop_key="$(printf '%s' "${prop_key}" | tr '[:upper:]' '[:lower:]')"
  prop_key="$(printf '%s' "${prop_key}" | sed 's/__/\x00/g; s/_/-/g; s/\x00/./g')"

  if grep -q "^${prop_key}=" "${PROPERTIES_FILE}"; then
    sed -i "s|^${prop_key}=.*|${prop_key}=${value}|" "${PROPERTIES_FILE}"
  else
    printf '%s=%s\n' "${prop_key}" "${value}" >> "${PROPERTIES_FILE}"
  fi
done < <(env)

echo "[entrypoint] server.properties configured"

# ---------------------------------------------------------------------------
# 2. JSON config files — create if missing, MC_JSON_* idempotent injection
# ---------------------------------------------------------------------------
declare -A JSON_FILES=(
  [whitelist]="MC_JSON_WHITELIST"
  [ops]="MC_JSON_OPS"
  [banned-players]="MC_JSON_BANNED_PLAYERS"
  [banned-ips]="MC_JSON_BANNED_IPS"
)

for json_name in "${!JSON_FILES[@]}"; do
  file="${CONFIG_DIR}/${json_name}.json"
  env_key="${JSON_FILES[${json_name}]}"

  # Create the file only if it doesn't already exist; never overwrite an existing file
  if [ ! -f "${file}" ]; then
    printf '[]' > "${file}"
    echo "[entrypoint] ${json_name}.json initialized as empty array"
  else
    echo "[entrypoint] ${json_name}.json already exists, leaving as-is"
  fi

  # If the corresponding env var is set, add only entries not already present
  # Uniqueness is determined by .uuid for player files, .ip for banned-ips
  env_value="${!env_key:-}"
  if [ -n "${env_value}" ]; then
    jq -s '
      .[0] as $existing |
      .[1] as $new |
      $existing + ($new | map(
        . as $e |
        select($existing | map(
          (.uuid // .ip // tostring) == ($e.uuid // $e.ip // $e | tostring)
        ) | any | not)
      ))
    ' "${file}" <(printf '%s' "${env_value}") > "${file}.tmp"
    mv "${file}.tmp" "${file}"
    echo "[entrypoint] ${json_name}.json: missing entries injected from env var ${env_key}"
  fi
done

echo "[entrypoint] JSON config files configured"

# ---------------------------------------------------------------------------
# 3. Launch the Minecraft server (or execute a custom command if provided)
# ---------------------------------------------------------------------------
if [[ $# -gt 0 ]]; then
  exec "$@"
fi

JAVA_XMX="${JAVA_XMX:-4G}"
JAVA_XMS="${JAVA_XMS:-4G}"

echo "[entrypoint] Starting Minecraft server (Xmx=${JAVA_XMX}, Xms=${JAVA_XMS})"
cd "${SERVER_DIR}"
exec java -Xmx"${JAVA_XMX}" -Xms"${JAVA_XMS}" ${JAVA_EXTRA_ARGS:-} -jar server.jar nogui
