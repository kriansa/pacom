# -*- mode: sh; sh-shell: bash -*-
# Build the specified packages

pkg-command "build" "Build a package in the git repo"

function cmd::build::help {
	echo "Usage: pacom build [OPTIONS] [<PKG> ...]"
	echo ""
	echo "Builds the specified PKGs."
	echo ""
	echo "Options:"
	echo "  -a, --all       Instead of passing each separate package as argument, you can use this"
	echo "                  to build all packages from this git repository."
	echo "  -i, --install   After building all specified packages, install them with pacom install."
	echo "  -f, --force     Force building and installing a package, even if it's been built."
	echo "  -h, --help      Show this message."
}

function cmd::build {
	local pkgs=()

	declare opt_all opt_install opt_force opt__list
	parseopts "aif" "all,install,force" "$@" || exit 1
	cmd::build::validates_args "$@"

	# Read the packages from parameters or get all from the $GIT_REPO_PATH
	if $opt_all; then mapfile -t pkgs < <(db::list_pkgs); else pkgs=("${opt__list[@]}"); fi

	build_install "$opt_install" "$opt_force" "${pkgs[@]}"
}

function cmd::build::validates_args {
	validates_all_or_package_argument_list "cmd::build::help" "$opt_all" "${#opt__list[@]}"
}

# Couples the logic for build and installation
# This function is also used by `add` command
function build_install {
	local opt_install=$1; shift
	local opt_force=$1; shift
	local pkgs=("$@")
	local built_packages=0

	for pkg in "${pkgs[@]}"; do
		build_pkg "$pkg" "$opt_force" && ((built_packages+=1))
	done

	if [ "$built_packages" -le 0 ]; then
		msg "No packages built."
		return
	elif [ "$built_packages" -lt ${#pkgs[@]} ]; then
		error "Some package(s) could not be built. Please, check the logs."
		return 1
	fi

	if $opt_install && ! install_pkgs "$opt_force" "${pkgs[@]}"; then
		error "Installation failed. Please check the logs."
		return 1
	fi

	if $opt_install; then
		msg "$built_packages package(s) built and installed successfully!"
	else
		msg "$built_packages package(s) built."
	fi
}

# Build a single package
#
# Returns a success code when the build succeeds
function build_pkg {
	local pkg=$1
	local force=$2

	if ! db::package_exists "$pkg"; then
		error "Package $pkg not found!"
		return 2
	fi

	local pkgbuild_dir; pkgbuild_dir="$(db::get_package_pkgbuild_dir "$pkg")"
	local build_path="$GIT_REPO_PATH/$pkg/$pkgbuild_dir"

	# Build the package
	test "$force" = "true" && local force_param="--force"
	msg "Building package $pkg"
	( cd "$build_path" && makepkg --clean --syncdeps --rmdeps --needed --noconfirm $force_param )

	# Stop if the build failed
	test $? -eq 0 || return 2

	# Add the built package to the pacman repo
	while IFS= read -r built_pkg_name; do
		repo::add_package "$built_pkg_name"
	done < <(cd "$build_path" && makepkg --packagelist)

	# Usually the build process leaves some files behind such as caches or PKGBUILD version updates
	# for VCS packages, so we will clean it
	git::clean_repo "$pkg"

	# Then reload the pacman database
	repo::update_pacman_db

	# This line helps to separate when there are multiple packages being built
	echo

	return 0
}
