# -*- mode: sh; sh-shell: bash -*-
# Remove packages from $GIT_REPO_PATH

pkg-command "remove" "Uninstall and remove a package from this git repo"

function cmd::remove::help {
	echo "Usage: pacom remove [OPTIONS] [<PKG> ...]"
	echo ""
	echo "Remove the specified PKGs from both the git and the pacman repositories."
	echo ""
	echo "Options:"
	echo "  -a, --all        Instead of passing each separate package as argument, you can use this"
	echo "                   to remove all packages from this git repository."
	echo "  -h, --help       Show this message."
}

function cmd::remove {
	local pkgs=() removed_packages=0 installed_packages=()

	declare opt_all opt__list
	parseopts "a" "all" "$@" || exit 1
	cmd::remove::validates_args "$@"

	# Read the packages from parameters or get all from the $GIT_REPO_PATH
	if $opt_all; then mapfile -t pkgs < <(db::list_pkgs); else pkgs=("${opt__list[@]}"); fi

	for pkg in "${pkgs[@]}"; do
		remove_pkg_repo "$pkg" && ((removed_packages+=1))

		# Check whether that package has been installed, so we flag it to removal
		pacman -Q "$pkg" > /dev/null 2>&1 && installed_packages+=("$pkg")
	done

	# Then uninstall the installed packages
	uninstall_pkgs "${installed_packages[@]}"

	if [ "$removed_packages" -le 0 ]; then
		msg "No packages removed."
	else
		msg "$removed_packages package(s) removed."
	fi
}

function cmd::remove::validates_args {
	validates_all_or_package_argument_list "cmd::remove::help" "$opt_all" "${#opt__list[@]}"
}

# Uninstall the packages from system
function uninstall_pkgs {
	test $# -gt 0 && sudo pacman -Rsc --noconfirm "$@"
}

# Remove a single package from this git repo
function remove_pkg_repo {
	local pkg=$1

	local removed=0

	# First we remove it from the repo
	if repo::has_package "$pkg"; then
		remove_from_local_repo "$pkg"
		msg "Package $pkg removed from local repository."
		removed=1
	fi

	# Remove package from git, then from DB, them commit the change
	if db::package_exists "$pkg"; then
		if ! git::remove_submodule "$pkg"; then
			error "Failed to remove $pkg locally. Please check the logs!"
			return 1
		fi

		db::remove_package "$pkg"
		git::commit_db ":fire: remove $pkg"
		removed=1
	fi

	if [ $removed -eq 0 ]; then
		error "Package $pkg not present on db/local repos."
		return 1
	fi

	return 0
}

function remove_from_local_repo {
	local pkg=$1

	# Remove the built package files
	while read -r pkgfile; do
		test -f "$pkgfile" && rm -f "$pkgfile"
	done < <(repo::list_existing_pkg_files "$pkg")

	# Remove the package from the repo, if present
	repo-remove "$PACMAN_REPO_PATH" "$pkg"

	# Then reload the pacman database
	repo::update_pacman_db
}
