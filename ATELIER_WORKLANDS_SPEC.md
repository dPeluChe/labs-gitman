# 🏗️ Atelier Worklands: Documento de Definición del Proyecto (PRD)

**Versión:** 1.0
**Fecha:** 13 Enero 2026
**Estado:** Aprobado para Inicio
**Concepto Principal:** Git Manager Gamificado & Orquestador de Agentes AI en Entorno 3D.

---

## 1. Resumen Ejecutivo
**Atelier Worklands** es una evolución radical de las herramientas de gestión de proyectos (Git Clients). Transforma la lista aburrida de repositorios en un **espacio de trabajo tridimensional isométrico (RTS/God-Game style)**.

El usuario actúa como el "Director" de un taller digital donde:
1.  **Los Proyectos son Portales/Estructuras:** Cada repositorio Git es un edificio o portal en el mapa.
2.  **Los Procesos son Agentes:** Las tareas (git status, build, tests, refactoring) son realizadas por personajes 3D (Agentes) que viajan a los portales, trabajan y regresan con resultados.
3.  **La Interfaz es Espacial:** En lugar de menús desplegables, arrastras un agente a un proyecto para iniciar una tarea.

El objetivo es migrar la lógica funcional existente (Swift) a una arquitectura escalable, multiplataforma y gráficamente superior usando **Tauri, Rust y React/Three.js**.

---

## 2. Stack Tecnológico (Estricto)

