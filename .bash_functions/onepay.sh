get_repo_url() {
    echo $(git remote get-url origin)
}

get_repo_url_http() {
	local repo_url=$(get_repo_url)
    repo_url_https=$(echo "$repo_url" | sed -E 's#ssh://git@([^:]+):[0-9]+/(.+)\.git#https://\1/\2#')

	echo $repo_url_https
}

get_repo_group() {
	local repo_url=$(get_repo_url)
	repo_url_https=$(echo "$repo_url" | sed -E 's#.*onepay/([^/]+)/.*#\1#')
	echo $repo_url_https
}

get_repo_name() {
	local repo_url=$(get_repo_url)
	repo_name=$(echo "$repo_url" | sed -E 's#.*/([^/]+).git$#\1#')
	echo $repo_name
}

get_theme_name() {
	local repo_group=$(get_repo_group)
	if [[ "$repo_group" != "paygate" ]]; then
		echo "CWD is not a theme"
		return 1
	fi

	local repo_name=$(get_repo_name)
	if [[ "$repo_name" == "paygate-general-fee" ]]; then
		repo_name=$(basename "$PWD")
	fi

	local theme_name=$(echo "$repo_name" | sed -E 's#^paygate-(.*)$#\1#')
	echo "$theme_name"
}


create_mr() {
    local source=""
    local target="prod"
    local title=""
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
            --title)
                title="$2"
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
	mr_url="${mr_url}&merge_request[title]=${title}"
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
	local repo_group=$(get_repo_group)
	if [[ "$repo_group" != "paygate" ]]; then
		echo "projects other than paygate/paygate-* are not implemented yet."
		return 1
	fi

	theme=$(get_theme_name)
	echo "Cleaning dist/..."
	rm -rf dist/

	nvm use 16
	local cmd="ng build --configuration production --base-href=/paygate/${theme}/ --output-path=dist/paygate/${theme}/ --watch"
	echo "Running command:"
	echo "$cmd"
	eval "$cmd"
}

sync_theme() {
	local host="$1"
	local theme="$2"

	if [[ -z "$host" || -z "$theme" ]]; then
		echo "Usage: command <host> <theme>"
		echo "Example: command dev18 installment"
		return 1
	fi

	local cmd="rsync -av --progress --delete --rsh='ssh -p7602' dist/paygate/${theme}/ root@${host}:/usr/share/nginx/onepay.vn/paygate/${theme}/"
	echo "Running command:"
	echo "$cmd"
	eval "$cmd"
}

build_theme_and_sync() {
	local host="$1"
	local theme="$2"

	set -e # Exit on error

	if [[ -z "$host" || -z "$theme" ]]; then
		echo "Usage: command <host> <theme>"
		echo "Example: command dev18 installment"
		return 1
	fi

	nvm use 16

	replace_dev_domain $host

	echo "Cleaning dist/..."
	rm -rf dist/
	echo "Building theme"
	ng build --configuration production --base-href=/paygate/${theme}/ --output-path=dist/paygate/${theme}/
	sync_theme "$host" "$theme"
}
