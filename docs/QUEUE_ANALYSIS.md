# Análisis del Queue y Proceso de Lectura Git

## 📋 ANÁLISIS DEL CÓDIGO ACTUAL

### 1. Proceso de Scanning (ConfigStore)

#### **scanMonitoredPaths()** - Sincrónico Secuencial

```swift
func scanMonitoredPaths() async -> [Project] {
    var discoveredProjects: [Project] = []

    // ❌ PROBLEMA: Itera secuencialmente
    for path in monitoredPaths {
        let projectsInPath = await scanPathForProjects(path)
        discoveredProjects.append(contentsOf: projectsInPath)
    }
    
    return discoveredProjects
}
```

**Características:**
- ✅ Secuencial: Espera a que termine un path antes de escanear el siguiente
- ❌ No hay paralelización
- ❌ Si tienes 3 monitored paths, se escanean uno tras otro

**Tiempo estimado:**
- 1 path con 20 repos: ~500ms
- 3 paths: ~1.5s (secuencial)

---

### 2. Proceso de Git Status (ProjectScannerViewModel)

#### **scanAllProjects()** - Batches de 5

```swift
func scanAllProjects() async {
    // 1. Discover projects
    let discoveredProjects = await configStore.scanMonitoredPaths()
    
    // 2. Update UI immediately
    self.projects = sortedProjects
    
    // 3. Fetch git details IN BATCHES
    let gitRepos = getAllGitRepos(from: sortedProjects)
    let batches = gitRepos.chunked(into: 5)  // ← BATCH SIZE: 5
    
    for batch in batches {
        await withTaskGroup(of: Void.self) { group in
            for project in batch {
                group.addTask {
                    await self.refreshProjectStatus(project)
                }
            }
        }
    }
}
```

**Características:**
- ✅ Usa `TaskGroup` para paralelizar dentro del batch
- ✅ Procesa 5 repos simultáneamente
- ⚠️ Espera a que termine el batch completo antes de iniciar el siguiente
- ❌ Batch size fijo (no configurable)

**Ejemplo con 20 repos:**
```
Batch 1: repos 1-5   → ~2 segundos (paralelo)
         ↓ (espera)
Batch 2: repos 6-10  → ~2 segundos (paralelo)
         ↓ (espera)
Batch 3: repos 11-15 → ~2 segundos (paralelo)
         ↓ (espera)
Batch 4: repos 16-20 → ~2 segundos (paralelo)

Total: ~8 segundos
```

---

### 3. Proceso de refreshProjectStatus()

#### **Por cada repositorio:**

```swift
func refreshProjectStatus(_ project: Project) async {
    do {
        // ❌ BLOCKING: Cada llamada ejecuta ~10 comandos git
        let gitStatus = try await gitService.getStatus(for: project)
        
        // Update UI
        updateProjectRecursively(...)
    } catch {
        // Handle error
    }
}
```

---

### 4. GitService.getStatus() - El cuello de botella

#### **Ejecución secuencial de comandos:**

```swift
func getStatus(for project: Project) async throws -> GitStatus {
    let gitPath = await resolveCommandPath("git")
    
    // ❌ TODO SECUENCIAL - Un comando a la vez
    
    // 1. Get current branch
    let branch = try await getCurrentBranch(path: project.path, gitPath: gitPath)
    
    // 2. Check for uncommitted changes
    let changes = try await hasUncommittedChanges(path: project.path, gitPath: gitPath)
    
    // 3. Get untracked files
    let untrackedFiles = try await getUntrackedFiles(path: project.path, gitPath: gitPath)
    
    // 4. Get modified files
    let modifiedFiles = try await getModifiedFiles(path: project.path, gitPath: gitPath)
    
    // 5. Get staged files
    let stagedFiles = try await getStagedFiles(path: project.path, gitPath: gitPath)
    
    // 6. Get last commit
    let commit = try await getLastCommit(path: project.path, gitPath: gitPath)
    
    // 7. Get behind/ahead counts
    let behindAhead = try await getBehindAheadCounts(path: project.path, gitPath: gitPath)
    
    // 8. Get branch list
    let branchList = try await getBranches(path: project.path, gitPath: gitPath)
    
    // 9. Check GitHub integration
    let isGitHub = await isGitHubRepository(at: project.path)
    
    // 10. Get PR count
    let prCount = await getPendingPullRequestCount(path: project.path)
    
    return GitStatus(...)
}
```

