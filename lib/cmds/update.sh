# -*- mode: sh; sh-shell: bash -*-
# Update the repo containing the specified packages

pkg-command "update" "Update packages from their external sources"

function cmd::update::help {
	echo "Usage: pacom update [OPTIONS] [<PKG> ...]"
	echo ""
	echo "Update the specified PKGs by pulling the remote git submodule."
	echo ""
	echo "Options:"
	echo "  -a, --all        Instead of passing each separate package as argument, you can use this"
	echo "                   to update all packages from this git repository."
	echo "  -h, --help       Show this message."
}

function cmd::update {
	local pkgs=() updated_packages=0

	declare opt_all opt__list
	parseopts "a" "all" "$@" || exit 1
	cmd::update::validates_args "$@"

	# Read the packages from parameters or get all from the $GIT_REPO_PATH
	if $opt_all; then mapfile -t pkgs < <(db::list_pkgs); else pkgs=("${opt__list[@]}"); fi

	for pkg in "${pkgs[@]}"; do
		update_pkg "$pkg" && ((updated_packages+=1))
	done

	if [ "$updated_packages" -le 0 ]; then
		msg "No updates."
	else
		msg "$updated_packages package(s) updated."
	fi
}

function cmd::update::validates_args {
	validates_all_or_package_argument_list "cmd::update::help" "$opt_all" "${#opt__list[@]}"
}

# Update a git repository under the base package.
#
# Returns a success code if the repository has been updated.
function update_pkg {
	local pkg=$1

	if ! db::package_exists "$pkg"; then
		error "Package $pkg not found!"
		return 1
	fi

	# Signal 0 means "there has been some changes, please rebuild"
	update_remote "$pkg" && return 0
	update_upstream_vcs "$pkg" && return 0

	# Signal 2 means "no changes"
	return 2
}

function update_remote {
	local pkg=$1

	msg "Checking updates for $pkg"

	# Skips if we don't have remote updates
	git::has_updates_for_package "$pkg" || return 2

	# Ask before proceeding. Resets the branch first to avoid problems on merging.
	ask "New update for package $pkg. Continue?" || return 2
	git::diff_remote_package "$pkg"

	# Confirm the diff before merging
	ask "Proceed?" || return 2
	git::update_repo "$pkg"
	local current_ver; current_ver=$(git::cloned_repo_revision "$pkg")
	git::commit_db ":arrow_up: update $pkg to $current_ver"

	# Signal that means "there has been changes, let's rebuild"
	return 0
}

function update_upstream_vcs {
	local pkg=$1

	# Updates on VCS packages are handled differently. Even if there are no changes on the PKGBUILD,
	# there might be changes on the VCS upstream repo, so we need to check if it has updates as well.
	pkg::is_vcs "$pkg" || return 2
	pkg::build_is_latest "$pkg" && return 2

	ask "New update on upstream for VCS package $pkg. Update?" && return 0 || return 2
}
