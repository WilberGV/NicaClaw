# 📜 REGLAS DEL PROYECTO: NICACLAW HYPER-OPTIMIZED

Este documento define las leyes fundamentales para el desarrollo y evolución de NicaClaw. Estas reglas son de cumplimiento OBLIGATORIO para cualquier agente o desarrollador.

## 1. 🔌 Uso Obligatorio de MCP (NicaClaw-First)
- Todas las operaciones de sistema, lectura, escritura y refactorización **DEBEN** realizarse exclusivamente a través del servidor MCP de NicaClaw y su herramienta `file_manager`.
- No se deben usar herramientas externas si existe una capacidad equivalente en el ecosistema native/mcp de NicaClaw.

## 2. ⚖️ Restricción de Peso Extremo (< 5MB)
- El binario final (`nicaclaw.exe`) y el núcleo del proyecto no deben exceder los **5MB**.
- Se prohíbe el uso de librerías externas pesadas. 
- Priorizar el uso de la librería estándar de Go para mantener el footprint lo más pequeño posible.

## 3. 🧠 Optimización de RAM (DDR2 Focus)
- Diseñado para funcionar en dispositivos con un máximo de **1GB de RAM**.
- El uso de memoria en reposo no debe superar los 10MB.
- Implementar `sync.Pool` para buffers y forzar GC agresivo en perfiles de baja memoria.

## 4. ⚡ Velocidad y Latencia Cero
- El tiempo de respuesta (TTFT - Time To First Token) es la métrica de éxito.
- Evitar abstracciones innecesarias que añadan overhead al ciclo de ejecución.
- Usar concurrencia nativa de Go (`goroutines`) solo cuando sea estrictamente necesario para no saturar la CPU.

## 5. 🛠 Auto-Refactorización Segura
- Antes de cada cambio, se debe verificar la integridad del código.
- Los cambios deben ser atómicos y documentados en `LEARNINGS.md`.

## 6. 🚫 Cero Conversaciones Inútiles
- NicaClaw debe ser directo. Cero "relleno" conversacional o explicaciones redundantes.
- El agente debe actuar, no solo informar.
