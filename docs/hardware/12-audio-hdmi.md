# 12 — Sistema de audio HDMI en Sovol Zero

## Alcance

Este capítulo documenta la habilitación de audio HDMI en la Sovol Zero (Allwinner H616) para utilizar la salida de audio integrada en la pantalla BTT HDMI5. El trabajo se realizó sobre Armbian y la pila ALSA del sistema.

## Punto de partida

En la configuración Device Tree inicial se observaron estos elementos:

- Dispositivos de audio AHUB1 (`ahub1_plat` y `ahub1_mach`) y componentes DAM.
- El códec H616 aparecía deshabilitado.
- La salida HDMI estaba habilitada.
- El kernel utilizado durante el diagnóstico era `6.18.44-current-sunxi64`.

En esa situación no aparecía un dispositivo PCM utilizable en `/proc/asound/pcm`.

## Habilitación de la ruta HDMI

Durante el trabajo se habilitaron AHUB1 y sus dependencias en el Device Tree. Como resultado, ALSA detectó una tarjeta de sonido denominada `HDMI`.

No se conserva en el registro recuperado el diff completo del Device Tree ni la ruta exacta del fichero modificado. Por tanto, este documento registra el resultado y los componentes implicados, pero no inventa un overlay ni un bloque DTS listo para copiar.

El códec interno H616 se mantuvo deshabilitado en el estado observado; la ruta utilizada fue la de audio HDMI.

## Permisos de usuario

Se añadió el usuario `sovol` al grupo `audio`:

```bash
sudo usermod -aG audio sovol
```

Para que el nuevo grupo se aplique a una sesión existente, puede ser necesario cerrar la sesión y volver a entrar o reiniciar los servicios correspondientes.

## Prueba de sonido confirmada

Se verificó la salida estéreo con ALSA mediante:

```bash
speaker-test -D hw:0,0 -c 2 -t sine -f 440
```

La prueba se ejecutó a 48 kHz y se confirmó sonido audible por la BTT HDMI5.

La enumeración ELD del monitor identificó un receptor HDMI Lontium Semi y capacidades LPCM estéreo con frecuencias de 32, 44,1 y 48 kHz, y formatos de 16, 20 y 24 bits.

En el sistema estaban disponibles `aplay` y `ffplay`; `mpg123` no estaba instalado en el momento de la comprobación.

## Estado y límites de la validación

**Confirmado:**
- ALSA detecta la tarjeta `HDMI`.
- El usuario `sovol` fue añadido al grupo `audio`.
- La prueba de tono de 440 Hz se escuchó por la pantalla BTT HDMI5.
- Se identificaron las capacidades LPCM anunciadas por el monitor.

**No documentado como cerrado:**
- El diff exacto y la ruta del Device Tree modificado.
- La selección persistente de la salida de audio tras cada arranque.
- La reproducción automática desde macros de Klipper.
- La reproducción completa de ficheros de audio y el comportamiento de latencia al iniciar.

No debe confundirse una prueba ALSA satisfactoria con una integración completa de audio en macros o con una configuración persistente ya verificada.

## Comprobaciones útiles

```bash
cat /proc/asound/cards
cat /proc/asound/pcm
aplay -l
```

Para repetir la prueba de tono:

```bash
speaker-test -D hw:0,0 -c 2 -t sine -f 440
```

El índice `hw:0,0` depende del orden de enumeración ALSA; si cambia, consulta primero `aplay -l`.

## Referencias

- [ALSA — utils](https://www.alsa-project.org/wiki/ALSA_Utils)
- [Armbian](https://www.armbian.com/)

---

**Navegación:** [← Índice de hardware](README.md) | [Siguiente: migración OEM a Mainline](../migration/README.md)
