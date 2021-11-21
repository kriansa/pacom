# -*- mode: sh; sh-shell: bash -*-
# Add the specified packages to $GIT_REPO_PATH

pkg-command "add" "Add a new package to the git repo"

function cmd::add::help {
	echo "Usage: pacom add [OPTIONS] <URL> [<URL> ...]"
	echo ""
	echo "Adds the package(s) to the git repository. the <URL> parameter can be any GIT URL, in the"
	echo "following formats: https://, ssh:// or git://. If you want to add an AUR package, pass only"
	echo "the name and it will be assumed as an AUR repo."
	echo ""
	echo "If you want to add another package to the repo that is not located on AUR, please follow"
	echo "the instructions below very carefully."
	echo ""
	echo "By default, pacom assumes that the specified URL has the PKGBUILD on the root of the git"
	echo "repository, but if you want to specify a different path to it, add a hash (#) and the path"
	echo "to folder where the PKGBUILD is located at."
	echo ""
	echo "If the PKGBUILD of the package you want to install provides a package-split, which means it"
	echo "will compile multiple packages at once, then you must specify which package you want to"
	echo "build, by adding it after a bang (!) on the URL parameter, for example:"
	echo ""
	echo -e "  - git://git@mysecureserver.com:my/git/repo.git\e[1;91m#\e[0msrc/hidden/build\e[1;91m!\e[0mpkg-name"
	echo -e "\e[1;32m                                              ↗  ↑                 ↖\e[0m"
	echo "     This whole string up until this point is    Now, past this      And lastly, after the"
	echo "     the path to the git server. Pretty          hash, it's the      exclamation (bang), is"
	echo "     straightforward.                            path to the         for the rarest cases"
	echo "                                                 PKGBUILD file.      that you will need to"
	echo "                                                                     specify a pkgname out"
	echo "                                                                     of a split-package."
	echo ""
	echo "    In most of the cases, the last parameter (pkgname) will hardly ever be needed."
	echo "    But for the sake of good comprehension, make sure you understand when to use it."

	echo ""
	echo "Options:"
	echo "  -i, --install   After adding it to the db, builds then install each listed package."
	echo "  -h, --help      Show this message."
}

function cmd::add {
	local pkgs=() added_packages=() added_packages_count=0

	declare opt_install opt__list
	parseopts "i" "install" "$@" || exit 1
	cmd::add::validates_args "$@"

	# Read the packages from parameters
	pkgs=("${opt__list[@]}")

	for pkg in "${pkgs[@]}"; do
		# This function includes added packages onto the `added_packages` array. Although it might
		# break referential transparency due to touching variables outside its context, this is done
		# in a controlled environment and the use of this pattern is discouraged across the codebase.
		add_pkg "$pkg" && ((added_packages_count+=1))
	done

	if [ "$added_packages_count" -le 0 ]; then
		msg "No packages added."
	else
		msg "$added_packages_count package(s) added."
	fi

	# If we also want to install the package, then we'll call `build_install` available on `build.sh`
	# Notice that we never want to use --force in this case anyway, since we're building the package
	# for the first time, it wouldn't be necessary. If needed, the user can always `build --force`
	if [ "$added_packages_count" -gt 0 ] && $opt_install; then
		build_install true false "${added_packages[@]}"
	fi
}