**Tiempo por repo:**
- Cada comando git: ~50-200ms (incluye process spawn, exec, I/O)
- 10 comandos × 100ms promedio = **~1 segundo por repo**

---

## 🔍 ANÁLISIS DE PERFORMANCE

### Timeline Completo (20 repos)

```
T=0s     App Launch
         ↓
T=0.5s   Scan filesystem complete
         discoveredProjects = [20 repos sin status]
         ↓
         UI Update #1: Usuario ve lista sin info
         ↓
T=0.5s   Start Batch 1 (repos 1-5)
         ├─ Repo 1: 10 git commands (~1s)
         ├─ Repo 2: 10 git commands (~1s) } Paralelo
         ├─ Repo 3: 10 git commands (~1s)
         ├─ Repo 4: 10 git commands (~1s)
         └─ Repo 5: 10 git commands (~1s)
         ↓
T=2.5s   Batch 1 complete
         UI Update: 5 repos con status
         ↓
T=2.5s   Start Batch 2 (repos 6-10)
         ... (mismo proceso)
         ↓
T=4.5s   Batch 2 complete
         UI Update: 10 repos con status
         ↓
T=4.5s   Start Batch 3 (repos 11-15)
         ↓
T=6.5s   Batch 3 complete
         ↓
T=6.5s   Start Batch 4 (repos 16-20)
         ↓
T=8.5s   ✅ ALL COMPLETE
         isScanning = false
```

---

## ❌ PROBLEMAS IDENTIFICADOS

### 1. **Escaneo Filesystem - No Optimal**

```swift
// ACTUAL: Secuencial
for path in monitoredPaths {
    await scanPathForProjects(path)
}

// MEJOR: Paralelo
await withTaskGroup(of: [Project].self) { group in
    for path in monitoredPaths {
        group.addTask {
            await scanPathForProjects(path)
        }
    }
}
```

### 2. **Batch Processing - Fijo en 5**

```swift
// ACTUAL: Hardcoded
let batches = gitRepos.chunked(into: 5)

// MEJOR: Configurable basado en CPU
let optimalBatchSize = ProcessInfo.processInfo.activeProcessorCount
let batches = gitRepos.chunked(into: optimalBatchSize)
```

**En un Mac M1 (8 cores):**
- Batch actual: 5 repos simultáneos
- Batch optimal: 8 repos simultáneos
- **Mejora: 37% más rápido**

### 3. **Git Commands - Todo Secuencial**

```swift
// ACTUAL: Secuencial dentro de getStatus()
let branch = try await getCurrentBranch(...)      // Espera
let changes = try await hasUncommittedChanges(...) // Espera
let files = try await getUntrackedFiles(...)       // Espera
// ...

// MEJOR: Paralelizar comandos independientes
async let branch = getCurrentBranch(...)
async let changes = hasUncommittedChanges(...)
async let files = getUntrackedFiles(...)
async let modified = getModifiedFiles(...)
async let staged = getStagedFiles(...)

let (b, c, f, m, s) = try await (branch, changes, files, modified, staged)
```

**Mejora potencial:**
- Actual: 10 comandos × 100ms = 1000ms
- Paralelo: max(comandos) ≈ 200ms
- **5x más rápido! 🚀**

### 4. **No hay Queue Management**

- No hay priorización (repos importantes primero)
- No hay cancelación si el usuario navega a otra vista
- No hay retry logic si un comando falla
- No hay rate limiting

---

## ✅ OPTIMIZACIONES PROPUESTAS

### Optimización 1: Paralelizar Filesystem Scan

```swift
func scanMonitoredPaths() async -> [Project] {
    await withTaskGroup(of: [Project].self) { group in
        for path in monitoredPaths {
            group.addTask {
                await self.scanPathForProjects(path)
            }
        }
        
        var allProjects: [Project] = []
        for await projects in group {
            allProjects.append(contentsOf: projects)
        }
        return allProjects
    }
}
```

**Ganancia:** 3 paths: 1.5s → 0.5s (**3x más rápido**)

---

### Optimización 2: Dynamic Batch Size

