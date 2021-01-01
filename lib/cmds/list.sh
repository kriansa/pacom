# -*- mode: sh; sh-shell: bash -*-
# List packages currently at $GIT_REPO_PATH

pkg-command "list" "List packages currently managed by Pacom"

function cmd::list::help {
	echo "Usage: $0 list"
	echo ""
	echo "List all packages managed by Pacom, along with their built and installed versions."
	echo ""
	echo "Options:"
	echo "  -h, --help      Show this message."
}

function cmd::list {
	db::query "CREATE TABLE IF NOT EXISTS list_metadata (
		name TEXT NOT NULL UNIQUE,
		built_version TEXT NOT NULL,
		installed_version TEXT NOT NULL,
		PRIMARY KEY(name),
		FOREIGN KEY(name) REFERENCES packages (name) ON DELETE CASCADE ON UPDATE CASCADE
	)"

	while read -r pkg_name; do
		local built_version; built_version="$(repo::get_built_package_version "$pkg_name")"
		test -z "$built_version" && built_version="Not built"

		local installed_version; installed_version="$(repo::get_installed_package_version "$pkg_name")"
		test -z "$installed_version" && installed_version="Not installed"

		db::query "INSERT INTO list_metadata (name, built_version, installed_version) VALUES
			('$pkg_name', '$built_version', '$installed_version')"
	done < <(db::list_pkgs)

	db::query "select p.name as Name,
		(case when git_url like '%aur.archlinux.org%' then 'AUR'
			when git_url like '%github.com%' then 'Github (' || substr(substr(git_url, 1, length(git_url) - 4), instr(git_url, 'github.com') + 11) || ')'
			else 'Git (' || git_url || ')' end) as 'Origin',
		built_version as 'Built version', installed_version as 'Installed version'
		from packages p
		left join list_metadata lm on p.name = lm.name
		order by p.name" -header -column

	db::query "DROP TABLE list_metadata"

	# This is to make sure we don't leave the git db dirty
	git::discard_db_changes
}