function cmd::add::validates_args {
	if [ $# -le 0 ]; then
		error "You need to specify at least one package in the arguments!"
		echo
		cmd::add::help
		exit 1
	fi
}

# Clones a git repo onto $GIT_REPO_PATH
# This function includes added packages onto the `added_packages` array. Although it might
# break referential transparency due to touching variables outside its context, this is done
# in a controlled environment and the use of this pattern is discouraged across the codebase.
function add_pkg {
	local url=$1

	msg "Adding $url"

	# Get the path to PKGBUILD out of the URL
	local git_url; git_url="$(url::get_git_url "$url")" || return 1
	local pkgbuild_path; pkgbuild_path=$(url::get_pkgbuild_hint "$url") || return 1

	if url::is_aur "$url"; then
		local pkg_name="$url"
	else
		local pkg_name; pkg_name="$(get_git_pkgname "$url")" || return 1
	fi

	# Ensure we store all pkgnames lowercased
	pkg_name="$(str::lower "$pkg_name")"

	# Check if package is already on the DB
	if db::package_exists "$pkg_name"; then
		msg2 "Package $pkg_name already on git repo, you need to manually build/install it. Skipping..."
		return 1
	fi

	msg2 "Downloading PKGBUILD for $pkg_name"
	git::get_pkgbuild "$git_url" "$pkgbuild_path" | show_file_contents; status=$?
	test $status -ne 0 && return 1

	ask "Continue?" || return 2

	# Clone the submodule onto the "pkgname" directory
	git::add_submodule "$git_url" "$pkg_name"
	db::add_package "$pkg_name" "$git_url" "$pkgbuild_path"
	git::commit ":sparkles: add $pkg_name"

	msg "Added $pkg_name"
	added_packages+=("$pkg_name")
}

# This function opens up the text editor so the user can see the contents of the PKGBUILD file
# before accepting it. It tries to be smart enough by identifying the editor preference by looking
# at $EDITOR env var, but it could be smarter and maybe look at some configuration or even
# implementing our own terminal-based file viewer.
function show_file_contents {
	if [ -z "$EDITOR" ]; then
		if command -v "vim" > /dev/null; then
			EDITOR=vim
		elif command -v "nano" > /dev/null; then
			EDITOR=nano
		else
			error "No known text editor found. Please define one using the \$EDITOR environment variable."
			exit 1
		fi
	fi

	# If we have $EDITOR set, but it points nowhere
	if ! command -v "$EDITOR" > /dev/null; then
		error "No text editor found using the \$EDITOR environment variable!"
		exit 1
	fi

	if [ "$EDITOR" = "nvim" ]; then
		$EDITOR -R -
	elif [[ "$EDITOR" == *"vim" ]]; then
		$EDITOR -R --not-a-term -
	elif [ "$EDITOR" = "nano" ]; then
		$EDITOR -v -
	else
		$EDITOR -
	fi
}

# Handling split-packages
# -----------------------
# The reason why this algo for fetching a pkgname is so complex is due to split-packages. This is a
# feature on ABS that allows a single PKGBUILD to build multiple packages at once, leveraging the
# same metadata, sources, etc. Unfortunately, that also adds some complexity to package management
# in general. One of them is that we can not easily identify a package name from a PKGBUILD, because
# it's not "a" package, but rather it could refer to several. That complexity adds up when we add
# support for non-AUR repositories, which are usually monorepos full of PKGBUILDs and we can't
# easily identify their pkgnames.
#
# This is the rationale we use to name a package:
#
# 1. Is this an AUR? If so, then we lookup for its repository name using AUR RPC API and set its
#    git_url. By default, if that API call returns anything, we also get to confirm the package name
#    provided by the user is correct and set it as the pkgname.
#
# 2. If it's not an AUR, then it gets a little bit more complex, because we no longer have package
#    names to fetch, but instead URLs that points to PKGBUILDs, and there's no semantic on URLs that
#    enforces a given name to a package based on the URL only.  In that case, to identify that
#    pkgname, we need to check if that repo is a split package. We can do so by fetching the
#    PKGBUILD, then checking if we find a pkgbase variable in it. If we find nothing, good, then
#    that is a single package, and we name it after the variable "pkgname" in the PKGFILE.
#    However, if we found a pkgbase variable, then it's a split-package. Here's how we proceed: if
#    the user hasn't provided the "packagename" parameter (string after the !), then we error and
#    exit, otherwise we define that as the pkgname and move on.
function get_git_pkgname {
	local url=$1

	local git_url; git_url="$(url::get_git_url "$url")" || return 1
	local pkgbuild_path; pkgbuild_path=$(url::get_pkgbuild_hint "$url") || return 1
	local pkgbuild; pkgbuild=$(git::get_pkgbuild "$git_url" "$pkgbuild_path") || return 1
	local pkgbase; pkgbase="$(git::get_pkgbuild_variable "$pkgbuild" pkgbase)"
	local pkg_name_hint; pkg_name_hint=$(url::get_pkgname_hint "$url")

	# We'll set the name as the hint suggests, if passed
	local pkg_name="$pkg_name_hint"

	# If the package is NOT a package-split (and user hasn't provided a hint)
	if [ -z "$pkgbase" ] && [ -z "$pkg_name" ]; then
		# We'll try to retrieve it from the pkgbuild, otherwise the user is out of luck
		pkg_name="$(git::get_pkgbuild_variable "$pkgbuild" pkgname)"

		if [ -z "$pkg_name" ]; then
			error "Can't figure out what's the name of that package! Please force it using the name hint the the parameter!"
			return 1
		fi

	# It's a package-split - bail if user hasn't provided a pkgname hint for split-packages
	elif [ -z "$pkg_name_hint" ]; then
		error "Found PKGBUILD as a split-package. You need to specify what's the name of the package in the parameter!"
		return 1
	fi

	echo "$pkg_name"
}
