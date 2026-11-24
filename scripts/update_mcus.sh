#!/usr/bin/env bash
# Sovol Zero - Klipper Mainline -> Mainline MCU updater.
# Uses the manually verified F103 CAN and H743 Katapult-USB procedures.
# Does NOT install Katapult, use ST-Link, or use Deployer.
# Full-cycle update successfully tested on this Sovol Zero on 2026-11-24 (Klipper v0.14.0).
set -Eeuo pipefail

KLIPPER_DIR="$HOME/klipper"
FLASHTOOL="$KLIPPER_DIR/lib/katapult/flashtool.py"
F103_CONFIG="$KLIPPER_DIR/klipper-f103-update.config"
H743_CONFIG="$KLIPPER_DIR/klipper-h743-update.config"
PRINTER_CFG="$HOME/printer_data/config/printer.cfg"
KLIPPY_LOG="$HOME/printer_data/logs/klippy.log"
SERVICE=klipper
CAN_IF=can0
EXPECTED_HOST_UUID=4179ccb3303d
EXPECTED_TOOLHEAD_UUID=e592fd710122
HOST_UUID=""
TOOLHEAD_UUID=""
USB_VENDOR=1d50
KATAPULT_PRODUCT=6177
KLIPPER_PRODUCT=606f
WORK_DIR="$HOME/mcu-update-work"
HOST_BIN="$WORK_DIR/klipper-host-h743.bin"
TOOLHEAD_BIN="$WORK_DIR/klipper-toolhead-f103.bin"
CONFIG_BACKUP=""
SERVICE_STOPPED_BY_SCRIPT=0
HOST_BOOTLOADER_REQUESTED=0
HOST_USB_CAN_CONFIRMED=0

# SHA256 values of the profiles used in the manually verified update.
EXPECTED_F103_CONFIG_SHA256=439597e622736e5162191b484ad256b42214faef4d6042d1e13c957848c99dd6
EXPECTED_H743_CONFIG_SHA256=ad6dd374a8e086311b1927923fc7fdfd452cda49f160ef386e9b6a345cc4a10a

info(){ echo "[INFO] $*"; }
warn(){ echo "[AVISO] $*" >&2; }
die(){ echo "[ERROR] $*" >&2; exit 1; }

