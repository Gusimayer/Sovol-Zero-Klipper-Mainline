# Actualización Klipper Mainline → Mainline — Sovol Zero

Este procedimiento actualiza una instalación **ya funcional de Klipper Mainline** en la Sovol Zero. No es una guía de migración desde el firmware OEM.

La actualización se divide en dos fases:

1. **Mainsail / Update Manager:** actualiza Klipper en el HOST y los componentes seleccionados (Moonraker, Mainsail, Crowsnest, etc.).
2. **`update_mcus.sh`:** compila y programa el MCU seleccionado. Para una actualización completa se actualizan ambos; también permite actualizar HOST o TOOLHEAD por separado.

> **Estado de validación: PROBADO Y FUNCIONANDO.** El procedimiento automático completo (actualización de software desde Mainsail y actualización de ambos MCU con la opción `3` del script) se ejecutó satisfactoriamente en esta Sovol Zero el 24-11-2026, pasando de `v0.13.0-827-g29d4ec2d` a `v0.14.0-0-gc9559fa0`. Se programó primero el F103 por CAN y después el H743 mediante Katapult USB. El script verificó en el registro del arranque actual que ambos MCU cargaron la misma versión; también se recuperaron USB-CAN y `can0` y Klipper volvió a estar operativo.
>
> **Esta es una prueba real completada, no un procedimiento pendiente de validar.** La evidencia corresponde a la unidad y configuración descritas aquí; no garantiza compatibilidad con otras revisiones de placa, UUID, offsets o configuraciones. Las opciones individuales `1` (HOST) y `2` (TOOLHEAD) existen en el menú, pero no formaron parte de la prueba completa documentada.

## 1. Hardware y configuración validados

- Impresora: Sovol Zero.
- Host: Allwinner H616, Armbian Trixie, arquitectura ARM64.
- MCU principal: placa física STM32H750, compilada como `stm32h743xx` a 400 MHz.
- MCU de cabezal: STM32F103 (`stm32f103xe`).
- El MCU principal también funciona como puente USB-CAN (`gs_usb`).
- Interfaz CAN: `can0`, 1 Mbps.
- Katapult disponible en ambos MCU.
- Klipper instalado en `~/klipper`.
- Configuración de impresora en `~/printer_data/config/printer.cfg`.
- Ruta de firmware y herramienta Katapult: `~/klipper/lib/katapult/flashtool.py`.

### Perfiles de compilación

El script espera estos archivos dentro de `~/klipper`:

- `klipper-f103-update.config` — `stm32f103xe`, aplicación en `0x8002000`.
- `klipper-h743-update.config` — `stm32h743xx`, aplicación en `0x8020000`.

El script comprueba sus SHA256 antes de continuar. **Estos dos archivos de perfil no están incluidos en el repositorio**: deben existir previamente en `~/klipper` y corresponder exactamente a los perfiles validados. El repositorio publica el script, no los perfiles binarios/de configuración locales. Si no conservas esos dos archivos, detente: no generes perfiles improvisados ni desactives las comprobaciones SHA256. No sustituyas estos perfiles por otros sin revisar MCU, reloj, interfaz y dirección de aplicación.

## 2. Antes de actualizar

1. Asegúrate de que la impresora funciona correctamente y Mainsail muestra `READY`.
2. Haz una copia de seguridad de la configuración de la impresora y de los archivos necesarios para recuperarla.
3. Mantén alimentación estable durante todo el proceso. No desconectes alimentación ni USB durante el flasheo.
4. Comprueba que tienes acceso SSH y que conoces la contraseña de `sudo`.
5. Comprueba que el script, los dos perfiles de compilación y Katapult están instalados en las rutas esperadas. El script descargado por sí solo no basta: los perfiles locales son un requisito obligatorio.

**Importante sobre UUID:** el script incluido contiene los UUID de la unidad usada para validar este procedimiento. Antes de usarlo en otra Sovol Zero, cambia `EXPECTED_HOST_UUID` y `EXPECTED_TOOLHEAD_UUID` por los UUID de esa impresora, obtenidos de las secciones `[mcu]` y `[mcu extruder_mcu]` de su `printer.cfg`. No reutilices los UUID de otra máquina.

