# -*- mode: sh; sh-shell: bash -*-
# Execute a GPG command under Pacom's GNUPGHOME

pkg-command "gpg" "Execute a GPG command under Pacom's GNUPGHOME"

function cmd::gpg::help {
	echo "Usage: pacom gpg <SUBCOMMAND> [ARGS]"
	echo ""
	echo "Execute any gpg command on Pacom's GPG trust database."
	echo ""
	echo "By default, pacom uses a separate GNUPG home location for storing GPG trusted keys for"
	echo "the managed packages. That is generally useful to keep your local GNUPGHOME clean, as well"
	echo "as enabling more independence for pacom by building packages without the need to rely on"
	echo "external databases."
	echo ""
	echo "As a general usage, you will want to run a 'pacom gpg --import <file.asc>' every time a"
	echo "package build fails due to missing PGP keys."
	echo ""
	echo "If you want to disable this behavior and use your own system GNUPGHOME (usually ~/.gnupg)"
	echo "then set the environment variable 'USE_SYSTEM_GPG'"
}

function cmd::gpg {
	gpg::start
	gpg "$@"
	gpg::cleanup
}
