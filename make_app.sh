#!/bin/zsh
# Baut UMLForge im Release-Modus und verpackt es als UMLForge.app
set -e
cd "$(dirname "$0")"
swift build -c release
APP="UMLForge.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/UMLForge "$APP/Contents/MacOS/UMLForge"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>UMLForge</string>
  <key>CFBundleDisplayName</key><string>UMLForge</string>
  <key>CFBundleIdentifier</key><string>de.yannick.umlforge</string>
  <key>CFBundleExecutable</key><string>UMLForge</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>UTExportedTypeDeclarations</key>
  <array><dict>
    <key>UTTypeIdentifier</key><string>de.yannick.umlforge.diagram</string>
    <key>UTTypeDescription</key><string>UMLForge-Diagramm</string>
    <key>UTTypeConformsTo</key><array><string>public.json</string></array>
    <key>UTTypeTagSpecification</key><dict>
      <key>public.filename-extension</key><array><string>umlforge</string></array>
    </dict>
  </dict></array>
</dict>
</plist>
PLIST
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
echo "Fertig: $(pwd)/$APP"
