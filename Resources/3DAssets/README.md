# 3D Assets for Game Mode

This directory contains 3D models for agents in Game Mode.

## Supported Formats

SceneKit on macOS has varying levels of support for different 3D formats:

| Format | Extension | Support | Performance | Recommended |
|--------|-----------|---------|-------------|-------------|
| **COLLADA** | `.dae` | ✅ Excellent | ⚡ Fast | ✅ **Yes** |
| **USDZ** | `.usdz` | ✅ Native Apple | ⚡ Fast | ✅ Yes |
| **SCN** | `.scn` | ✅ Native Apple | ⚡ Fastest | ✅ Yes |
| **glTF Binary** | `.glb` | ⚠️ Limited | 🐌 Slow | ❌ No |
| **OBJ** | `.obj` | ⚠️ Basic | 🐌 Slow | ⚠️ Textures may not work |
| **FBX** | `.fbx` | ❌ Not supported | - | ❌ No |

**Recommendation**: Use **DAE (COLLADA)** for best compatibility and performance.

## Current Assets

All assets are available in both original GLB and converted DAE formats:

### Characters
- `Rubber_Duck` - Rubber duck character
- `Chicken_Guy` - Chicken character
- `Citizen_1`, `Citizen_2`, `Citizen_3` - Generic citizens
- `Generic_Male`, `Generic_Female` - Generic characters
- `Male_Officer`, `Female_Officer` - Police officers
- `Prisoner` - Prison inmate
- `Crypto_Bro` - Cryptocurrency enthusiast
- `Retail_Worker` - Store employee
- `Food_Worker` - Food service worker
- `Santa_Claus` - Santa character
- `Snowman` - Snowman character

### Objects
- `Chicken_Bucket` - KFC-style bucket
- `Dollar` - Dollar sign/money

### Vehicles
- `Vehicle` - Generic vehicle
- `Orange_Vehicle` - Orange car
- `Taxi_Vehicle` - Taxi cab
- `Police_Car` - Police vehicle

## Converting New Models

If you have new GLB files and need to convert them to DAE:

### Option 1: Using the Conversion Script (Recommended)

```bash
# 1. Make sure Python dependencies are installed
pip3 install trimesh pygltflib pycollada

# 2. Place your .glb files in this directory

# 3. Run the conversion script from project root
python3 convert_glb_to_dae.py
```

The script will:
- Find all `.glb` files in this directory
- Convert them to `.dae` format
- Skip files that are already converted
- Show progress and any errors

### Option 2: Manual Conversion with Blender

1. Install Blender: `brew install --cask blender`
2. Open Blender
3. File → Import → glTF 2.0 (.glb/.gltf)
4. Select your GLB file
5. File → Export → COLLADA (.dae)
6. Save to this directory

### Option 3: Online Converters

- https://www.vectary.com/ - GLB to USDZ/DAE
- https://products.aspose.app/3d/conversion/glb-to-dae

## Using Models in Code

Models are loaded automatically by `Agent3DNode.swift`:

```swift
let agent = Agent3DNode(
    id: UUID(),
    name: "My Agent",
    color: .blue,
    position: CGPoint(x: 100, y: 100),
    modelName: "Rubber_Duck"  // Filename without extension
)
```

The loading system will automatically:
1. Look for `Rubber_Duck.dae` (highest priority)
2. Fall back to `Rubber_Duck.usdz`
3. Fall back to `Rubber_Duck.glb`
4. If none found, use geometric primitives as fallback

## Troubleshooting

### "Model not found" Warning

The app prints available models in the console. Check the logs:

```
⚠️ Model not found: 'MyModel'
   ✓ Found in: /path/to/Resources/3DAssets
   Files: Rubber_Duck.dae, Chicken_Guy.dae, ...
```

Make sure:
- Filename matches exactly (case-sensitive)
- File has `.dae`, `.usdz`, or `.glb` extension
- File is in `Resources/3DAssets/` directory

### "Failed to load model" Error

Check the error message:

```
⚠️ Failed to load model 'MyModel.glb': Error...
   Error Code: 259 - Domain: NSCocoaErrorDomain
   SceneKit has limited GLB support on macOS
   💡 Solution: Convert GLB files to DAE (COLLADA) format
   Run: python3 convert_glb_to_dae.py
```

Solution: Convert the GLB to DAE using the conversion script.

### Model Appears Too Large/Small

Models are auto-scaled to fit a 40-pixel bounding box. To adjust:

1. Edit `Agent3DNode.swift`
2. Find `let targetSize: CGFloat = 40`
3. Change to desired size

### Model Has Wrong Colors/Textures

DAE format should preserve materials and textures. If they don't appear:

1. Check that texture files are in the same directory as the model
2. Try converting with different options
3. Consider using USDZ format instead (better material support)

## File Organization

```
Resources/3DAssets/
├── README.md (this file)
├── Rubber_Duck.glb (original)
├── Rubber_Duck.dae (converted)
├── Chicken_Guy.glb
├── Chicken_Guy.dae
└── ... (21 models total)
```

Both GLB and DAE files are kept for reference. The app prefers DAE files.

## Performance Notes

- **DAE files are larger** than GLB (text-based vs binary)
- But **DAE loads faster** in SceneKit (native support)
- Models are **cached** after first load
- Each unique model is only loaded once in memory

## Adding New Models

To add a new model to Game Mode:

1. **Get the model** in GLB, DAE, or USDZ format
2. **Place it** in `Resources/3DAssets/`
3. **Convert if needed**: `python3 convert_glb_to_dae.py`
4. **Use in code**:
   ```swift
   let agent = Agent3DNode(..., modelName: "YourModel")
   ```
5. **Build and test**: `swift build && swift run GitMonitor`

No need to modify any configuration files - new models are discovered automatically!
