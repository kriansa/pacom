# -*- mode: sh; sh-shell: bash -*-
# Common GPG-related functions

function gpg::start {
	# Do nothing if we're using system GPG or already initialized
	[ -n "$USE_SYSTEM_GPG" ] || [ "$_gpg_initialized" = 1 ] && return

	# Create the GPG path
	msg "Mounting a temporary GPG home structure"
	export GNUPGHOME="$GIT_REPO_PATH/.gnupg"
	# Cleanup if needed
	test -d "$GNUPGHOME" && rm -rf "$GNUPGHOME"
	mkdir "$GNUPGHOME" && chmod 700 "$GNUPGHOME"

	# Then import saved keys onto it
	local keys_path; keys_path="$(gpg::keys_path)"
	if [ -f "$keys_path" ]; then
		gpg --import "$keys_path" 2> /dev/null
	fi

	# Ensure we don't get pubring.kbx creation stderr messages
	gpg -k > /dev/null 2>&1

	# Set a flag that says the GPG infrastructure has been initialized
	# This prevents calls to gpg::sync_db to backup the system keyring instead of Pacom's when it
	# hasn't been initialized yet
	_gpg_initialized=1

	# Make sure we cleanup on exit
	trap gpg::_cleanup EXIT
}

function gpg::sync_db {
	# Do nothing if we're using system gpg (or haven't initialized using gpg::start)
	[ -n "$USE_SYSTEM_GPG" ] || [ "$_gpg_initialized" != 1 ] && return

	# Save all existing keys onto our git repo
	local keys_path; keys_path="$(gpg::keys_path)"
	if ! gpg --export --armor --output "$keys_path" --batch --yes 2> /dev/null; then
		error "Failure while saving the GPG keys to your pacom git repository."
		msg "Check the output of the command: 'GNUPGHOME=\"$GNUPGHOME\" gpg --export --armor --output \"$keys_path\"'"
	fi

	git::commit_gpg ":arrow_up: update gpg database"
}

# Retrieve the path to the gpg keys file on the git repo
function gpg::keys_path {
	echo "$GIT_REPO_PATH/gpg-keys.asc"
}

# Cleanup temporary $GNUPGHOME created by pacom
# This function should not be called manually
function gpg::_cleanup {
	# Do nothing if we're using system gpg or we're not using Pacom's gpg home
	[ -n "$USE_SYSTEM_GPG" ] || [ "$_gpg_initialized" != 1 ] && return

	rm -rf "$GNUPGHOME"
}