get_uuid(){
  local section="$1"
  awk -v wanted="$section" '
    /^[[:space:]]*\[/ {
      s=$0
      sub(/^[[:space:]]*\[/, "", s)
      sub(/\].*$/, "", s)
      if (s == "mcu") current="mcu"
      else if (s ~ /^mcu[[:space:]]+/) { sub(/^mcu[[:space:]]+/, "", s); current=s }
      else current=""
      next
    }
    current == wanted {
      line=$0
      sub(/[;#].*$/, "", line)
      if (line ~ /^[[:space:]]*canbus_uuid[[:space:]]*:/) {
        sub(/^[[:space:]]*canbus_uuid[[:space:]]*:[[:space:]]*/, "", line)
        gsub(/[[:space:]]/, "", line)
        print line
        exit
      }
    }
  ' "$PRINTER_CFG"
}

restore_config(){
  if [[ -n "$CONFIG_BACKUP" && -f "$CONFIG_BACKUP" ]]; then
    cp -f "$CONFIG_BACKUP" "$KLIPPER_DIR/.config"
    rm -f "$CONFIG_BACKUP"
    CONFIG_BACKUP=""
    info "Configuración original .config restaurada."
  fi
}

restart_service(){
  if (( SERVICE_STOPPED_BY_SCRIPT )); then
    info "Arrancando Klipper..."
    if sudo systemctl start "$SERVICE"; then SERVICE_STOPPED_BY_SCRIPT=0
    else warn "No se pudo arrancar Klipper. Comprueba systemctl status klipper."; fi
  fi
}

cleanup(){
  local rc=$?
  restore_config || warn "No se pudo restaurar automáticamente .config; comprueba $KLIPPER_DIR/.config."

  # Never start Klipper while the HOST may still be in Katapult or mid-flash.
  if (( HOST_BOOTLOADER_REQUESTED && ! HOST_USB_CAN_CONFIRMED )); then
    warn "No se ha confirmado el regreso del HOST como USB-CAN."
    warn "Klipper se deja detenido deliberadamente; no se intentará arrancarlo automáticamente."
    warn "Comprueba la enumeración USB y el estado de Katapult antes de continuar."
  else
    restart_service || true
  fi

  if ((rc)); then
    warn "Finalizado con error (código $rc). Comprueba la impresora antes de reintentar."
  fi
  exit "$rc"
}
trap cleanup EXIT

check_can_ready(){
  local details
  details="$(ip -details link show "$CAN_IF" 2>/dev/null)" || return 1
  grep -q 'state UP' <<<"$details" && grep -q 'bitrate 1000000' <<<"$details"
}

wait_for_can_ready(){
  info "Esperando $CAN_IF UP a 1 Mbps..."
  local until=$((SECONDS+25))
  while (( SECONDS < until )); do
    if check_can_ready; then
      info "$CAN_IF está UP a 1 Mbps."
      return 0
    fi
    sleep 1
  done
  ip -details link show "$CAN_IF" 2>/dev/null || true
  return 1
}

preflight(){
  [[ -d "$KLIPPER_DIR" ]] || die "No existe $KLIPPER_DIR"
  for f in "$FLASHTOOL" "$F103_CONFIG" "$H743_CONFIG" "$PRINTER_CFG" "$KLIPPY_LOG" "$KLIPPER_DIR/.config"; do
    [[ -f "$f" ]] || die "Falta archivo: $f"
  done
  for c in python3 make sudo systemctl ip lsusb udevadm sha256sum awk grep sed wc stat nproc tail tee basename mktemp cp chmod rm sleep; do
    command -v "$c" >/dev/null || die "Falta comando: $c"
  done
  sudo -v || die "No se pudo validar sudo; no se realizará ninguna operación."

  HOST_UUID="$(get_uuid mcu)"
  TOOLHEAD_UUID="$(get_uuid extruder_mcu)"
  [[ "$HOST_UUID" =~ ^[[:xdigit:]]{12}$ ]] || die "No se pudo extraer un canbus_uuid válido de [mcu] en printer.cfg."
  [[ "$TOOLHEAD_UUID" =~ ^[[:xdigit:]]{12}$ ]] || die "No se pudo extraer un canbus_uuid válido de [mcu extruder_mcu] en printer.cfg."
  [[ "$HOST_UUID" == "$EXPECTED_HOST_UUID" ]] || die "El UUID HOST no corresponde a esta Sovol Zero: $HOST_UUID"
  [[ "$TOOLHEAD_UUID" == "$EXPECTED_TOOLHEAD_UUID" ]] || die "El UUID TOOLHEAD no corresponde a esta Sovol Zero: $TOOLHEAD_UUID"

  local f103_hash h743_hash
  f103_hash="$(sha256sum "$F103_CONFIG" | awk '{print $1}')"
  h743_hash="$(sha256sum "$H743_CONFIG" | awk '{print $1}')"
  [[ "$f103_hash" == "$EXPECTED_F103_CONFIG_SHA256" ]] || die "El perfil F103 no coincide con el perfil validado. SHA256: $f103_hash"
  [[ "$h743_hash" == "$EXPECTED_H743_CONFIG_SHA256" ]] || die "El perfil H743 no coincide con el perfil validado. SHA256: $h743_hash"

  grep -q '^CONFIG_MCU="stm32f103xe"$' "$F103_CONFIG" || die "Perfil F103 inesperado"
  grep -q '^CONFIG_FLASH_APPLICATION_ADDRESS=0x8002000$' "$F103_CONFIG" || die "Dirección F103 inesperada"
  grep -q '^CONFIG_MCU="stm32h743xx"$' "$H743_CONFIG" || die "Perfil H743 inesperado"
  grep -q '^CONFIG_FLASH_APPLICATION_ADDRESS=0x8020000$' "$H743_CONFIG" || die "Dirección H743 inesperada"
  mkdir -p "$WORK_DIR"
}

preflight_update(){
  preflight
  ip link show "$CAN_IF" >/dev/null 2>&1 || die "No existe $CAN_IF"
  check_can_ready || die "$CAN_IF no está UP a 1 Mbps"
  sudo systemctl is-active --quiet "$SERVICE" || die "Klipper no está activo"
}

show_status(){
  echo "UUID HOST H743: ${HOST_UUID:-$(get_uuid mcu)}"
  echo "UUID TOOLHEAD F103: ${TOOLHEAD_UUID:-$(get_uuid extruder_mcu)}"
  echo "Últimos registros de versión MCU (pueden incluir arranques anteriores):"
  grep -E "^Loaded MCU '(mcu|extruder_mcu)' .*\\(v[0-9]" "$KLIPPY_LOG" | tail -4 || true
  echo "CAN:"
  if ip link show "$CAN_IF" >/dev/null 2>&1; then
    ip -details link show "$CAN_IF" | sed -n '1,5p'
  else
    echo "$CAN_IF no está presente"
  fi
  echo "Klipper: $(sudo systemctl is-active "$SERVICE" 2>/dev/null || true)"
}

build_one(){
  local profile="$1" destination="$2" label="$3"
  info "Compilando $label..."
  CONFIG_BACKUP="$(mktemp "$WORK_DIR/config-original.XXXXXX")"
  cp -f "$KLIPPER_DIR/.config" "$CONFIG_BACKUP"
  cp -f "$profile" "$KLIPPER_DIR/.config"
  local jobs
  jobs="$(nproc)"
  if (( jobs > 4 )); then jobs=4; fi
  ( cd "$KLIPPER_DIR" && make clean && make -j"$jobs" )
  [[ -s "$KLIPPER_DIR/out/klipper.bin" ]] || die "No se generó klipper.bin para $label"
  cp -f "$KLIPPER_DIR/out/klipper.bin" "$destination"
  chmod 0644 "$destination"
  sha256sum "$destination" | tee "${destination}.sha256"
  restore_config
}

build_binaries(){
  local target="$1"
  case "$target" in
    toolhead)
      build_one "$F103_CONFIG" "$TOOLHEAD_BIN" "TOOLHEAD F103"
      ;;
    host)
      build_one "$H743_CONFIG" "$HOST_BIN" "HOST H743"
      ;;
    both)
      build_one "$F103_CONFIG" "$TOOLHEAD_BIN" "TOOLHEAD F103"
      build_one "$H743_CONFIG" "$HOST_BIN" "HOST H743"
      ;;
    *)
      die "Destino de compilación no válido: $target"
      ;;
  esac
  [[ -s "$TOOLHEAD_BIN" ]] && sha256sum "$TOOLHEAD_BIN" || true
  [[ -s "$HOST_BIN" ]] && sha256sum "$HOST_BIN" || true
  info "Binarios guardados en $WORK_DIR"
}

