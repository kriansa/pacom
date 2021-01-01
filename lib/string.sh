# -*- mode: sh; sh-shell: bash -*-
# String library

function str::lower {
	printf '%s\n' "${1,,}"
}
