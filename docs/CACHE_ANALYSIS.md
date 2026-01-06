# Análisis de Cache y Almacenamiento Local - GitMan

**Fecha:** 2026-01-06  
**Objetivo:** Optimizar el proceso de carga y lectura de proyectos Git mediante almacenamiento persistente

---

## 📊 ANÁLISIS ACTUAL

### 1. Proceso de Lectura de Proyectos (Estado Actual)

#### **Flujo de Escaneo**

```
App Launch
    ↓
ProjectScannerViewModel.scanAllProjects()
    ↓
ConfigStore.scanMonitoredPaths()
    ↓
[Para cada monitored path]
    ↓
    ├─ Escanear directorios (FileManager)
    ├─ Detectar .git folders
    ├─ Construir jerarquía (workspace/folders/repos)
    └─ Retornar lista de Projects
    ↓
[Para cada Git Repository encontrado]
    ↓
    GitService.getStatus(for project)
    ↓
    ├─ getCurrentBranch (git rev-parse)
    ├─ hasUncommittedChanges (git status)
    ├─ getUntrackedFiles (git ls-files)
    ├─ getModifiedFiles (git diff)
    ├─ getStagedFiles (git diff --cached)
    ├─ getLastCommit (git log -1)
    ├─ getBehindAheadCounts (git rev-list)
    ├─ getBranches (git branch)
    └─ getPendingPullRequestCount (gh pr list) [si aplica]
    ↓
Actualizar UI con GitStatus
```

#### **Problemas Identificados**

1. **❌ Escaneo Completo en Cada Inicio**
   - Cada vez que se abre la app, se escanea TODO desde cero
   - No hay persistencia del estado anterior de los proyectos
   - Se ejecutan ~8-10 comandos git POR CADA REPOSITORIO

2. **❌ Proceso Secuencial con Alta Latencia**
   - Aunque se procesan en batches (de 5), sigue siendo lento
   - Cada comando git tiene latencia de proceso (spawn, exec, I/O)
   - Para 20 repos = ~160-200 comandos git = varios segundos

3. **❌ Re-fetch Innecesario de Datos Estáticos**
   - Información como lista de branches, commits antiguos, etc. cambian poco
   - Se vuelven a consultar aunque no hayan cambiado

4. **❌ No hay Detección de Cambios**
   - No sabemos si algo cambió desde la última vez
   - No podemos optimizar "solo actualizar lo que cambió"

5. **⚠️ Carga Inicial Pobre en UX**
   - El usuario ve una lista vacía durante segundos
   - No hay feedback inmediato con datos anteriores

---

## 💡 PROPUESTA DE SOLUCIÓN

### Sistema de Cache Inteligente Multinivel

---

## 🗂️ ARQUITECTURA PROPUESTA

### **Nivel 1: Cache en Memoria (Runtime)**
- **Ubicación:** `ProjectScannerViewModel.projects`
- **Duración:** Mientras la app esté abierta
- **Propósito:** Estado actual de trabajo
- ✅ **Ya existe**

### **Nivel 2: Cache Persistente (Disk)**
- **Ubicación:** `~/Library/Application Support/GitMan/projects.cache`
- **Formato:** JSON (Codable)
- **Contenido:** 
  ```swift
  struct ProjectCache: Codable {
      var lastScanDate: Date
      var projects: [Project]  // Con GitStatus incluido
      var monitoredPaths: [String]
      var version: String = "1.0"
  }
  ```
- **Propósito:** Recuperación instantánea en el siguiente inicio

### **Nivel 3: Metadata Ligera (Quick Check)**
- **Método:** Verificar timestamps de `.git/index` y `.git/HEAD`
- **Propósito:** Detectar cambios sin ejecutar git commands
- **Beneficio:** Saber qué repos actualizar sin escanear todos

---

## 🔄 ESTRATEGIA DE ACTUALIZACIÓN

### **Al Iniciar la App**

```
1. Cargar cache de disco inmediatamente
   ↓ (< 100ms)
2. Mostrar datos cached en UI
   ↓
3. Background: Verificar cambios
   ↓
4. Actualizar solo lo que cambió
```

### **Detección de Cambios (Smart Refresh)**

```swift
// Pseudo-código
for project in cachedProjects {
    let gitIndexPath = "\(project.path)/.git/index"
    let headPath = "\(project.path)/.git/HEAD"
    
    let indexModified = modificationDate(gitIndexPath)
    let headModified = modificationDate(headPath)
    
    if indexModified > project.lastScanned || 
       headModified > project.lastScanned {
        // ✅ Actualizar este proyecto
        await refreshProjectStatus(project)
    } else {
        // ⏭️ Skip - sin cambios
    }
}
```

### **Triggers de Actualización Completa**

1. **Manual:** Usuario Pull-to-Refresh
2. **Auto:** Cada X minutos (configurable: 5, 15, 30 min)
3. **Cambio de Paths:** Si se agregan/quitan monitored paths
4. **FSEvents:** (Futuro) Observar cambios en filesystem

---

## 📝 IMPLEMENTACIÓN PROPUESTA

