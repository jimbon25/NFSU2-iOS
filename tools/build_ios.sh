#!/bin/bash
# ==============================================================================
# Need for Speed: Underground 2 - Native iOS ARM64 Build & IPA Packaging
# ==============================================================================
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
TARGET="arm64-apple-ios14.0"
MIN_IOS="14.0"
J="$(sysctl -n hw.ncpu || echo 4)"

echo "=== Building NFSU2 for iOS (Target: $TARGET, SDK: $SDK_PATH) ==="

CFLAGS="-O3 -target $TARGET -isysroot $SDK_PATH -miphoneos-version-min=$MIN_IOS \
  -fobjc-arc -I$ROOT/runtime -I$ROOT/gen/all -Wno-unused-label -Wno-parentheses-equality \
  -Wno-int-conversion -Wno-tautological-compare -Wno-unused-variable -Wno-deprecated-declarations \
  -Wno-unguarded-availability -Wno-unguarded-availability-new -Wno-macro-redefined"

LDFLAGS="-target $TARGET -isysroot $SDK_PATH -miphoneos-version-min=$MIN_IOS"

FRAMEWORKS="-lm -framework Foundation -framework CoreFoundation -framework UIKit -framework Metal -framework QuartzCore \
  -framework ImageIO -framework CoreGraphics -framework AudioToolbox \
  -framework CoreAudio -framework GameController -framework AVFoundation -lobjc"

mkdir -p "$ROOT/out/obj_ios" "$ROOT/out/obj_ios/srv"

# 1. Compile Shards in Parallel
echo "--- Compiling lifted shards in parallel ($J workers) ---"
export CFLAGS ROOT SDK_PATH TARGET MIN_IOS

{ (cd "$ROOT/gen/all" && ls shard_*.c fntab.c stubs.c 2>/dev/null | sed "s|^|all |")
  [ -d "$ROOT/gen/server" ] && (cd "$ROOT/gen/server" && ls shard_*.c fntab.c stubs.c 2>/dev/null | sed "s|^|server |"); } | \
  xargs -P "$J" -n 2 sh -c '
    case "$1" in all) od="$ROOT/out/obj_ios" ;; *) od="$ROOT/out/obj_ios/srv" ;; esac
    cd "$ROOT/gen/$1"; shift
    obj="$od/$(basename "$1" .c).o"
    if [ -f "$obj" ]; then exit 0; fi
    clang $CFLAGS -c -I"$ROOT/runtime" -I. -o "$obj" "$1"
' sh

# 2. Compile Runtime
echo "--- Compiling iOS runtime ---"
CSRC="mem dispatch genexec heap watchdog win32 win32_ext com debug res fileio overrides d3dx_hle vsemu enhance perflog autotest lifecycle widescreen framerate dinput_pad dikeys keyboard dinput_kbd career intro oracle drifttest discord roam roam_core roam_bsd roam_game mprace horn carsfx racehorn winsock online netrace net_vlan module modheap headlights language"
MSRC="metal audio bundle gamepad keyboard_mac fpscounter texrep ios_view"

pids=""
for f in $CSRC; do
  [ -f "runtime/$f.c" ] || continue
  fx=""; case "$f" in roam_core|roam_game) fx="-ffp-contract=off" ;; esac
  clang $CFLAGS $fx -DNFS_ENHANCED=0 -c -o "out/obj_ios/$f.o" "runtime/$f.c" &
  pids="$pids $!"
done

for f in $MSRC; do
  clang $CFLAGS -DNFS_ENHANCED=0 -c -o "out/obj_ios/$f.o" "runtime/$f.m" &
  pids="$pids $!"
done

clang $CFLAGS -c -o "out/obj_ios/impargs.o" gen/all/impargs.c & pids="$pids $!"
[ -f "gen/server/impargs.c" ] && clang $CFLAGS -c -o "out/obj_ios/srv_impargs.o" gen/server/impargs.c & pids="$pids $!"
[ -f "gen/server/modinfo.c" ] && clang $CFLAGS -c -o "out/obj_ios/srv_modinfo.o" gen/server/modinfo.c & pids="$pids $!"
clang $CFLAGS -DNFS_ENHANCED=0 -c -o "out/obj_ios/boot.o" tests/boot.c & pids="$pids $!"