stop_klipper(){ sudo systemctl stop "$SERVICE"; SERVICE_STOPPED_BY_SCRIPT=1; }

query_can_nodes(){
  info "Consultando nodos Katapult en CAN..."
  python3 "$FLASHTOOL" -i "$CAN_IF" -q
}

flash_toolhead(){
  [[ -s "$TOOLHEAD_BIN" ]] || die "No existe el binario F103 preparado: $TOOLHEAD_BIN"
  check_can_ready || die "can0 dejó de estar operativo antes de programar TOOLHEAD."
  query_can_nodes
  info "Programando TOOLHEAD F103 por CAN (UUID $TOOLHEAD_UUID)..."
  python3 "$FLASHTOOL" -i "$CAN_IF" -u "$TOOLHEAD_UUID" -f "$TOOLHEAD_BIN"
  info "Programación TOOLHEAD terminada; comprobando de nuevo CAN..."
  check_can_ready || die "can0 no está operativo después de programar TOOLHEAD."
  query_can_nodes
}

find_usb_device(){
  local product="$1" until="$((SECONDS+45))" dev props
  while (( SECONDS < until )); do
    for dev in /dev/ttyACM* /dev/ttyUSB*; do
      [[ -e "$dev" ]] || continue
      props="$(udevadm info --query=property --name="$dev" 2>/dev/null || true)"
      if grep -q "^ID_VENDOR_ID=$USB_VENDOR$" <<<"$props" && grep -q "^ID_MODEL_ID=$product$" <<<"$props"; then
        echo "$dev"
        return 0
      fi
    done
    sleep 1
  done
  return 1
}

wait_for_klipper_usbcan(){
  info "Esperando que el HOST vuelva a enumerar como USB-CAN (${USB_VENDOR}:${KLIPPER_PRODUCT})..."
  local until=$((SECONDS+45))
  while (( SECONDS < until )); do
    if lsusb | grep -qi "${USB_VENDOR}:${KLIPPER_PRODUCT}"; then
      info "USB-CAN del HOST detectado."
      wait_for_can_ready || return 1
      return 0
    fi
    sleep 1
  done
  return 1
}

