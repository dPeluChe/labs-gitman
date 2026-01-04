#!/bin/bash

# GitMonitor - Build and Run Script

echo "🔨 Building GitMonitor..."
cd "$(dirname "$0")"

# Build the project
swift build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "🚀 Starting GitMonitor..."

    # Run the application
    swift run GitMonitor
else
    echo "❌ Build failed!"
    exit 1
fi
