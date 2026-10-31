#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -z "${SDKROOT:-}" ] && [ -d /Library/Developer/CommandLineTools/SDKs/MacOSX26.2.sdk ]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.2.sdk
fi
swift run -Xswiftc -DLINESHELF_CHECKS Tendedero
