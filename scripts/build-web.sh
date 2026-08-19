#!/usr/bin/env bash
# Builds the web app: the engine to WebAssembly, plus the fixture the day starts from.
#
# Needs the Swift SDK for WebAssembly once:
#   curl -fLO https://download.swift.org/swift-6.2-release/wasm-sdk/swift-6.2-RELEASE/swift-6.2-RELEASE_wasm.artifactbundle.tar.gz
#   swift sdk install ./swift-6.2-RELEASE_wasm.artifactbundle.tar.gz
# (installing straight from the URL is refused without --checksum, so download it first)
set -euo pipefail

SDK="${NIDO_WASM_SDK:-swift-6.2-RELEASE_wasm}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> building NidoWebBridge for $SDK"
swift build -c release --swift-sdk "$SDK" --product NidoWebBridge

cp .build/wasm32-unknown-wasip1/release/NidoWebBridge.wasm web/nido.wasm
cp examples/sample-day.json web/sample-day.json

echo "==> web/ is ready ($(du -h web/nido.wasm | cut -f1) engine)"
echo "    serve it with:  python3 -m http.server 8787 --directory web"
