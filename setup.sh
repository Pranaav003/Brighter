#!/bin/bash
set -e

echo "☀️  Building Brighter..."
swift build --disable-sandbox

echo ""
echo "✅ Build complete!"
echo ""
echo "Run with:"
echo "  .build/debug/Brighter"
echo ""
echo "The sun icon (☀) will appear in your menu bar."
echo "Click it and use the slider to boost brightness up to 200%."
