# -*- mode: sh; sh-shell: bash -*-
# Common Git-related functions

# Get a PKGBUILD variable without parsing it. No support for creative ways to dynamically set the
# pkgname, as we extract them using regex
# It is smart enough to recognize comments and similar variable names (e.g. _pkgname vs pkgname)
function git::get_pkgbuild_variable {
	local pkgbuild_content; pkgbuild_content=$1
	local variable_name=$2
	echo "$pkgbuild_content" | sed 's/#.*//' | grep -E "\b$variable_name\b=.*" | grep -Po "(?<=$variable_name=)(.*)"
}

# TODO: This needs to be changed if we decide to support more than Github
function git::get_pkgbuild {
	local git_url=$1
	local pkgbuild_path=$2

	if [[ $git_url =~ aur\.archlinux\.org/.+\.git ]]; then
		local repo_name; repo_name=$(echo "$git_url" | sed -E 's#(https|ssh|git)?://##' | \
			grep -oP '(?<=aur\.archlinux\.org/).*(?=\.git)')

		curl --fail "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=$repo_name" 2> /dev/null
		status=$?

		if [ $status -ne 0 ]; then
			error "Unable to fetch PKGBUILD from AUR!"
			return 1
		fi

	elif [[ $git_url =~ github\.com/.+\.git ]]; then
		local repo_name; repo_name=$(echo "$git_url" | sed -E 's#(https|ssh|git)?://##' | \
			grep -oP '(?<=github\.com/).*(?=\.git)')

		curl --fail "https://raw.githubusercontent.com/$repo_name/master/$pkgbuild_path" 2> /dev/null
		status=$?

		if [ $status -ne 0 ]; then
			error "Unable to fetch PKGBUILD from Github!"
			return 1
		fi

	else
		error "We don't know how to fetch PKGBUILD from this URL!"
		return 1
	fi
}

function git::cloned_repo_revision {
	local pkg_name=$1
	( cd "$GIT_REPO_PATH" && git submodule status "$pkg_name" | awk '{ print $1 }' )
}

function git::add_submodule {
	local git_url=$1
	local pkg_name=$2

	( cd "$GIT_REPO_PATH" && git submodule add "$git_url" "$pkg_name" ) > /dev/null
}

function git::remove_submodule {
	local pkg_name=$1

	(
		cd "$GIT_REPO_PATH" || return 1

		# Remove from local & from git -- although not strictly necessary, return statement is here to
		# make explicit that we rely upon the return code of this call to decide whether this entire
		# command succeded or failed

		# First we remove the git submodule completely
		git submodule deinit -f "$pkg_name" || return 1
		rm -rf ".git/modules/$pkg_name" || return 1

		# Then we remove it from the working tree. We first make sure to set the flags w+x to all
		# files/folders before we attempt to remove, otherwise it can fail to remove read-only entries.
		chmod +x+w -R "$pkg_name"
		git rm -rf "$pkg_name" || return 1
	) > /dev/null
}

function git::commit {
	local message=$1

	( cd "$GIT_REPO_PATH" && git add pacom.db && git commit -m "$message" \
		&& git remote | xargs -I R git push R HEAD ) > /dev/null
}

function git::has_updates_for_package {
	local pkg_name=$1
	local pkg_path="$GIT_REPO_PATH/$pkg_name"
	local pkgbuild_dir; pkgbuild_dir="$(db::get_package_pkgbuild_dir "$pkg_name")"

	( cd "$pkg_path" && git fetch origin && \
		git reset --hard HEAD && git checkout HEAD && \
		! git diff --quiet HEAD..origin/HEAD -- "$pkgbuild_dir" ) > /dev/null
}

function git::diff_remote_package {
	local pkg_name=$1
	local pkg_path="$GIT_REPO_PATH/$pkg_name"
	local pkgbuild_dir; pkgbuild_dir="$(db::get_package_pkgbuild_dir "$pkg_name")"

	( cd "$pkg_path" && git diff HEAD..origin/HEAD -- "$pkgbuild_dir" )
}

function git::update_repo {
	local pkg_name=$1
	local pkg_path="$GIT_REPO_PATH/$pkg_name"

	( cd "$pkg_path" && git merge origin/HEAD ) > /dev/null
	( cd "$GIT_REPO_PATH" && git add "$pkg_name" ) > /dev/null
}

# Restore a git module to its HEAD and remove any untracked content
function git::clean_repo {
	local pkg_name=$1
	local pkg_path="$GIT_REPO_PATH/$pkg_name"

	msg2 "Cleaning up git repo of $pkg_name..."
	( cd "$pkg_path" && git reset --hard HEAD && git clean -ffd ) > /dev/null
}

function git::discard_db_changes {
	( cd "$GIT_REPO_PATH" && git restore pacom.db )
}