```swift
func scanAllProjects() async {
    // ...
    
    // Usar número de cores disponibles
    let batchSize = max(5, ProcessInfo.processInfo.activeProcessorCount)
    let batches = gitRepos.chunked(into: batchSize)
    
    // ...
}
```

**Ganancia:** ~30-40% más rápido en Macs modernos

---

### Optimización 3: Paralelizar Git Commands

```swift
func getStatus(for project: Project) async throws -> GitStatus {
    let gitPath = await resolveCommandPath("git")
    
    // Paralelizar comandos INDEPENDIENTES
    async let branch = getCurrentBranch(path: project.path, gitPath: gitPath)
    async let changes = hasUncommittedChanges(path: project.path, gitPath: gitPath)
    async let untracked = getUntrackedFiles(path: project.path, gitPath: gitPath)
    async let modified = getModifiedFiles(path: project.path, gitPath: gitPath)
    async let staged = getStagedFiles(path: project.path, gitPath: gitPath)
    async let commit = getLastCommit(path: project.path, gitPath: gitPath)
    
    // Esperar resultados en paralelo
    let (
        currentBranch,
        uncommittedChanges,
        untrackedFiles,
        modifiedFiles,
        stagedFiles,
        lastCommit
    ) = try await (branch, changes, untracked, modified, staged, commit)
    
    // Comandos que DEPENDEN de branch (deben ir después)
    let behindAhead = try await getBehindAheadCounts(
        path: project.path, 
        gitPath: gitPath
    )
    
    async let branchList = getBranches(path: project.path, gitPath: gitPath)
    async let isGitHub = isGitHubRepository(at: project.path)
    
    let (branches, hasGitHub) = await (branchList, isGitHub)
    
    // PR count solo si es GitHub
    let prCount = hasGitHub ? await getPendingPullRequestCount(path: project.path) : 0
    
    return GitStatus(
        currentBranch: currentBranch,
        hasUncommittedChanges: uncommittedChanges,
        untrackedFiles: untrackedFiles,
        modifiedFiles: modifiedFiles,
        stagedFiles: stagedFiles,
        // ...
    )
}
```

**Ganancia:** 1000ms → 200ms (**5x más rápido per repo**)

---

### Optimización 4: Priority Queue

```swift
struct PriorityProject {
    let project: Project
    let priority: Int
}

func scanAllProjectsWithPriority() async {
    let gitRepos = getAllGitRepos(from: sortedProjects)
    
    // Priorizar por last reviewed (más reciente = mayor prioridad)
    let prioritized = gitRepos
        .sorted { $0.lastReviewed > $1.lastReviewed }
        .enumerated()
        .map { PriorityProject(project: $0.element, priority: $0.offset) }
    
    // Procesar primero los más importantes
    for batch in prioritized.chunked(into: batchSize) {
        // ...
    }
}
```

**Beneficio UX:** Usuario ve sus repos importantes primero

---

## 📊 COMPARACIÓN FINAL

### Escenario: 20 repos

| Optimización | Tiempo | Mejora | Comandos Git |
|--------------|--------|--------|--------------|
| **Actual** | ~8s | - | 200 |
| + Parallel Scan | ~7.5s | 6% | 200 |
| + Dynamic Batch | ~6s | 25% | 200 |
| + Parallel Git Cmds | ~2s | **75%** ⚡ | 200 |
| **+ CACHE** | **~0.1s** | **99%** 🚀 | 20-40 |

---

## 🎯 RECOMENDACIÓN FINAL

### Stack de Optimizaciones:

1. **Implementar CACHE** (máxima prioridad)
   - 99% mejora en carga inicial
   - 80-90% menos comandos git

2. **Paralelizar Git Commands** (alta prioridad)
   - 5x más rápido por repo
   - Sin cambiar arquitectura major

3. **Dynamic Batch Size** (media prioridad)
   - 30-40% más rápido
   - Una línea de código

4. **Parallel Filesystem Scan** (baja prioridad)
   - 3x más rápido en scan
   - Pero scan ya es rápido (~0.5s)

### Implementar en este orden:
1. ✅ Cache System (docs ya creados)
2. ✅ Parallel Git Commands
3. ✅ Dynamic Batching
4. (Opcional) Parallel Scan

---

**¿Quieres que implemente las optimizaciones de paralelización de Git commands ahora?** 🚀
