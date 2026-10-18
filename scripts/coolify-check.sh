#!/usr/bin/env bash
# scripts/coolify-check.sh: verifica que los compose*.yaml de la raíz cumplan
# el contrato Coolify (puntos 1 y 2: nada que salte a Traefik ni dé poder sobre
# el host; ningún nombre fijo a nivel raíz ni en redes ni en volúmenes). Para
# cada compose genera un .env ficticio y renderiza con `docker compose config`,
# luego enumera las violaciones como "archivo:servicio: motivo" y sale 1.
#
# Origen: plan "B - Hefesto listo para Coolify" (rama coolify). Sin -e: queremos
# seguir enumerando violaciones incluso cuando el primer check falla.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER="${DOCKER_BIN:-docker}"   # sobreescribible para tests (stub en PATH)
JQ="${JQ_BIN:-jq}"               # sobreescribible para tests (stub en PATH)

URL_DEFECTO="https://ejemplo.invalid"
SECRETO_DEFECTO="x1234567890abcdef"   # valor ficticio no secreto, contrato dice explícito
DB_DEFECTO="mvp_prueba"
SSL_DEFECTO="disable"

# Una sola composición cumple el contrato hoy (compose.yaml + compose.supabase.yaml).
COMPOSES=()
while IFS= read -r -d '' f; do
  COMPOSES+=("$f")
done < <(find "$RAIZ" -maxdepth 1 -type f -name 'compose*.yaml' -print0 | sort -z)

if [[ ${#COMPOSES[@]} -eq 0 ]]; then
  printf 'error: no se encontraron compose*.yaml en %s\n' "$RAIZ" >&2
  exit 2
fi

# Extrae los nombres de variable ${VAR}, ${VAR:-...} y ${VAR:?...} de un archivo.
extraer_vars() {
  local archivo="$1"
  grep -oE '\$\{[A-Za-z_][A-Za-z0-9_]*' "$archivo" | cut -c 3- | sort -u
}

# Escribe un .env con valores ficticios para todas las variables del compose.
generar_env_falso() {
  local compose="$1" salida="$2"
  {
    printf 'DB_NAME=%s\n' "$DB_DEFECTO"
    printf 'DB_SSLMODE=%s\n' "$SSL_DEFECTO"
    while IFS= read -r var; do
      [[ -z "$var" ]] && continue
      case "$var" in
        *URL*|*ORIGIN*)
          printf '%s=%s\n' "$var" "$URL_DEFECTO" ;;
        *)
          printf '%s=%s\n' "$var" "$SECRETO_DEFECTO" ;;
      esac
    done < <(extraer_vars "$compose")
  } > "$salida"
}

# Escanea el YAML fuente en busca de `name:` fijo. No usamos el render porque
# docker compose autoderiva el nombre del proyecto, la red "default" y los
# volúmenes nombrados, y eso no es una violación del contrato.
verificar_nombres_fijos() {
  local compose="$1" relativo="$2"
  local rc=0 nro=0 en_volumes=0 en_networks=0
  while IFS= read -r linea || [[ -n "$linea" ]]; do
    nro=$((nro + 1))
    case "$linea" in
      'name:'*)
        printf '%s:%d: nombre de proyecto fijo (Coolify lo gestiona)\n' \
          "$relativo" "$nro"
        rc=1 ;;
      'networks:'*) en_networks=1; en_volumes=0 ;;
      'volumes:'*)   en_volumes=1; en_networks=0 ;;
      'services:'*)  en_networks=0; en_volumes=0 ;;
    esac
    # Cualquier otra clave top-level sale de los bloques actuales.
    if [[ "$linea" =~ ^[a-z][a-zA-Z0-9_-]*: ]] \
       && [[ "$linea" != name:* ]] \
       && [[ "$linea" != networks:* ]] \
       && [[ "$linea" != volumes:* ]] \
       && [[ "$linea" != services:* ]]; then
      en_networks=0
      en_volumes=0
    fi
    if [[ "$en_networks" -eq 1 || "$en_volumes" -eq 1 ]] \
       && [[ "$linea" =~ ^[[:space:]]+name:[[:space:]]*[^[:space:]] ]]; then
      if [[ "$en_volumes" -eq 1 ]]; then
        printf '%s:%d: volumen con name fijo (Coolify lo gestiona)\n' \
          "$relativo" "$nro"
      else
        printf '%s:%d: red con name fijo (Coolify lo gestiona)\n' \
          "$relativo" "$nro"
      fi
      rc=1
    fi
  done < "$compose"
  return $rc
}