### 2.1. Descargar y colocar el actualizador de MCU

Antes de comenzar la actualización, es necesario descargar el script `update_mcus.sh` desde el repositorio de GitHub y colocarlo en el directorio de Klipper de la impresora.

**Ubicación obligatoria del archivo:**

```text
/home/sovol/klipper/update_mcus.sh
```

#### Paso 1. Conectarse por SSH

Abre una sesión SSH con la Sovol Zero utilizando el usuario habitual.

#### Paso 2. Descargar el script

Ejecuta el siguiente comando:

```bash
wget -O ~/klipper/update_mcus.sh https://raw.githubusercontent.com/Gusimayer/Sovol-Zero-Klipper-Mainline/main/scripts/update_mcus.sh
```

El archivo se descargará directamente desde el repositorio y quedará guardado en el directorio `~/klipper`.

#### Paso 3. Comprobar que se ha descargado

Ejecuta:

```bash
ls -lh ~/klipper/update_mcus.sh
```

Debe aparecer el archivo `update_mcus.sh` con su tamaño correspondiente.

#### Paso 4. Comprobar la sintaxis del script

Ejecuta:

```bash
bash -n ~/klipper/update_mcus.sh
```

Si el comando no devuelve ningún mensaje, la comprobación de sintaxis ha terminado correctamente.

#### Paso 5. Comprobar los perfiles de compilación

El actualizador necesita los dos perfiles de configuración en el mismo directorio. **No se descargan con el comando anterior ni se publican en este repositorio**; deben proceder de la configuración validada que se conserva para esta máquina:

```text
~/klipper/klipper-f103-update.config
~/klipper/klipper-h743-update.config
```

El propio script verifica sus huellas SHA256 antes de continuar. No sustituyas estos archivos por perfiles diferentes sin revisar sus parámetros.

> **Importante sobre los UUID:** el script contiene inicialmente los UUID de la Sovol Zero utilizada para validar el procedimiento. Si se utiliza en otra impresora, hay que modificar `EXPECTED_HOST_UUID` y `EXPECTED_TOOLHEAD_UUID` dentro del script, sustituyéndolos por los UUID reales de esa unidad. Se obtienen de las secciones `[mcu]` y `[mcu extruder_mcu]` del archivo `printer.cfg`. No reutilices los UUID de otra impresora.

Si no tienes ambos perfiles, no continúes con el actualizador hasta recuperarlos de una copia fiable. Una vez completadas estas comprobaciones, el actualizador estará preparado para ejecutarse cuando corresponda, siguiendo el apartado 4 de esta guía.

## 3. Actualizar HOST y componentes desde Mainsail

1. Abre Mainsail.
2. Entra en **Update Manager**.
3. Pulsa **UPDATE ALL** (o actualiza los componentes que correspondan, incluido Klipper).
4. Espera a que finalicen las actualizaciones.
5. Si Mainsail solicita reiniciar Klipper o el equipo, sigue la indicación y espera a que vuelva a estar disponible.

La conexión SSH puede mantenerse si solo se reinicia el servicio Klipper. Si se reinicia el sistema completo, la sesión SSH se cerrará; espera a que la impresora arranque y vuelve a conectarte.

En este punto es normal que el HOST tenga la nueva versión y los MCU sigan temporalmente con la versión anterior. No imprimas hasta actualizar los MCU y verificar el estado `READY`.

## 4. Ejecutar el actualizador de MCU

Conéctate por SSH y ejecuta:

```bash
bash ~/klipper/update_mcus.sh
```

El script solicita la contraseña `sudo` y muestra un menú:

- `1` — Actualizar HOST H743.
- `2` — Actualizar TOOLHEAD F103.
- `3` — Actualizar ambos MCU (opción habitual para una actualización de versión completa).
- `4` — Consultar versiones y estado.
- `5` — Salir.
- `6` — Recuperar HOST H743 desde Katapult USB usando el binario guardado.

