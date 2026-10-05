#!/usr/bin/env bash

set -e

FLUTTER_VERSION="3.47.5"

git clone \
  https://github.com/flutter/flutter.git \
  --depth 1 \
  --branch "$FLUTTER_VERSION" \
  "$HOME/flutter"

export PATH="$HOME/flutter/bin:$PATH"

flutter --version
flutter pub get
flutter build web --release