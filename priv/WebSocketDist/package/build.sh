#!/bin/bash
cd ..
set -ex
JAVASCRIPTKIT_EXPERIMENTAL_EMBEDDED_WASM=true swift package -c release --triple wasm32-unknown-none-wasm js
cp -a .build/plugins/PackageToJS/outputs/Package/. package/swiftwasm-build