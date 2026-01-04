# Visual UI/UX Examples - GitMonitor

## 🎨 Before & After Comparisons

---

## 1. Status Indicators Evolution

### ❌ Current Implementation
```swift
// Simple colored circle
Circle()
    .fill(statusColor)
    .frame(width: 8, height: 8)
```
**Visual:**
```
🟢 Project A
🟡 Project B
🔵 Project C
```

### ✅ Improved Implementation
```swift
HStack(spacing: 12) {
    // Animated circle with glow
    ZStack {
        Circle()
            .fill(statusColor.opacity(0.2))
            .frame(width: 18, height: 18)
            .blur(radius: 3)

        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
    }

    // Status text with timestamp
    VStack(alignment: .leading, spacing: 2) {
        Text("Clean")
            .font(.subheadline)
            .fontWeight(.medium)

        Text("Updated 2m ago")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    // Trend indicator
    Image(systemName: "arrow.down.circle.fill")
        .font(.caption)
        .foregroundColor(.green)
}
```
**Visual:**
```
┌────────────────────────────────────────────┐
│ ●✨  Clean                                 │
│      Updated 2m ago              ↓         │
└────────────────────────────────────────────┘
```

---

## 2. Project Row Enhancement

### ❌ Current
```swift
HStack {
    Circle().fill(.green)
    Text("Project A")
}
```

### ✅ Improved
```swift
HStack(spacing: 12) {
    // Status indicator
    StatusIndicator(status: .success, size: 12)

    VStack(alignment: .leading, spacing: 4) {
        Text("Project A")
            .font(.subheadline)
            .fontWeight(.medium)

        HStack(spacing: 6) {
            Image(systemName: "git.branch")
                .font(.caption2)
            Text("main")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if needsAttention {
                StatusBadge(text: "3 changes", status: .warning)
            }
        }
    }

    Spacer()

    // Last update
    Text("5m")
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(4)
}
```

**Visual:**
```
┌────────────────────────────────────────────────┐
│ 🟢 Project A                    [5m]           │
│     main  [3 changes]                        │
└────────────────────────────────────────────────┘
```

---

## 3. Dashboard Cards

### New Component
```swift
struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)

                Spacer()

                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
```

**Layout:**
```
┌──────────────┬──────────────┬──────────────┬──────────────┐
│ 📁           │            │ ⚠️           │ ↓↧           │
│              │              │              │              │
│    12        │    10        │    3         │    7         │
│              │              │              │              │
│ Total        │ Repos        │ Need Atten.  │ PRs          │
└──────────────┴──────────────┴──────────────┴──────────────┘
```

---

## 4. Animations Examples

### Scanning Animation
```swift
struct ScanningProgressView: View {
    @State private var isAnimating = false
    let progress: Double

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color(.controlBackgroundColor), lineWidth: 4)
                .frame(width: 40, height: 40)

            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: progress)

            // Percentage
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .fontWeight(.bold)
        }
    }
}
```

**Visual:**
```
Scanning...
    [75% ▶️] ← Animated progress circle

Project A ████████████░░ 80%
Project B ██████████░░░░ 60%
Project C ████████░░░░░░ 40%
```

### List Item Animation
```swift
struct AnimatedProjectRow: View {
    let project: Project
    @State private var isVisible = false

    var body: some View {
        HStack {
            // Content
        }
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : -20)
        .animation(
            .spring(response: 0.4, dampingFraction: 0.8)
            .delay(0.1 * index),  // Stagger effect
            value: isVisible
        )
        .onAppear {
            isVisible = true
        }
    }
}
```

**Effect:**
```
t=0.0s  [hidden, offset -20px]
t=0.1s  [fade in, slide to 0px] ← item 1
t=0.2s  [fade in, slide to 0px] ← item 2
t=0.3s  [fade in, slide to 0px] ← item 3
```

---

## 5. Status Badges

### Simple Badge
```swift
struct StatusBadge: View {
    let text: String
    let status: StatusLevel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)

            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.15))
        .foregroundColor(status.color)
        .cornerRadius(12)
    }
}
```

**Examples:**
```
[✓ Clean]         ← Green
[⚠️ 3 changes]    ← Orange
[↓ 2 PRs]        ← Blue
[✗ Critical]     ← Red
```

### Interactive Badge
```swift
struct InteractiveStatusBadge: View {
    @State private var isHovering = false

    var body: some View {
        StatusBadge(text: "3 changes", status: .warning)
            .scaleEffect(isHovering ? 1.05 : 1.0)
            .shadow(
                color: isHovering ? .orange.opacity(0.3) : .clear,
                radius: 4
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
            .cursor(.pointingHand)
    }
}
```

**Effect:**
```
Hover:
  [⚠️ 3 changes] → Slight scale up + shadow glow
  Cursor: → Pointing hand
```

---

## 6. Timeline Activity

### Component
```swift
struct ActivityTimeline: View {
    let activities: [Activity]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(activities.enumerated()), id: \.offset) { index, activity in
                HStack(alignment: .top, spacing: 12) {
                    // Timeline
                    VStack(spacing: 0) {
                        Circle()
                            .fill(activity.color)
                            .frame(width: 8, height: 8)

                        if index < activities.count - 1 {
                            Rectangle()
                                .fill(Color(.separator))
                                .frame(width: 2)
                                .padding(.top, 4)
                        }
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activity.title)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(activity.description)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(activity.timestamp)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}
```

