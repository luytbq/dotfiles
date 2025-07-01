m1() {
	git checkout -f prod && git pull && git checkout -b luytbq/prod/ENH_20250423_065-phase2
}
m2() {
	create_mr --target prod --description https://10.36.36.63:8618/op_pm/Project/Detail/472b1fa5-0063-4e56-bcb6-3d95c334f1e8
}
create_mr() {
    local source=""
    local target="prod"
    local description=""

    # Parse named arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --source)
                source="$2"
                shift 2
                ;;
            --target)
                target="$2"
                shift 2
                ;;
            --description)
                description="$2"
                shift 2
                ;;
            *)
                echo "Unknown argument: $1"
                return 1
                ;;
        esac
    done

    local repo_url
    repo_url=$(git remote get-url origin)

    if [[ -z "$source" ]]; then
        source=$(git branch --show-current)
    fi

    # Convert SSH URL to HTTPS URL
    local repo_https_url
    repo_https_url=$(echo "$repo_url" | sed -E 's#ssh://git@([^:]+):[0-9]+/(.+)\.git#https://\1/\2#')

    echo "Repo URL (HTTPS): $https_url"
    echo "Source Branch: $source"
    echo "Target Branch: $target"

	local mr_url="${repo_https_url}/-/merge_requests/new"
	mr_url="${mr_url}?merge_request[source_branch]=${source}"
	mr_url="${mr_url}&merge_request[target_branch]=${target}"
	mr_url="${mr_url}&merge_request[description]=${description}"
    echo "New merge request URL:"
	echo "$mr_url"
}

replace_dev_domain() {
	local subdomain="$1"
	if [[ -z "$subdomain" ]]; then
		echo "Usage: replace_dev_domain dev18"
		return 1
	fi

	find . -type f -name "*.ts" \
		! -path "./node_modules/*" \
		! -path "./dist/*" \
		! -path "./.git/*" \
		! -name "lang-vi.ts" \
		! -name "lang-en.ts" \
		-exec grep -lE 'https://(.*)onepay.vn' {} + \
		| xargs sed -i "s|https://\(.*\)onepay.vn|https://${subdomain}.onepay.vn|g"
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
		echo "Usage: ${0} <host> <theme>"
		echo "Example: ${0} dev18 installment"
		return 1
	fi

	nvm use 16

	replace_dev_domain $host

	echo "Cleaning dist/..."
	rm -rf dist/
	echo "Building theme"
	ng build --configuration production --base-href=/paygate/${theme}/ --output-path=dist/paygate/${theme}/
	rsync -av --progress --delete --rsh='ssh -p7602' dist/paygate/${theme}/ root@${host}:/usr/share/nginx/onepay.vn/paygate/${theme}/
}
