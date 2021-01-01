# -*- mode: sh; sh-shell: bash -*-
# This is a small CLI-lib that allows us to quickly build monolithic command line tools by adding
# subcommands to it. It works by creating a "command" which is basically a bash function and then
# registering it using `pkg-command` function. See examples at the `cmds` folder.

declare commands command_descs

# Add a command to the application
#
# Arguments
#   1 - The command string (such as `add`)
#   2 - The description of that command (content that will be displayed at the help page)
function pkg-command {
	local command=$1
	local description=$2

	commands+=("$command")
	command_descs+=("$description")
}

# Checks whether a given command has been previouslyu registered or not
#
# Arguments
#   1 - The command string (such as `add`)
function command-exists {
	local command=$1

	for e in "${commands[@]}"; do
		test "$e" = "$command" && return 0
	done

	return 1
}

# Prints all commands and their specific descriptions, tipically used for displaying help texts
function list-commands-descriptions {
	for i in "${!commands[@]}"; do
		printf "  %- 15s %s\n" "${commands[$i]}" "${command_descs[$i]}"
	done
}

# Checks whether the specified flag is a help option (--help or -h). Returns 0 in case it matches.
#
# Arguments
#   1 - The value you want to check against
function is-help-flag {
	local value=$1

	test "$value" = "--help" || test "$value" = "-h"
}

# Checks whether the specified flag is a version option (--version or -v). Returns 0 in case it
# matches.
#
# Arguments
#   1 - The value you want to check against
function is-version-flag {
	local value=$1

	test "$value" = "--version" || test "$value" = "-v"
}

# Prints out the specified command help content
#
# Arguments
#   1 - The command string (such as `add`)
function exec-command-help {
	local command=$1

	"cmd::$command::help"
}

# Runs the specified command (runs the entry point function for it)
#
# Arguments
#   1 - The command string (such as `add`)
function exec-command {
	local command=$1; shift

	# Anti-sudo protection
	if [ "$EUID" -eq 0 ]; then
		error "Don't run this command as root!"
		exit 1
	fi

	"cmd::$command" "$@"
}