**Visual:**
```
●─  Project A committed
│
   "Updated user authentication"
   5 minutes ago
│
●─  Project B has changes
│
   "3 files modified"
   12 minutes ago
│
●─  PR #42 opened
│
   "Feature/new-ui"
   1 hour ago
│
○─  All projects scanned
   2 hours ago
```

---

## 7. Filter Pills

```swift
struct FilterPills: View {
    @State private var selectedFilter: Filter = .all

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Filter.allCases) { filter in
                    FilterPill(
                        title: filter.displayName,
                        isSelected: selectedFilter == filter,
                        count: filter.count
                    ) {
                        withAnimation(.spring()) {
                            selectedFilter = filter
                        }
                    }
                }
            }
        }
    }
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let count: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                if let count = count {
                    Text("(\(count))")
                        .font(.caption2)
                }
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.controlBackgroundColor))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
            .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
```

**Visual:**
```
┌─────────────────────────────────────────────────┐
│ [All (12)] [Needs Atten. (3)] [Has PRs (7)]     │
│             ↑ Selected                          │
└─────────────────────────────────────────────────┘
```

---

## 8. Context Menu

```swift
.contextMenu {
    Button {
        // Open in Finder
    } label: {
        Label("Open in Finder", systemImage: "folder")
    }

    Button {
        // Open in Terminal
    } label: {
        Label("Open in Terminal", systemImage: "terminal")
    }

    Divider()

    Menu {
        Button("Copy Branch Name") {
            // Copy
        }

        Button("Copy Path") {
            // Copy
        }

        Button("Copy Last Commit") {
            // Copy
        }
    } label: {
        Label("Copy", systemImage: "doc.on.doc")
    }

    Divider()

    Button(role: .destructive) {
        // Stop monitoring
    } label: {
        Label("Stop Monitoring", systemImage: "trash")
    }
}
```

**Visual:**
```
Right-click on project:

┌──────────────────────────────┐
│ Open in Finder      📁       │
│ Open in Terminal    ⌘       │
├──────────────────────────────┤
│ Copy               📋       │
│ ├─ Copy Branch Name         │
│ ├─ Copy Path                │
│ └─ Copy Last Commit         │
├──────────────────────────────┤
│ Stop Monitoring     🗑️       │
└──────────────────────────────┘
```

---

## 9. Success Toast

```swift
struct SuccessToast: View {
    let message: String
    @State private var isVisible = false

    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)

                Text(message)
                    .font(.subheadline)

                Spacer()

                Button {
                    withAnimation {
                        isVisible = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.controlBackgroundColor))
            )
            .shadow(radius: 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .padding()
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        isVisible = false
                    }
                }
            }
        }
    }
}
```

**Visual:**
```
┌─────────────────────────────────────────────┐
│ ✓ Projects scanned successfully        [×]  │
└─────────────────────────────────────────────┘
        ↓ Slides in from top
        ↓ Auto-dismisses after 3s
```

---

## 10. Hover Effects

```swift
struct HoverableCard: View {
    let content: Content
    @State private var isHovering = false

    var body: some View {
        content
            .scaleEffect(isHovering ? 1.02 : 1.0)
            .shadow(
                color: isHovering ? .accentColor.opacity(0.2) : .clear,
                radius: isHovering ? 8 : 0
            )
            .animation(.easeInOut(duration: 0.2), value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
            .cursor(.pointingHand)
    }
}
```

**Effect:**
```
Normal:     [Flat card, no shadow]
Hover:      [Slightly larger, colored glow]
Cursor:     → Pointing hand
```

---

## 🎯 Color Palette

### Status Colors
```swift
extension Color {
    static let statusCritical = Color(red: 0.8, green: 0.2, blue: 0.2)
    static let statusWarning = Color(red: 1.0, green: 0.6, blue: 0.0)
    static let statusSuccess = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let statusInfo = Color(red: 0.2, green: 0.6, blue: 1.0)
    static let statusNeutral = Color(white: 0.6)
}
```

### Dark Mode Compatibility
```swift
struct AdaptiveView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack {
            Text("Hello")
                .foregroundColor(
                    colorScheme == .dark ? .white : .black
                )
        }
        .background(
            colorScheme == .dark
                ? Color(.windowBackgroundColor)
                : Color(.windowBackgroundColor)
        )
    }
}
```

---

## 📐 Spacing & Typography

### Spacing Scale
```swift
struct Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}
```

### Typography Scale
```swift
extension Font {
    static let largeTitle = Font.system(size: 34, weight: .bold)
    static let title1 = Font.system(size: 28, weight: .bold)
    static let title2 = Font.system(size: 22, weight: .bold)
    static let title3 = Font.system(size: 20, weight: .semibold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let subheadline = Font.system(size: 15, weight: .medium)
    static let body = Font.system(size: 15, weight: .regular)
    static let callout = Font.system(size: 14, weight: .regular)
    static let subheadline = Font.system(size: 13, weight: .regular)
    static let footnote = Font.system(size: 12, weight: .regular)
    static let caption1 = Font.system(size: 12, weight: .regular)
    static let caption2 = Font.system(size: 11, weight: .regular)
}
```

---

*Last updated: 2026-01-04*
