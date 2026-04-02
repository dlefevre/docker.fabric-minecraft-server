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
# 2. JSON config files — mounted overrides + MC_JSON_* env var injection
# ---------------------------------------------------------------------------
declare -A JSON_FILES=(
  [whitelist]="MC_JSON_WHITELIST"
  [ops]="MC_JSON_OPS"
  [banned-players]="MC_JSON_BANNED_PLAYERS"
  [banned-ips]="MC_JSON_BANNED_IPS"
)

for json_name in "${!JSON_FILES[@]}"; do
  target="${SERVER_DIR}/${json_name}.json"
  env_key="${JSON_FILES[${json_name}]}"
  override_file="${CONFIG_DIR}/${json_name}.json"

  # Start with empty array
  printf '[]' > "${target}"

  # If a mounted override file exists, use it as the base
  if [ -f "${override_file}" ]; then
    cp "${override_file}" "${target}"
    echo "[entrypoint] ${json_name}.json loaded from mounted file"
  fi

  # If the corresponding env var is set, merge its elements into the array
  env_value="${!env_key:-}"
  if [ -n "${env_value}" ]; then
    jq -s '.[0] + .[1]' "${target}" <(printf '%s' "${env_value}") > "${target}.tmp"
    mv "${target}.tmp" "${target}"
    echo "[entrypoint] ${json_name}.json merged from env var ${env_key}"
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
