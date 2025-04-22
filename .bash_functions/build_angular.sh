build_angular() {
  echo "Cleaning dist/..."
  rm -rf dist/
  echo "Starting build..."
  ng build --optimization=false --build-optimizer=false "$@"
}

watch_angular() {
  echo "Cleaning dist/..."
  rm -rf dist/
  echo "Starting watch build..."
  ng build --optimization=false --build-optimizer=false --watch "$@"
}