flash_host(){
  [[ -s "$HOST_BIN" ]] || die "No existe el binario H743 preparado: $HOST_BIN"
  info "Solicitando Katapult al HOST por CAN (UUID $HOST_UUID)..."
  HOST_BOOTLOADER_REQUESTED=1
  python3 "$FLASHTOOL" -i "$CAN_IF" -u "$HOST_UUID" -r

  info "Esperando USB Katapult VID:PID ${USB_VENDOR}:${KATAPULT_PRODUCT}..."
  local dev status
  dev="$(find_usb_device "$KATAPULT_PRODUCT")" || die "No se detectó el puerto USB Katapult; no se flasheará a ciegas."
  info "Puerto detectado: $dev"
  status="$(python3 "$FLASHTOOL" -d "$dev" -s 2>&1)" || { printf '%s\n' "$status"; die "No se pudo consultar Katapult"; }
  printf '%s\n' "$status"
  grep -qi '0x8020000' <<<"$status" || die "Katapult no informa la dirección de aplicación 0x8020000; cancelado."

  echo
  warn "Se va a programar el HOST H743. No desconectes la alimentación."
  read -r -p "Escribe PROGRAMAR-HOST para continuar: " answer
  [[ "$answer" == PROGRAMAR-HOST ]] || die "Programación HOST cancelada. El HOST puede seguir en Katapult."
  python3 "$FLASHTOOL" -d "$dev" -f "$HOST_BIN"
  info "El comando de programación del HOST ha terminado correctamente."
}

fresh_mcu_lines(){
  local start_line="$1" start_inode="$2" current_inode
  current_inode="$(stat -c %i "$KLIPPY_LOG")"
  if [[ "$current_inode" != "$start_inode" ]]; then
    grep -E "^Loaded MCU '(mcu|extruder_mcu)' .*\\(v[0-9]" "$KLIPPY_LOG" || true
  else
    tail -n "+$((start_line+1))" "$KLIPPY_LOG" | grep -E "^Loaded MCU '(mcu|extruder_mcu)' .*\\(v[0-9]" || true
  fi
}

start_klipper_and_verify_mcus(){
  local log_start_line log_start_inode host_line toolhead_line host_version toolhead_version until
  log_start_line="$(wc -l < "$KLIPPY_LOG")"
  log_start_inode="$(stat -c %i "$KLIPPY_LOG")"

  if (( SERVICE_STOPPED_BY_SCRIPT )); then
    restart_service
  else
    sudo systemctl start "$SERVICE"
  fi
  sudo systemctl is-active --quiet "$SERVICE" || die "El servicio Klipper no está activo tras el flasheo."

  info "Esperando registros nuevos de ambos MCUs en klippy.log..."
  until=$((SECONDS+75))
  while (( SECONDS < until )); do
    local fresh
    fresh="$(fresh_mcu_lines "$log_start_line" "$log_start_inode")"
    host_line="$(grep -E "^Loaded MCU 'mcu' " <<<"$fresh" | tail -1 || true)"
    toolhead_line="$(grep -E "^Loaded MCU 'extruder_mcu' " <<<"$fresh" | tail -1 || true)"
    if [[ -n "$host_line" && -n "$toolhead_line" ]]; then break; fi
    sleep 1
  done

  [[ -n "${host_line:-}" ]] || die "No se encontró una carga nueva del MCU HOST en klippy.log."
  [[ -n "${toolhead_line:-}" ]] || die "No se encontró una carga nueva del MCU TOOLHEAD en klippy.log."
  host_version="$(sed -n 's/.*(\(v[^ ]*\).*/\1/p' <<<"$host_line")"
  toolhead_version="$(sed -n 's/.*(\(v[^ ]*\).*/\1/p' <<<"$toolhead_line")"
  [[ -n "$host_version" && -n "$toolhead_version" ]] || die "No se pudieron extraer las versiones de ambos MCUs."
  [[ "$host_version" == "$toolhead_version" ]] || die "Las versiones no coinciden: HOST $host_version / TOOLHEAD $toolhead_version."
  sudo systemctl is-active --quiet "$SERVICE" || die "Klipper dejó de estar activo durante la verificación."

  echo "Verificación de carga MCU en el arranque actual:"
  printf '%s\n' "$host_line" "$toolhead_line"
  info "Ambos MCUs han cargado la misma versión: $host_version."
  warn "Confirma también en Mainsail que Klipper muestra READY antes de imprimir."
}

verify_after_update(){
  if [[ "$1" == "host" || "$1" == "both" ]]; then
    if ! wait_for_klipper_usbcan; then
      die "No se confirmó el regreso del HOST como USB-CAN con can0 operativo. Klipper permanecerá detenido."
    fi
    HOST_USB_CAN_CONFIRMED=1
  else
    check_can_ready || die "can0 no está operativo tras actualizar TOOLHEAD. Klipper permanecerá detenido."
  fi
  start_klipper_and_verify_mcus
}

