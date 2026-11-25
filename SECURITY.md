# Política de seguridad

## Uso permitido

Este proyecto es un **laboratorio didáctico de administración remota local**. Su uso permitido es:

- equipos de tu propiedad;
- equipos de terceros con consentimiento explícito y verificable;
- redes privadas aisladas de Internet.

**No está permitido** usarlo para acceder a sistemas sin autorización, evadir controles de seguridad, ocultar actividad o cometer delitos.

## Qué deliberadamente NO incluye este proyecto

- Persistencia oculta (tareas programadas, servicios en segundo plano encubiertos, entradas de Registro).
- Evasión de antivirus o EDR.
- Keylogging, captura de pantalla, credenciales ni exfiltración de datos.
- Salto de autenticación ni escalada de privilegios.
- Reenvío de puertos a Internet.

## Cómo reportar un problema de seguridad

Abre un *Security Advisory* privado en GitHub o escribe a `grandrodri3@gmail.com`. No publiques detalles explícitos antes de que exista una corrección.

## Superficie de ataque conocida

- El servicio `sshd` escucha en el puerto 22 **solo en la subred detectada**; el firewall es la primera barrera.
- La autenticación es únicamente por clave pública Ed25519; las contraseñas están desactivadas.
- El usuario creado (`labremote`) es un usuario estándar, no administrador.
- La clave privada generada por `scripts/generate-key.sh` se guarda en `keys/` y está excluida por `.gitignore`.

Si encuentras una forma de eludir estas restricciones, repórtala: es exactamente lo que queremos corregir.