### **Archivo 1: `CacheManager.swift`**

```swift
import Foundation
import OSLog

/// Manages persistent caching of project data
actor CacheManager {
    private let logger = Logger(subsystem: "com.gitmonitor", category: "CacheManager")
    private let fileManager = FileManager.default
    
    // Cache file location
    private var cacheFileURL: URL {
        get throws {
            let appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let gitManDir = appSupport.appendingPathComponent("GitMan", isDirectory: true)
            
            // Create directory if needed
            if !fileManager.fileExists(atPath: gitManDir.path) {
                try fileManager.createDirectory(at: gitManDir, withIntermediateDirectories: true)
            }
            
            return gitManDir.appendingPathComponent("projects.cache")
        }
    }
    
    // MARK: - Save Cache
    
    func saveCache(_ cache: ProjectCache) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(cache)
        let url = try cacheFileURL
        
        try data.write(to: url, options: [.atomic])
        logger.info("Cache saved successfully: \(cache.projects.count) projects")
    }
    
    // MARK: - Load Cache
    
    func loadCache() async throws -> ProjectCache? {
        let url = try cacheFileURL
        
        guard fileManager.fileExists(atPath: url.path) else {
            logger.info("No cache file found")
            return nil
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let cache = try decoder.decode(ProjectCache.self, from: data)
        logger.info("Cache loaded: \(cache.projects.count) projects from \(cache.lastScanDate)")
        
        return cache
    }
    
    // MARK: - Cache Validation
    
    func isCacheValid(_ cache: ProjectCache, maxAge: TimeInterval = 3600) -> Bool {
        let age = Date().timeIntervalSince(cache.lastScanDate)
        return age < maxAge
    }
    
    // MARK: - Clear Cache
    
    func clearCache() async throws {
        let url = try cacheFileURL
        
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
            logger.info("Cache cleared")
        }
    }
}

// MARK: - Data Models

struct ProjectCache: Codable {
    var version: String = "1.0"
    var lastScanDate: Date
    var monitoredPaths: [String]
    var projects: [Project]
    
    init(monitoredPaths: [String], projects: [Project]) {
        self.lastScanDate = Date()
        self.monitoredPaths = monitoredPaths
        self.projects = projects
    }
}
```

### **Archivo 2: `ChangeDetector.swift`**

```swift
import Foundation

/// Detects changes in git repositories without running git commands
actor ChangeDetector {
    private let fileManager = FileManager.default
    
    /// Check if a git repository has changes since last scan
    func hasChanges(project: Project) -> Bool {
        let gitIndexPath = (project.path as NSString).appendingPathComponent(".git/index")
        let gitHeadPath = (project.path as NSString).appendingPathComponent(".git/HEAD")
        
        // Get modification dates
        guard let indexDate = modificationDate(at: gitIndexPath),
              let headDate = modificationDate(at: gitHeadPath) else {
            // If we can't check, assume it changed
            return true
        }
        
        // Compare with last scan date
        let lastCheck = project.lastScanned
        
        return indexDate > lastCheck || headDate > lastCheck
    }
    
    /// Get modification date of a file
    private func modificationDate(at path: String) -> Date? {
        guard fileManager.fileExists(atPath: path) else {
            return nil
        }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: path)
            return attributes[.modificationDate] as? Date
        } catch {
            return nil
        }
    }
    
    /// Batch check multiple projects
    func filterChangedProjects(_ projects: [Project]) -> [Project] {
        return projects.filter { hasChanges(project: $0) }
    }
}
```

### **Archivo 3: Modificaciones a `ProjectScannerViewModel.swift`**