recover_host(){
  HOST_BOOTLOADER_REQUESTED=0
  HOST_USB_CAN_CONFIRMED=0
  preflight
  [[ -s "$HOST_BIN" ]] || die "No existe un binario H743 recuperable en $HOST_BIN. No se compilará durante la recuperación."
  [[ -s "${HOST_BIN}.sha256" ]] || die "Falta el SHA256 guardado junto al binario HOST."
  ( cd "$WORK_DIR" && sha256sum -c "$(basename "${HOST_BIN}.sha256")" ) || die "El binario HOST no coincide con su SHA256 guardado."

  echo "Recuperación HOST H743 desde Katapult USB"
  echo "Binario guardado: $HOST_BIN"
  echo "SHA256: $(sha256sum "$HOST_BIN" | awk '{print $1}')"
  warn "Comprueba que este binario corresponde al firmware Mainline H743 esperado."

  local dev status
  dev="$(find_usb_device "$KATAPULT_PRODUCT")" || die "No se detecta USB Katapult (${USB_VENDOR}:${KATAPULT_PRODUCT}). No se intentará flashear."
  info "Dispositivo Katapult detectado: $dev"
  status="$(python3 "$FLASHTOOL" -d "$dev" -s 2>&1)" || { printf '%s\n' "$status"; die "No se pudo consultar Katapult."; }
  printf '%s\n' "$status"
  grep -qi '0x8020000' <<<"$status" || die "La dirección de aplicación no coincide con 0x8020000. Recuperación cancelada."

  echo
  warn "Se volverá a programar el HOST H743 con el binario guardado."
  warn "No desconectes alimentación ni USB durante la operación."
  read -r -p "Si has comprobado el binario y su SHA256, escribe RECUPERAR-HOST: " answer
  [[ "$answer" == RECUPERAR-HOST ]] || { info "Recuperación cancelada; no se ha flasheado nada."; return 0; }

  if sudo systemctl is-active --quiet "$SERVICE"; then
    info "Deteniendo Klipper antes de recuperar el HOST..."
    sudo systemctl stop "$SERVICE"
    SERVICE_STOPPED_BY_SCRIPT=1
  fi
  HOST_BOOTLOADER_REQUESTED=1
  python3 "$FLASHTOOL" -d "$dev" -f "$HOST_BIN"
  info "Programación de recuperación terminada."

  wait_for_klipper_usbcan || die "No se detectó USB-CAN/can0 operativo después de programar. Klipper permanecerá detenido."
  HOST_USB_CAN_CONFIRMED=1
  start_klipper_and_verify_mcus
  info "Recuperación verificada a nivel de conexión y versión de ambos MCUs."
}

run_update(){
  local target="$1"
  HOST_BOOTLOADER_REQUESTED=0
  HOST_USB_CAN_CONFIRMED=0
  preflight_update
  show_status
  echo "Destino: $target"
  echo "Se compilará el firmware seleccionado y se guardará antes de detener Klipper."
  read -r -p "Escribe ACTUALIZAR para continuar: " answer
  [[ "$answer" == ACTUALIZAR ]] || { info "Cancelado; no se han realizado cambios."; return 0; }

  build_binaries "$target"
  stop_klipper
  case "$target" in
    host) flash_host ;;
    toolhead) flash_toolhead ;;
    both) flash_toolhead; flash_host ;;
    *) die "Destino interno no válido: $target" ;;
  esac
  verify_after_update "$target"
}

main(){
  cd "$KLIPPER_DIR" || die "No se puede acceder a $KLIPPER_DIR"
  preflight
  while true; do
    cat <<'MENU'

=============================================
 Sovol Zero - Klipper Mainline MCU Updater
 Mainline -> Mainline
=============================================
 1) Actualizar HOST H743
 2) Actualizar TOOLHEAD F103
 3) Actualizar ambos MCU
 4) Consultar versiones y estado
 5) Salir
 6) Recuperar HOST H743 desde Katapult USB
MENU
    read -r -p "Selecciona una opción: " choice
    case "$choice" in
      1) run_update host ;;
      2) run_update toolhead ;;
      3) run_update both ;;
      4) show_status ;;
      5) info "Saliendo."; break ;;
      6) recover_host ;;
      *) warn "Opción no válida." ;;
    esac
  done
}
main "$@"
