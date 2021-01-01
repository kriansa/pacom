# -*- mode: sh; sh-shell: bash -*-
# Seek all packages under the $GIT_REPO_PATH and look for updates. When there
# are, we update, build then install them.

pkg-command "upgrade" "Updates, builds and install the listed packages"

function cmd::upgrade::help {
	echo "Usage: $0 upgrade [OPTIONS] [<PKG> ...]"
	echo ""
	echo "Update, build and install all the specified PKGs"
	echo ""
	echo "Options:"
	echo "  -a, --all       Instead of passing each separate package as argument, you can use this"
	echo "                  to upgrade all packages from this git repository."
	echo "  -h, --help      Show this message."
}

function cmd::upgrade {
	local updated_pkgs=() built_pkgs=() failed_pkgs=()

	declare opt_all opt__list
	parseopts "a" "all" "$@" || exit 1
	cmd::upgrade::validates_args "$@"

	# Read the packages from parameters or get all from the $GIT_REPO_PATH
	if $opt_all; then mapfile -t pkgs < <(db::list_pkgs); else pkgs=("${opt__list[@]}"); fi

	for pkg in "${pkgs[@]}"; do
		update_pkg "$pkg" && updated_pkgs+=("$pkg")
	done

	if [ "${#updated_pkgs[@]}" -eq 0 ]; then
		msg "No updates."
		exit
	else
		msg2 "Updated packages: ${updated_pkgs[*]}"
	fi

	for pkg in "${updated_pkgs[@]}"; do
		build_pkg "$pkg" && built_pkgs+=("$pkg") || failed_pkgs+=("$pkg")
	done

	# Install packages with --force option
	install_pkgs "true" "${built_pkgs[@]}"

	# Then show the errors, if any
	if [ "${#failed_pkgs[@]}" -gt 0 ]; then
		error "Error while building the following packages: ${failed_pkgs[*]}"
		exit 1
	fi
}

function cmd::upgrade::validates_args {
	validates_all_or_package_argument_list "cmd::upgrade::help" "$opt_all" "${#opt__list[@]}"
}
