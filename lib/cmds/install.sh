# -*- mode: sh; sh-shell: bash -*-
# Install the specified packages

pkg-command "install" "Install a package already present in the git repo"

function cmd::install::help {
	echo "Usage: pacom install [OPTIONS] [<PKG> ...]"
	echo ""
	echo "Install the specified PKGs."
	echo ""
	echo "Options:"
	echo "  -a, --all       Instead of passing each separate package as argument, you can use this"
	echo "                  to install all packages from this git repository."
	echo "  -f, --force     Force reinstall, even if the installed package is at the same version."
	echo "  -h, --help      Show this message."
}

function cmd::install {
	local pkgs=()

	declare opt_all opt_force opt__list
	parseopts "af" "all,force" "$@" || exit 1
	cmd::install::validates_args "$@"

	# Read the packages from parameters or get all from the $GIT_REPO_PATH
	if $opt_all; then mapfile -t pkgs < <(db::list_pkgs); else pkgs=("${opt__list[@]}"); fi

	if install_pkgs "$opt_force" "${pkgs[@]}"; then
		msg "${#pkgs[@]} package(s) installed."
	else
		error "Installation failed. Please, check the logs."
		return 1
	fi
}

function cmd::install::validates_args {
	validates_all_or_package_argument_list "cmd::install::help" "$opt_all" "${#opt__list[@]}"
}

function install_pkgs {
	local opt_force=$1; shift

	test "$opt_force" = "false" && local needed_param="--needed"
	msg "Installing packages..."
	sudo pacman -Sy $needed_param --noconfirm "$@"
}