```swift
// Agregar propiedades
private let cacheManager = CacheManager()
private let changeDetector = ChangeDetector()
private var autoRefreshTimer: Timer?
@Published var isLoadingFromCache = false

// Nuevo: Init con cache loading
init(configStore: ConfigStore, gitService: GitService) {
    self.configStore = configStore
    self.gitService = gitService
    
    // Cargar cache inmediatamente
    Task {
        await loadFromCache()
    }
}

// MARK: - Cache Management

/// Load projects from cache for instant display
func loadFromCache() async {
    isLoadingFromCache = true
    
    do {
        if let cache = try await cacheManager.loadCache() {
            // Verificar que los paths monitored no hayan cambiado
            if cache.monitoredPaths == configStore.monitoredPaths {
                await MainActor.run {
                    self.projects = cache.projects
                    logger.info("Loaded \(cache.projects.count) projects from cache")
                }
                
                // Opdonal: Trigger background refresh of changed items
                await refreshChangedProjects()
            } else {
                logger.info("Monitored paths changed, cache invalid")
                await scanAllProjects()
            }
        } else {
            // No cache, do full scan
            await scanAllProjects()
        }
    } catch {
        logger.error("Failed to load cache: \(error)")
        await scanAllProjects()
    }
    
    isLoadingFromCache = false
}

/// Refresh only projects that have changes
private func refreshChangedProjects() async {
    logger.debug("Checking for changed projects...")
    
    // Get all git repos (flatten hierarchy)
    let allGitRepos = getAllGitRepos(from: projects)
    
    // Detect which ones changed
    let changedRepos = await changeDetector.filterChangedProjects(allGitRepos)
    
    logger.info("Found \(changedRepos.count) changed repos out of \(allGitRepos.count)")
    
    // Update only those
    for repo in changedRepos {
        await refreshProjectStatus(repo)
    }
    
    // Save updated cache
    await saveCache()
}

/// Save current state to cache
func saveCache() async {
    let cache = ProjectCache(
        monitoredPaths: configStore.monitoredPaths,
        projects: projects
    )
    
    do {
        try await cacheManager.saveCache(cache)
    } catch {
        logger.error("Failed to save cache: \(error)")
    }
}

/// Modified: scanAllProjects - save cache after scan
func scanAllProjects() async {
    // ... código existente ...
    
    // Al final, guardar cache
    await saveCache()
}

/// Modified: refreshProjectStatus - save cache after refresh
func refreshProjectStatus(_ project: Project) async {
    // ... código existente ...
    
    // Al final, guardar cache
    await saveCache()
}

// MARK: - Auto Refresh

func startAutoRefresh(interval: TimeInterval = 300) { // 5 minutos
    autoRefreshTimer?.invalidate()
    
    autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
        Task { @MainActor in
            await self?.refreshChangedProjects()
        }
    }
}

func stopAutoRefresh() {
    autoRefreshTimer?.invalidate()
    autoRefreshTimer = nil
}
```

---

## ⚙️ CONFIGURACIÓN RECOMENDADA

### **Settings UI Updates**

Agregar a `SettingsStore.swift`:

```swift
@Published var cacheEnabled: Bool = true
@Published var cacheMaxAge: TimeInterval = 3600 // 1 hora
@Published var autoRefreshInterval: TimeInterval = 300 // 5 minutos
@Published var autoRefreshEnabled: Bool = true
```

### **Settings View**

```swift
Section("Cache") {
    Toggle("Enable Cache", isOn: $settings.cacheEnabled)
    
    Picker("Cache Validity", selection: $settings.cacheMaxAge) {
        Text("15 minutes").tag(TimeInterval(900))
        Text("1 hour").tag(TimeInterval(3600))
        Text("6 hours").tag(TimeInterval(21600))
        Text("1 day").tag(TimeInterval(86400))
    }
    
    Toggle("Auto Refresh", isOn: $settings.autoRefreshEnabled)
    
    if settings.autoRefreshEnabled {
        Picker("Refresh Interval", selection: $settings.autoRefreshInterval) {
            Text("2 minutes").tag(TimeInterval(120))
            Text("5 minutes").tag(TimeInterval(300))
            Text("15 minutes").tag(TimeInterval(900))
            Text("Never").tag(TimeInterval.infinity)
        }
    }
    
    Button("Clear Cache") {
        Task {
            try? await cacheManager.clearCache()
        }
    }
}
```

---

## 📊 BENEFICIOS ESPERADOS

### **Performance**

| Métrica | Antes | Después | Mejora |
|---------|-------|---------|--------|
| Tiempo de carga inicial | 5-10s | 0.1-0.5s | **95%** ⚡ |
| Comandos git ejecutados | ~200 | ~20-40 | **80%** 📉 |
| Uso de CPU | Alto | Bajo | **70%** 💚 |
| Experiencia usuario | ❌ Espera | ✅ Inmediato | 🎯 |

### **User Experience**

- ✅ **Instant Load:** Datos disponibles en < 100ms
- ✅ **Smart Updates:** Solo actualiza lo necesario
- ✅ **Background Refresh:** Mantiene datos frescos sin bloquear
- ✅ **Offline Ready:** Funciona sin problema si no hay cambios

---

## 🚀 PLAN DE IMPLEMENTACIÓN

### **Fase 1: Base (Core)**
1. ✅ Crear `CacheManager.swift`
2. ✅ Crear `ChangeDetector.swift`
3. ✅ Agregar `ProjectCache` model

### **Fase 2: Integración**
1. Modificar `ProjectScannerViewModel`
2. Implementar `loadFromCache()`
3. Implementar `saveCache()`
4. Implementar `refreshChangedProjects()`

### **Fase 3: UI/Settings**
1. Agregar opciones a `SettingsStore`
2. Crear Settings UI para cache
3. Agregar indicadores de "Loading from cache"

### **Fase 4: Refinamiento**
1. Manejo de errores robusto
2. Migración de cache versions
3. Testing y optimización
4. Logging y debugging

---

## 🎯 RESUMEN

**Problema:** La app escanea TODO desde cero en cada inicio, siendo muy lento.

**Solución:** Cache persistente + detección inteligente de cambios.

**Resultado:** 
- ⚡ Carga instantánea (< 100ms vs 5-10s)
- 🎯 Actualización inteligente (solo lo que cambió)
- 💚 Menor uso de recursos
- 😊 Mejor experiencia de usuario

---

**¿Procedemos con la implementación?** 🚀