for p in $pids; do
  wait "$p"
done

# 3. Link Executable
echo "--- Linking native iOS binary (NFSU2) ---"
SHARDS="$(ls out/obj_ios/shard_*.o out/obj_ios/fntab.o 2>/dev/null || true) $([ -f out/obj_ios/stubs.o ] && echo out/obj_ios/stubs.o || true)"
[ -d "out/obj_ios/srv" ] && SHARDS="$SHARDS $(ls out/obj_ios/srv/shard_*.o out/obj_ios/srv/fntab.o 2>/dev/null || true) $([ -f out/obj_ios/srv/stubs.o ] && echo out/obj_ios/srv/stubs.o || true)"

RTOBJS=""
for f in $CSRC $MSRC impargs srv_impargs srv_modinfo boot; do
  [ -f "out/obj_ios/$f.o" ] && RTOBJS="$RTOBJS out/obj_ios/$f.o"
done

clang $LDFLAGS -o "$ROOT/out/NFSU2" $SHARDS $RTOBJS $FRAMEWORKS
strip "$ROOT/out/NFSU2" || true
echo "Binary linked successfully: out/NFSU2 ($(stat -f%z "$ROOT/out/NFSU2" 2>/dev/null || stat -c%s "$ROOT/out/NFSU2") bytes)"

# 4. Packaging iOS App Bundle (.app) and Sideloadable (.ipa)
echo "--- Assembling iOS Application Bundle ---"
APP_DIR="$ROOT/out/Payload/NFSU2.app"
rm -rf "$ROOT/out/Payload" "$ROOT/out/NFSU2-iOS.ipa"
mkdir -p "$APP_DIR"

cp "$ROOT/out/NFSU2" "$APP_DIR/NFSU2"
chmod +x "$APP_DIR/NFSU2"
[ -f "$ROOT/app/registry-defaults.txt" ] && cp "$ROOT/app/registry-defaults.txt" "$APP_DIR/registry-defaults.txt"
[ -f "$ROOT/SPEED2.EXE" ] && cp "$ROOT/SPEED2.EXE" "$APP_DIR/SPEED2.EXE"

# Generate Info.plist
cat << 'EOF' > "$APP_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>NFS Underground 2</string>
    <key>CFBundleExecutable</key>
    <string>NFSU2</string>
    <key>CFBundleIdentifier</key>
    <string>org.nfsu2.ios</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>NFSU2</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.6</string>
    <key>CFBundleVersion</key>
    <string>6</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UILaunchScreen</key>
    <dict/>
    <key>MinimumOSVersion</key>
    <string>14.0</string>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
        <integer>2</integer>
    </array>
    <key>UIRequiresFullScreen</key>
    <true/>
    <key>UIStatusBarHidden</key>
    <true/>
    <key>UIViewControllerBasedStatusBarAppearance</key>
    <false/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UIFileSharingEnabled</key>
    <true/>
    <key>LSSupportsOpeningDocumentsInPlace</key>
    <true/>
    <key>GCSupportsControllerUserInteraction</key>
    <true/>
    <key>GCSupportedGameControllers</key>
    <array>
        <dict>
            <key>ProfileName</key>
            <string>ExtendedGamepad</string>
        </dict>
    </array>
</dict>
</plist>
EOF

# Ad-hoc code sign for sideloading
echo "--- Applying Ad-hoc Code Signature ---"
codesign --force --deep --sign - "$APP_DIR"

# Create IPA archive
echo "--- Packaging into NFSU2-iOS.ipa ---"
(cd "$ROOT/out" && zip -q -r9 NFSU2-iOS.ipa Payload)
echo "=== Build Complete! Artifact: out/NFSU2-iOS.ipa ==="
