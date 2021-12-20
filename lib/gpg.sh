# -*- mode: sh; sh-shell: bash -*-
# Common GPG-related functions

function gpg::start {
	# Do nothing if we're using system GPG
	test -n "$USE_SYSTEM_GPG" && return

	# Create the GPG path
	msg "Mounting a temporary GPG home structure"
	export GNUPGHOME; GNUPGHOME="$(gpg::home-path)"
	test -d "$GNUPGHOME" || mkdir "$GNUPGHOME"
	chmod 700 "$GNUPGHOME"

	# Then import saved keys onto it
	local keys_path; keys_path="$(gpg::keys-path)"
	if [ -f "$keys_path" ]; then
		gpg --import "$keys_path" 2> /dev/null
	fi

	# Ensure we don't get pubring.kbx creation stderr messages
	gpg -k > /dev/null 2>&1
}

function gpg::keys-path {
	echo "$GIT_REPO_PATH/gpg-keys.asc"
}

function gpg::home-path {
	echo "$GIT_REPO_PATH/.gnupg"
}

function gpg::cleanup {
	# Do nothing if we're using system gpg
	test -n "$USE_SYSTEM_GPG" && return

	# Save all existing keys onto our git repo
	local keys_path; keys_path="$(gpg::keys-path)"
	if ! gpg --export --armor --output "$keys_path" --batch --yes 2> /dev/null; then
		error "Failure while saving the GPG keys to your pacom git repository."
		msg "Check the output of the command: 'GNUPGHOME=\"$GNUPGHOME\" gpg --export --armor --output \"$keys_path\"'"
	fi

	git::commit_gpg ":arrow_up: update gpg database"
	rm -rf "$GNUPGHOME"
}