### 🖥️ Core & Backend (Host)
*   **Framework:** [Tauri v2](https://v2.tauri.app/)
*   **Lenguaje:** **Rust**
*   **Responsabilidades:**
    *   Acceso al Sistema de Archivos (File System).
    *   Ejecución de Procesos (Terminal/Shell commands).
    *   **Gestión de Git:** Uso del crate `git2` (libgit2 bindings) para operaciones rápidas y `Command` para operaciones complejas.
    *   Gestión de la cola de tareas de los agentes (Thread pool).
    *   Puente AI: Comunicación segura con Ollama/LLM APIs.

### 🎨 Frontend & Renderizado 3D
*   **UI Framework:** **React** (TypeScript).
*   **Build Tool:** Vite.
*   **Motor 3D:** **Three.js** a través de **@react-three/fiber (R3F)**.
*   **Helpers 3D:** **@react-three/drei** (para controles de cámara, carga de GLB, texto en 3D).
*   **Estilos UI (HUD):** TailwindCSS + shadcn/ui (para paneles flotantes, terminales y logs).
*   **Estado Global:** Zustand (para sincronizar el estado de los agentes entre Rust y React).

---

## 3. Arquitectura del Sistema

### A. Modelo de Datos (Rust -> TypeScript)
El backend en Rust es la "Fuente de la Verdad".
1.  **`Project` (Struct):**
    *   `path`: String
    *   `name`: String
    *   `git_status`: Struct (Branch, Modified files, Ahead/Behind count).
    *   `health`: Enum (Healthy, Warning, Error, Busy).
2.  **`Agent` (Struct):**
    *   `id`: UUID
    *   `name`: String
    *   `type`: Enum (Duck, Robot, Human).
    *   `state`: Enum (Idle, Moving, Working, Reporting).
    *   `current_task`: Option<Task>.
    *   `position`: (x, y, z) - *Sincronizado con frontend*.

### B. Flujo de Comunicación
1.  **Frontend (React):** Renderiza la escena. Cuando el usuario arrastra un agente a un portal, invoca un comando Tauri: `invoke('assign_task', { agentId, projectId, taskType })`.
2.  **Backend (Rust):**
    *   Recibe el comando.
    *   Cambia el estado del agente a `Moving`.
    *   Calcula la ruta (o simula el tiempo de viaje).
    *   Ejecuta la operación real (ej. `git fetch`, `npm run test`, `llm analyze`).
    *   Emite eventos al frontend (`emit('agent_update', new_state)`) para que el 3D se actualice en tiempo real.

---

## 4. Requerimientos Funcionales (Fase 1: MVP)

### 4.1. El "Taller" (La Escena 3D)
*   **Cámara:** Isométrica fija o con rotación orbital limitada (tipo The Sims o Starcraft).
*   **Grid:** Un suelo cuadriculado donde se posicionan los elementos.
*   **Navegación:** Pan (Click derecho + arrastrar) y Zoom (Scroll).
*   **Iluminación:** Sombras suaves, iluminación ambiental tecnológica.

### 4.2. Gestión de Proyectos (Los Portales)
*   **Importar:** Botón para añadir carpetas locales (abre diálogo nativo).
*   **Visualización:**
    *   Cada proyecto se representa como una plataforma o puerta.
    *   **Estado Visual:**
        *   *Clean:* Luces verdes / estructura calmada.
        *   *Changes:* Luces amarillas / cajas apiladas (archivos modificados).
        *   *Error/Conflict:* Luces rojas / humo.
*   **HUD:** Al pasar el mouse, mostrar un tooltip flotante HTML con: Rama actual, # archivos modificados.

### 4.3. Los Agentes (Workers)
*   **Spawn:** Iniciar con 2 agentes por defecto (ej. "Junior Dev" y "Senior Bot").
*   **Control:** Click para seleccionar, Click derecho en el suelo para mover, Drag & Drop sobre un portal para asignar tarea.
*   **Animación:**
    *   Deben tener ciclos de animación básicos (Idle, Walk, Work).
    *   *Nota:* Usar modelos placeholders (capsulas o low-poly assets gratuitos) para el MVP, pero preparar el sistema para cargar `.glb`.

### 4.4. Sistema de Tareas (El Core)
Las tareas disponibles al soltar un agente en un portal:
1.  **Git Status:** (Rápido) El agente va, escanea y actualiza el visual del portal.
2.  **Git Pull:** (Acción) Trae cambios remotos.
3.  **Code Review (Simulado):** El agente "lee" el código (envía diff a LLM) y genera un reporte de texto.

---

## 5. Estructura de Carpetas Sugerida

```text
Atelier-Worklands/
├── src-tauri/           # Backend (Rust)
│   ├── src/
│   │   ├── main.rs      # Entry point
│   │   ├── git_ops.rs   # Lógica git2 + comandos
│   │   ├── agents.rs    # Máquina de estados de agentes
│   │   └── llm.rs       # Cliente HTTP para Ollama
│   ├── Cargo.toml
│   └── tauri.conf.json
├── src/                 # Frontend (React + TS)
│   ├── components/
│   │   ├── ui/          # Botones, Paneles (HTML/CSS)
│   │   └── world/       # Componentes 3D (R3F)
│   │       ├── Agent.tsx
│   │       ├── Portal.tsx
│   │       └── Scene.tsx
│   ├── stores/          # Zustand store (Game logic)
│   ├── types/           # Interfaces compartidas con Rust
│   └── App.tsx
└── public/              # Assets 3D (.glb, texturas)
```

---

## 6. Pasos de Implementación para el Agente Constructor

1.  **Setup Inicial:**
    *   Crear app Tauri (`npm create tauri-app`).
    *   Instalar dependencias frontend (`three`, `@react-three/fiber`, `@react-three/drei`, `lucide-react`, `zustand`).
    *   Instalar dependencias Rust (`git2`, `serde`, `serde_json`, `tokio`).

2.  **Infraestructura Rust:**
    *   Crear el comando `scan_project(path: String) -> ProjectStatus`.
    *   Configurar el `GameLoop` o sistema de eventos en Rust para manejar el estado de los agentes.

3.  **Mundo 3D:**
    *   Configurar el Canvas R3F.
    *   Implementar el componente `Floor` (Grid).
    *   Implementar el componente `ProjectNode` (Cubo con etiqueta de texto por ahora).

4.  **Integración:**
    *   Conectar el Drag & Drop del agente al comando de Rust.
    *   Mostrar la salida de la terminal en una ventana flotante dentro del juego.

---

## 7. Referencias
*   **Estilo Visual:** Starcraft 2, Habbo Hotel (Isométrico), RALV.ai.
*   **Lógica de Negocio:** Ver código legado en `../labs-gitman/Services/GitService.swift` para entender qué comandos de git se esperan.
