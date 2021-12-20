# -*- mode: sh; sh-shell: bash -*-
# Common package related functions

function pkg::build_is_latest {
	local pkg=$1

	# Get the current built version on the repo
	local current; current=$(repo::get_built_package_version "$pkg")
	local next; next=$(pkg::get_build_version "$pkg")

	test "$current" = "$next"
}

function pkg::is_vcs {
	local pkg=$1
	local vcs_regex=".*-(bzr|git|hg|svn)$"

	[[ "$pkg" =~ $vcs_regex ]]
}

function pkg::get_build_version {
	local pkg=$1
	local pkgbuild_dir; pkgbuild_dir="$(db::get_package_pkgbuild_dir "$pkg")"
	local build_path="$GIT_REPO_PATH/$pkg/$pkgbuild_dir"

	# Run makepkg to update the PKGBUILD pkgver for vcs packages
	pkg::is_vcs "$pkg" && ( cd "$build_path" && \
		makepkg --nobuild --clean --cleanbuild --nodeps --noconfirm > /dev/null 2>&1 )

	# Evaluates the PKGBUILD to get the version: It should have been changed by the makepkg above
	# Copied from https://github.com/AladW/aurutils/blob/master/lib/aur-srcver
	#
	# How safe is this, by the way? Well, at the moment we end up sourcing the PKGBUILD, the user has
	# already reviewed and accepted its inclusion on the repository, so there is consent already,
	# since for building, makepkg will source it anyway. If it ever changes, it will be detected on
	# the update process, before VCS update is triggered, so again, consent is given, hence no
	# issues.
	#
	# shellcheck disable=SC2016
	local last; last=$(env -C "$build_path" -i bash -c '
		PATH= source PKGBUILD

		if [ -n "$epoch" ]; then
			fullver=$epoch:$pkgver-$pkgrel
		else
			fullver=$pkgver-$pkgrel
		fi

		echo "$fullver"')

	# Clean all version changes done to the PKGBUILD by makepkg made by vcs packages
	pkg::is_vcs "$pkg" && git::clean_repo "$pkg" > /dev/null 2>&1

	echo "$last"
}
