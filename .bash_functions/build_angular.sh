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

build_theme_and_sync() {
	local host="$1"
	local theme="$2"

	set -e # Exit on error

	if [[ -z "$host" || -z "$theme" ]]; then
		echo "Usage: <function> <host> <theme>"
		return 1
	fi

	echo "Cleaning dist/..."
	rm -rf dist/
	echo "Building theme"
	ng build --optimization=false --build-optimizer=false --base-href=/paygate/${theme}/ --output-path=dist/paygate/${theme}/
	rsync -av --progress --delete --rsh='ssh -p7602' dist/paygate/${theme}/ root@${host}:/usr/share/nginx/onepay.vn/paygate/${theme}/
}