Para repetir el procedimiento completo que ya hemos probado satisfactoriamente, selecciona `3`. Las opciones `1` y `2` permiten solicitar la actualización individual de HOST o TOOLHEAD; son rutas separadas y no forman parte de la validación completa registrada el 24-11-2026.

Para actualizar ambos MCU:

1. Selecciona `3`.
2. Revisa los UUID, el estado de CAN y el estado del servicio Klipper.
3. Cuando solicite confirmación, escribe exactamente `ACTUALIZAR`.
4. El script compila ambos binarios y los guarda en `~/mcu-update-work/` antes de detener Klipper.
5. El script detiene Klipper y programa primero el TOOLHEAD F103 por CAN.
6. Después solicita Katapult al HOST H743 a través de CAN, espera a que aparezca como USB Katapult y comprueba el tipo de MCU y la dirección de aplicación.
7. Cuando solicite confirmación para el HOST, escribe exactamente `PROGRAMAR-HOST`.
8. No desconectes la alimentación ni el USB. Espera a que termine la programación, vuelva a aparecer el puente USB-CAN y `can0` esté operativo.
9. El script arranca Klipper y comprueba en los registros del arranque actual que ambos MCU han cargado la misma versión.

Si una comprobación falla, no repitas el flasheo a ciegas. Lee el mensaje, conserva la sesión y los binarios de `~/mcu-update-work/`, y diagnostica el estado del MCU antes de actuar.

## 5. Verificación final

En la ruta completa probada (opción `3`), la actualización solo se considera terminada cuando se cumplen todas estas condiciones:

- El script informa que ambos MCU han cargado la misma versión.
- Mainsail muestra `READY`.
- En **System Loads** aparecen las versiones esperadas para `mcu` y `extruder_mcu`.
- CAN está operativo a 1 Mbps.

Las opciones individuales `1` y `2` tienen una verificación específica del MCU seleccionado, pero no deben confundirse con el ciclo completo que se ha probado. La comprobación de arranque utiliza nuevas líneas de `klippy.log`, no únicamente registros antiguos.

## 6. Alcance y limitaciones

- Este script actualiza firmware Klipper de MCU ya preparados con Katapult. **No instala ni actualiza Katapult**.
- No utiliza ST-Link ni Deployer.
- No actualiza Armbian ni sustituye el sistema operativo.
- No sustituye el procedimiento de backup.
- La opción de recuperación del HOST requiere que el MCU sea visible como Katapult USB y que exista el binario H743 guardado con su SHA256.
- La opción `both` programa F103 primero y H743 después. El orden es intencionado porque el H743 también actúa como puente USB-CAN.
- Tras el flasheo, confirma manualmente `READY` en Mainsail antes de imprimir.

## 7. Resultado de la prueba del 24-11-2026

Actualización realizada en esta unidad:

| Elemento | Antes | Después |
|---|---|---|
| Klipper HOST | `v0.13.0-827-g29d4ec2d` | `v0.14.0-0-gc9559fa0` |
| MCU principal H743 | `v0.13.0-827-g29d4ec2d` | `v0.14.0-0-gc9559fa0` |
| MCU cabezal F103 | `v0.13.0-827-g29d4ec2d` | `v0.14.0-0-gc9559fa0` |

**Resultado: correcto y satisfactorio.** La compilación de ambos perfiles terminó correctamente; la programación y verificación de escritura se completaron; USB-CAN y CAN se recuperaron; Klipper arrancó y Mainsail volvió a mostrar la impresora operativa, con ambos MCU cargados en la misma versión. Este ciclo completo es el procedimiento automático validado del proyecto.

---

**Aviso:** la programación de firmware implica riesgo de dejar un MCU inaccesible. Comprueba siempre la revisión de hardware, el perfil, el offset y los UUID de tu propia impresora. Procede bajo tu responsabilidad.

---

**Navegación:** [← Índice de mantenimiento](README.md) | [Siguiente: backups y recuperación](../recovery/02-backups-y-recuperacion.md)
