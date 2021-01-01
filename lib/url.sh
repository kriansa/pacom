# -*- mode: sh; sh-shell: bash -*-
# Common URL-related functions

# Checks whether the parameter given by the user is a AUR or a generic Git URL
# If we're not using the absolute URL to the repo, then we assume it's AUR
function url::is_aur {
	local url=$1
	! [[ $url =~ ^(ssh|git|https):// ]]
}

# TODO: This needs to be changed if we decide to support more than Github
function url::get_git_url {
	local url=$1

	# Ignore everything after the hash and bang
	url="${url%%#*}"
	url="${url%%!*}"

	# For AURs, we use AUR API to fetch the repo name, because this package might be a split-package
	# and its parent pkgbase might have a different repo location
	if url::is_aur "$url"; then
		local pkgbase; pkgbase="$(
			curl "https://aur.archlinux.org/rpc/?v=5&type=info&arg[]=$url" 2> /dev/null \
			| jq -r '.results[0].PackageBase // empty'
		)"; status=$?

		if [ $status -ne 0 ]; then
			error "Unable to fetch package from AUR RPC! Please check your connection and try again."
			return 1
		fi

		if [ -z "$pkgbase" ]; then
			error "Package '$url' was not found on AUR."
			return 1
		fi

		url="https://aur.archlinux.org/$pkgbase.git"
	else
		# Adds trailing `.git` if the URL doesn't have one
		if ! [[ $url =~ \.git$ ]]; then
			url="${url}.git"
		fi
	fi

	echo "$url"
}

function url::get_pkgname_hint {
	local url=$1

	# Gets only the string after the exclamation mark
	hint="${url#*!}"

	if [ "$hint" = "$url" ]; then
		echo ""
	else
		echo "$hint"
	fi
}

function url::get_pkgbuild_hint {
	local url=$1

	# Ignore everyting after the bang (as it is the pkgname hint)
	url="${url%!*}"

	if ! [[ $url =~ "#" ]]; then
		echo "PKGBUILD"
	else
		url="${url#*#}"

		# Remove trailing PKGBUILD if present
		if [[ $url =~ PKGBUILD$ ]]; then
			url="${url/%PKGBUILD/}"
		fi

		# Remove both leading and trailing slashes, if present
		url="${url#/}"
		url="${url%/}"

		if [ -z "$url" ]; then
			echo "PKGBUILD"
		else
			echo "$url/PKGBUILD"
		fi
	fi
}
