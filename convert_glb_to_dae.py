#!/usr/bin/env python3
"""
Convert GLB files to DAE (COLLADA) format for SceneKit compatibility.

SceneKit on macOS has limited support for GLB files. This script converts
all GLB files in Resources/3DAssets/ to DAE format, which SceneKit handles natively.

Usage:
    python3 convert_glb_to_dae.py

Requirements:
    pip install trimesh pygltflib pycollada
"""

import os
import sys
from pathlib import Path

def check_dependencies():
    """Check if required libraries are installed."""
    try:
        import trimesh
        import pygltflib
        print("✅ Dependencies installed")
        return True
    except ImportError as e:
        print("❌ Missing dependencies. Installing...")
        print(f"   Error: {e}")
        print("\nRun this command to install:")
        print("   pip3 install trimesh pygltflib pycollada")
        return False

def convert_glb_to_dae(glb_path: Path, dae_path: Path) -> bool:
    """Convert a single GLB file to DAE format."""
    try:
        import trimesh

        print(f"📦 Loading: {glb_path.name}")

        # Load GLB file
        mesh = trimesh.load(str(glb_path), force='mesh')

        # Export to DAE
        print(f"💾 Exporting: {dae_path.name}")
        mesh.export(str(dae_path), file_type='dae')

        # Verify output
        if dae_path.exists():
            size_kb = dae_path.stat().st_size / 1024
            print(f"✅ Success: {dae_path.name} ({size_kb:.1f} KB)")
            return True
        else:
            print(f"❌ Failed: Output file not created")
            return False

    except Exception as e:
        print(f"❌ Error converting {glb_path.name}: {e}")
        return False

def main():
    """Main conversion process."""
    print("=" * 60)
    print("GLB to DAE Converter for SceneKit")
    print("=" * 60)
    print()

    # Check dependencies
    if not check_dependencies():
        sys.exit(1)

    # Find GLB directory
    assets_dir = Path(__file__).parent / "Resources" / "3DAssets"

    if not assets_dir.exists():
        print(f"❌ Directory not found: {assets_dir}")
        sys.exit(1)

    # Find all GLB files
    glb_files = list(assets_dir.glob("*.glb"))

    if not glb_files:
        print(f"⚠️  No GLB files found in {assets_dir}")
        sys.exit(0)

    print(f"Found {len(glb_files)} GLB files to convert\n")

    # Convert each file
    success_count = 0
    failed_files = []

    for glb_path in sorted(glb_files):
        dae_path = glb_path.with_suffix('.dae')

        # Skip if DAE already exists and is newer
        if dae_path.exists() and dae_path.stat().st_mtime > glb_path.stat().st_mtime:
            print(f"⏭️  Skipping: {glb_path.name} (DAE already exists and is newer)")
            continue

        if convert_glb_to_dae(glb_path, dae_path):
            success_count += 1
        else:
            failed_files.append(glb_path.name)

        print()

    # Summary
    print("=" * 60)
    print(f"Conversion complete!")
    print(f"  ✅ Successful: {success_count}")
    print(f"  ❌ Failed: {len(failed_files)}")

    if failed_files:
        print(f"\nFailed files:")
        for filename in failed_files:
            print(f"  - {filename}")

    print("\nNext steps:")
    print("  1. Build the app: swift build")
    print("  2. Run the app: swift run GitMonitor")
    print("  3. The 3D models should now load correctly!")
    print("=" * 60)

if __name__ == "__main__":
    main()
