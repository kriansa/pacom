# -*- mode: sh; sh-shell: bash -*-
# Initialize a new repository for usage with Pacom

pkg-command "init" "Initialize a new Git & Pacman repository"

function cmd::init::help {
	echo "Usage: pacom init"
	echo ""
	echo "Initialize a new repository for usage with Pacom."
	echo ""
	echo "By default, it creates a git and a Pacman repository at \$XDG_DATA_HOME/pacom or"
	echo "\$HOME/.local/share/pacom if the XDG variable is not set."
	echo ""
	echo "Also, after pacom has created the Pacman repository, you will need to add it to Pacman's"
	echo "config file at /etc/pacman.conf - You will be asked to do it right after the command is run."
	echo ""
	echo "Options:"
	echo "  -h, --help      Show this message."
}

function cmd::init {
	initialize_git_repo
	echo ""
	initialize_pacman_repo
}

function initialize_git_repo {
	if [ -d "$GIT_REPO_PATH" ]; then
		error "You already have a Git database at '$GIT_REPO_PATH'"
		msg2 "Make sure you are not using it or remove the folder if you want to start from scratch."
		return 1
	fi

	mkdir -p "$GIT_REPO_PATH"
	(
		cd "$GIT_REPO_PATH" || return 1
		git init > /dev/null
		db::bootstrap
		cat <<-EOF > README.md
			# Pacom metadata store

			This repository is a database of current (and previous) installed versions of
			Arch Linux user packages using [Pacom][pacom] package manager.

			---
			[pacom]: https://github.com/kriansa/pacom
		EOF
		git add README.md
		git::commit ":tada: initialize repository"
	)

	msg "Git database initialized successfully!"
	msg2 "You might want to setup a remote to it and it will automatically be synchronized."
}

function initialize_pacman_repo {
	if [ -f "$PACMAN_REPO_PATH" ]; then
		error "You already have a Pacman repository at '$PACMAN_REPO_PATH'"
		msg2 "Make sure you are not using it or remove the folder if you want to start from scratch."
		return 1
	fi

	local repo_dir; repo_dir="$(dirname "$PACMAN_REPO_PATH")"
	mkdir -p "$repo_dir"
	repo-add "$PACMAN_REPO_PATH" > /dev/null 2>&1

	msg "Pacman repository created successfully!"
	msg2 "Now, add the following entry to your /etc/pacman.conf"
	echo ""
	cat <<-EOF
		# Pacom local package repository
		[pacom]
		SigLevel = Optional TrustAll
		Server = file://$repo_dir
	EOF
}
