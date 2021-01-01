# -*- mode: sh; sh-shell: bash -*-
# Functions for helping Pacman repo management

function repo::has_package {
	local pkg=$1
	pacman -Sl "$PACMAN_REPO_NAME" | grep "$PACMAN_REPO_NAME $pkg " > /dev/null 2>&1
}

# Get the current built version of that package on the repo
function repo::get_built_package_version {
	local pkg=$1
	pacman -Sl "$PACMAN_REPO_NAME" | grep "$PACMAN_REPO_NAME $pkg " | awk '{ print $3 }'
}

# Get the current installed version of that package locally
function repo::get_installed_package_version {
	local pkg=$1
	pacman -Q "$pkg" 2> /dev/null | awk '{ print $2 }'
}

function repo::add_package {
	local package_name=$1
	repo-add --remove "$PACMAN_REPO_PATH" "$package_name"
}

# To update the local repo cache, we just run pacman -Sy. The problem by just running that is that
# we also end up updating all repos listed under /etc/pacman.conf, which is not a good thing because
# packages on an external repo might be updated and we might end up needing it further in the
# process.
#
# Ideally, pacman should have a feature built-in so that we could just update a single repo instead
# of everything. While we don't have that, what we'll do here is to pretend that we only have a
# single repo by faking a /etc/pacman.conf file and then running pacman -Sy against them.
function repo::update_pacman_db {
	local tmpfile; tmpfile=$(mktemp)
	local repo_path; repo_path=$(dirname "$PACMAN_REPO_PATH")

	cat <<-EOF > "$tmpfile"
		[options]
		CheckSpace
		[$PACMAN_REPO_NAME]
		SigLevel = Optional TrustAll
		Server = file://$repo_path
	EOF

	sudo pacman --config "$tmpfile" -Sy > /dev/null
	rm "$tmpfile"

	msg "Pacman database updated"
}

# Lists all possible files that would be generated out of a package
function repo::list_pkg_output_files {
	local pkg=$1

	local pkgbuild_dir; pkgbuild_dir="$(db::get_package_pkgbuild_dir "$pkg")"
	local build_path="$GIT_REPO_PATH/$pkg/$pkgbuild_dir"

	( cd "$build_path" && makepkg --packagelist )
}

# Differently than list_pkg_output_files, this function list all existing package files on the
# filesystem, including version variations by globbing the versions, so for instance, for package
# `stress-ng`, this function would be able to pick up the following files (if they exist):
# - stress-ng-0.12.01-1-x86_64.pkg.tar.zst
# - stress-ng-0.12.01-2-x86_64.pkg.tar.zst
function repo::list_existing_pkg_files {
	local pkg=$1

	while read -r pkgfile; do
		local pkgglob; pkgglob="$(echo "$pkgfile" | sed -E "s/(.*)-([^-]+-[^-]+)-([^-]*)$/\1-*-\3/")"
		compgen -G "$pkgglob"
	done < <(repo::list_pkg_output_files "$pkg")
}
