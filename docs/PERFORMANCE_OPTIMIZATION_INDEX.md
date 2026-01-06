# 📚 GitMan - Análisis de Performance y Optimización

**Fecha:** 2026-01-06  
**Autor:** Análisis de Sistema  
**Versión:** 1.0

---

## 📖 Índice de Documentación

Este documento unifica el análisis completo del sistema de lectura y carga de proyectos Git en GitMan, identificando problemas de performance y proponiendo soluciones optimizadas.

---

## 📄 Documentos Generados

### 1. **QUEUE_ANALYSIS.md** - Análisis del Proceso Actual
**Contenido:**
- ✅ Análisis detallado del flujo de escaneo actual
- ✅ Identificación de cuellos de botella
- ✅ Timeline completo con métricas
- ✅ Propuestas de optimización de paralelización

**Hallazgos clave:**
- 🔴 Comandos git ejecutados secuencialmente (10 por repo)
- 🔴 Batch size fijo en 5 (no aprovecha todos los cores)
- 🔴 Filesystem scan secuencial
- ✅ Ya usa TaskGroup para batching básico

**Optimizaciones propuestas:**
1. Paralelizar comandos git (5x más rápido)
2. Dynamic batch size basado en CPU cores (40% más rápido)
3. Paralelizar filesystem scan (3x más rápido)

---

### 2. **CACHE_ANALYSIS.md** - Sistema de Cache Inteligente
**Contenido:**
- ✅ Análisis del problema de re-escaneo en cada inicio
- ✅ Arquitectura de cache multinivel
- ✅ Estrategia de detección de cambios
- ✅ Implementación completa propuesta

**Solución propuesta:**
- **Cache persistente en disco** (JSON)
- **Smart refresh** solo de repos modificados
- **Auto-refresh** configurable en background
- **Change detection** vía timestamps de `.git/index` y `.git/HEAD`

**Código incluido:**
- `CacheManager.swift` - Manejo de cache
- `ChangeDetector.swift` - Detección de cambios
- Modificaciones a `ProjectScannerViewModel.swift`

---

### 3. **CACHE_FLOW_DIAGRAM.md** - Diagramas Visuales
**Contenido:**
- ✅ Diagrama de flujo ACTUAL (sin cache)
- ✅ Diagrama de flujo PROPUESTO (con cache)
- ✅ Proceso de auto-refresh
- ✅ Explicación de change detection
- ✅ Ejemplos de formato de cache JSON

**Visualizaciones:**
- Timeline comparativo lado a lado
- Escenarios de detección de cambios
- Formato del archivo de cache

---

### 4. **CACHE_SUMMARY.md** - Resumen Ejecutivo
**Contenido:**
- ✅ Problema principal identificado
- ✅ Solución en 3 puntos
- ✅ Tabla de resultados esperados
- ✅ Plan de implementación por fases

**Ideal para:** Vista rápida y toma de decisiones

---

## 🎯 Resumen de Hallazgos

### Problemas Principales

| # | Problema | Impacto | Severidad |
|---|----------|---------|-----------|
| 1 | **Escaneo completo en cada inicio** | 5-10s de espera | 🔴 CRÍTICO |
| 2 | **Comandos git secuenciales** | ~200 comandos por carga | 🔴 CRÍTICO |
| 3 | **No hay persistencia** | Re-carga todo desde cero | 🔴 CRÍTICO |
| 4 | **Batch size fijo** | No aprovecha CPU | 🟡 MEDIO |
| 5 | **Scan filesystem secuencial** | Lento con múltiples paths | 🟢 BAJO |

---

## 💡 Soluciones Propuestas

### Stack de Optimizaciones (Priorizado)

#### 🥇 **PRIORIDAD 1: Sistema de Cache**
**Archivos a crear:**
- `Services/CacheManager.swift`
- `Services/ChangeDetector.swift`

**Archivos a modificar:**
- `ViewModels/ProjectScannerViewModel.swift`
- `Models/SettingsStore.swift`

**Impacto esperado:**
- ⚡ Carga inicial: 5-10s → **0.1s** (99% mejora)
- 📉 Comandos git: 200 → **20-40** (80-90% reducción)
- 😊 UX: Datos instantáneos en cada inicio

**Esfuerzo:** ~4-6 horas  
**Complejidad:** Media  
**ROI:** 🚀🚀🚀🚀🚀 (Máximo)

---

#### 🥈 **PRIORIDAD 2: Paralelizar Git Commands**
**Archivos a modificar:**
- `Services/GitService.swift` (método `getStatus`)

**Cambio:**
```swift
// Antes: secuencial (~1s por repo)
let branch = try await getCurrentBranch(...)
let changes = try await hasUncommittedChanges(...)

// Después: paralelo (~200ms por repo)
async let branch = getCurrentBranch(...)
async let changes = hasUncommittedChanges(...)
let (b, c) = try await (branch, changes)
```

**Impacto esperado:**
- ⚡ Tiempo por repo: 1s → **200ms** (5x más rápido)
- ⚡ Tiempo total (20 repos): 8s → **2s** (75% mejora)

**Esfuerzo:** ~1-2 horas  
**Complejidad:** Baja  
**ROI:** 🚀🚀🚀🚀 (Muy Alto)

---

#### 🥉 **PRIORIDAD 3: Dynamic Batch Size**
**Archivos a modificar:**
- `ViewModels/ProjectScannerViewModel.swift`