# Imprime violaciones como "archivo:servicio: motivo" y devuelve 1 si hay alguna.
validar_compose() {
  local compose="$1"
  local relativo="${compose#"$RAIZ"/}"
  local tmp_env dir_salida rc=0
  tmp_env="$(mktemp "${TMPDIR:-/tmp}/coolify.XXXXXX.env")"
  dir_salida="$(mktemp -d "${TMPDIR:-/tmp}/coolify.XXXXXX.d")"
  # shellcheck disable=SC2064  # expandimos en este punto: $tmp_env ya está fijado.
  trap "rm -rf '$tmp_env' '$dir_salida'" RETURN

  generar_env_falso "$compose" "$tmp_env"

  if ! "$DOCKER" compose --project-directory "$RAIZ" -f "$compose" \
       --env-file "$tmp_env" config --format json \
       > "$dir_salida/render.json" 2> "$dir_salida/render.err"; then
    printf '%s::-: docker compose config falló: %s\n' "$relativo" \
      "$(tr '\n' ' ' < "$dir_salida/render.err" | sed 's/  */ /g')"
    return 1
  fi

  # 4a) Nivel raíz: nombre, redes y volúmenes fijos (escaneando el YAML fuente).
  if ! verificar_nombres_fijos "$compose" "$relativo"; then
    rc=1
  fi

  # 4b) Cada servicio sin profiles: contrato punto 1.
  while IFS= read -r svc; do
    [[ -z "$svc" ]] && continue
    local base="archivo=${relativo} servicio=${svc}"
    local R="$dir_salida/render.json"

    if [[ "$("$JQ" -r --arg s "$svc" '.services[$s].ports // [] | length' "$R")" != "0" ]]; then
      printf '%s motivo=publica puertos en el host; Coolify enruta con Traefik\n' "$base"
      rc=1
    fi
    if [[ -n "$("$JQ" -r --arg s "$svc" '.services[$s].container_name // ""' "$R")" ]]; then
      printf '%s motivo=container_name fijo\n' "$base"
      rc=1
    fi
    if [[ "$("$JQ" -r --arg s "$svc" '.services[$s].privileged // false' "$R")" == "true" ]]; then
      printf '%s motivo=privileged=true da poder sobre el host\n' "$base"
      rc=1
    fi
    if [[ "$("$JQ" -r --arg s "$svc" '.services[$s].cap_add // [] | length' "$R")" != "0" ]]; then
      printf '%s motivo=cap_add expone capabilities del kernel\n' "$base"
      rc=1
    fi
    if [[ "$("$JQ" -r --arg s "$svc" '.services[$s].devices // [] | length' "$R")" != "0" ]]; then
      printf '%s motivo=devices expone dispositivos del host\n' "$base"
      rc=1
    fi
    if [[ "$("$JQ" -r --arg s "$svc" '.services[$s].network_mode // ""' "$R")" == "host" ]]; then
      printf '%s motivo=network_mode=host escapa de la red de Docker\n' "$base"
      rc=1
    fi
    if [[ "$("$JQ" -r --arg s "$svc" '.services[$s].pid // ""' "$R")" == "host" ]]; then
      printf '%s motivo=pid=host comparte namespace de procesos con el host\n' "$base"
      rc=1
    fi
    if [[ "$("$JQ" -r --arg s "$svc" '.services[$s].ipc // ""' "$R")" == "host" ]]; then
      printf '%s motivo=ipc=host comparte namespace IPC con el host\n' "$base"
      rc=1
    fi
    if "$JQ" -e --arg s "$svc" \
         '.services[$s].security_opt // [] | index("unconfined") != null' \
         "$R" >/dev/null 2>&1; then
      printf '%s motivo=security_opt incluye "unconfined"\n' "$base"
      rc=1
    fi

    # Bind mounts: docker.sock prohibido; binds fuera del repo prohibidos.
    while IFS= read -r source; do
      [[ -z "$source" ]] && continue
      if [[ "$source" == *"docker.sock"* ]]; then
        printf '%s motivo=bind a %s controla el Docker del host\n' "$base" "$source"
        rc=1
        continue
      fi
      case "$source" in
        /*)
          printf '%s motivo=bind absoluto fuera del repo: %s\n' "$base" "$source"
          rc=1 ;;
        *) ;;
      esac
    done < <("$JQ" -r --arg s "$svc" \
             '.services[$s].volumes // []
              | .[] | select(.type == "bind") | .source // ""' \
             "$R")
  done < <("$JQ" -r '.services // {} | to_entries[]
                       | select((.value.profiles // null) == null) | .key' \
                    "$dir_salida/render.json")

  return $rc
}

FALLA=0
REVISADOS=0
for compose in "${COMPOSES[@]}"; do
  # Bootstrap files: la primera línea es "# bootstrap:" y se exceptúan del
  # contrato (punto 7 del plan), porque son compose de desarrollo local.
  primera="$(head -n 1 "$compose" 2>/dev/null || true)"
  case "$primera" in
    '# bootstrap:'*|'#bootstrap:'*)
      printf 'saltar %s: bootstrap\n' "${compose#"$RAIZ"/}"
      continue
      ;;
  esac
  REVISADOS=$((REVISADOS + 1))
  if ! validar_compose "$compose"; then
    FALLA=1
  fi
done

if (( FALLA )); then
  exit 1
fi
printf 'OK: %d compose(s) revisados cumplen el contrato Coolify\n' "$REVISADOS"