**Cambio:**
```swift
// Antes: hardcoded
let batches = gitRepos.chunked(into: 5)

// Después: adaptativo
let batchSize = ProcessInfo.processInfo.activeProcessorCount
let batches = gitRepos.chunked(into: batchSize)
```

**Impacto esperado:**
- ⚡ En Macs modernos (8+ cores): **30-40% más rápido**

**Esfuerzo:** ~15 minutos  
**Complejidad:** Muy Baja  
**ROI:** 🚀🚀🚀 (Alto)

---

#### 🏅 **PRIORIDAD 4: Parallel Filesystem Scan**
**Archivos a modificar:**
- `Models/ConfigStore.swift` (método `scanMonitoredPaths`)

**Impacto esperado:**
- ⚡ Scan de 3 paths: 1.5s → **0.5s** (3x más rápido)
- ⚠️ Pero scan ya es rápido, no es el cuello de botella

**Esfuerzo:** ~30 minutos  
**Complejidad:** Baja  
**ROI:** 🚀🚀 (Medio - opcional)

---

## 📊 Resultados Acumulados Esperados

### Si implementamos TODAS las optimizaciones:

| Escenario | Tiempo Actual | Tiempo Optimizado | Mejora Total |
|-----------|---------------|-------------------|--------------|
| **Primera carga** (no cache) | 8-10s | 1.5-2s | **80-85%** ⚡ |
| **Cargas subsecuentes** (con cache) | 8-10s | **0.1s** | **99%** 🚀 |
| **Comandos git ejecutados** | ~200 | 20-40 | **80-90%** 📉 |

### Breakdown por optimización:

```
Estado Actual:                           8.0s  (baseline)
+ Parallel Git Commands (5x):            2.0s  (-75%)
+ Dynamic Batch Size (1.4x):             1.4s  (-83%)
+ Parallel Scan (3x):                    1.2s  (-85%)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CON CACHE (cargas subsecuentes):         0.1s  (-99%) 🎯
```

---

## 🚀 Plan de Implementación Recomendado

### Fase 1: Quick Wins (30 min)
```
✅ Implementar Dynamic Batch Size
   - 1 línea de código
   - 30-40% mejora
   - Sin riesgo
```

### Fase 2: Paralelización (2 horas)
```
✅ Paralelizar Git Commands
   - Modificar GitService.getStatus()
   - 5x más rápido por repo
   - Testing importante
```

### Fase 3: Cache System (6 horas)
```
✅ Crear CacheManager
✅ Crear ChangeDetector
✅ Modificar ProjectScannerViewModel
✅ Agregar Settings UI
   - 99% mejora en carga
   - Cambio arquitectónico
   - Requiere testing exhaustivo
```

### Fase 4: Refinamiento (opcional)
```
✅ Parallel Filesystem Scan
✅ Priority Queue
✅ FSEvents monitoring
```

---

## 🧪 Testing Recomendado

### Test Cases Críticos:

1. **Cache Persistence**
   - ✅ Guardar y cargar cache correctamente
   - ✅ Validar formato JSON
   - ✅ Manejar cache corrupto

2. **Change Detection**
   - ✅ Detectar commits nuevos
   - ✅ Detectar cambios en archivos
   - ✅ Detectar cambio de branch
   - ✅ No falsos positivos

3. **Parallel Execution**
   - ✅ Todos los comandos git completan
   - ✅ No race conditions
   - ✅ Manejo de errores por comando

4. **Edge Cases**
   - ✅ Repos vacíos (sin commits)
   - ✅ Repos sin remote
   - ✅ Paths que ya no existen
   - ✅ Permisos insuficientes

---

## 📝 Configuración Propuesta

### Settings Store
```swift
struct CacheSettings {
    var enabled: Bool = true
    var maxAge: TimeInterval = 3600  // 1 hora
}

struct RefreshSettings {
    var autoRefreshEnabled: Bool = true
    var interval: TimeInterval = 300  // 5 minutos
}

struct PerformanceSettings {
    var batchSizeMode: BatchSizeMode = .dynamic
    var maxConcurrentGitCommands: Int = 10
}
```

---

## 🎯 Decisión Requerida

### ¿Qué quieres hacer primero?

**Opción A: Todo a la vez (full stack)** 🚀
- Implementar las 4 optimizaciones
- Tiempo: ~8 horas
- Ganancia: 99% mejora inmediata

**Opción B: Por fases (iterativo)** 🎯
- Fase 1: Quick win (30 min)
- Fase 2: Paralelización (2h)
- Fase 3: Cache (6h)
- Permite testing incremental

**Opción C: Solo cache (máximo impacto)** ⚡
- Implementar solo el sistema de cache
- Tiempo: ~6 horas
- Ganancia: 99% en cargas subsecuentes

**Opción D: Solo quick wins** 🏃
- Dynamic batch + Parallel git commands
- Tiempo: ~2 horas
- Ganancia: ~80% sin cambiar arquitectura

---

## 📚 Referencias

- `QUEUE_ANALYSIS.md` - Análisis técnico detallado
- `CACHE_ANALYSIS.md` - Propuesta de cache completa
- `CACHE_FLOW_DIAGRAM.md` - Diagramas visuales
- `CACHE_SUMMARY.md` - Resumen ejecutivo

---

**¿Listo para implementar? ¿Qué opción prefieres?** 🚀
