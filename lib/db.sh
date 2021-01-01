# -*- mode: sh; sh-shell: bash -*-
# DB layer abstraction

function db::query {
	local sql=$1; shift
	local sqliteargs=("$@")
	local tmpfile; tmpfile="$(mktemp)"

	sqlite3 "${sqliteargs[@]}" "$SQLITE_DB_PATH" "$sql" 2> "$tmpfile"; status=$?

	if [ $status -ne 0 ]; then
		local error_msg; error_msg="$(cat "$tmpfile")"
		error "SQLite: ${error_msg//Error: /}"
	fi

	rm "$tmpfile"
	return $status
}

function db::list_pkgs {
	db::query "select name from packages order by name"
}

function db::package_exists {
	local name=$1
	local count; count="$(db::query "select count(*) from packages where name = '$name'")"
	test $? -eq 0 && test "$count" = "1"
}

function db::get_package_git_url {
	local name=$1
	db::query "select git_url from packages where name = '$name'"
}

function db::get_package_pkgbuild_path {
	local name=$1
	db::query "select pkgbuild_path from packages where name = '$name'"
}

function db::get_package_pkgbuild_dir {
	local name=$1
	dirname "$(db::get_package_pkgbuild_path "$name")"
}

function db::is_repo_cloned {
	local git_url=$1
	local count; count="$(db::query "select count(*) from packages where git_url = '$git_url'")"
	test $? -eq 0 && test "$count" != "0"
}

function db::add_package {
	local name=$1
	local git_url=$2
	local pkgbuild_path=$3

	db::query "insert into packages
		(name, git_url, pkgbuild_path) values
		('$name', '$git_url', '$pkgbuild_path')"
}

function db::remove_package {
	local name=$1
	db::query "delete from packages where name = '$name'"
}

function db::bootstrap {
	db::query "CREATE TABLE packages (
		name TEXT NOT NULL,
		git_url TEXT NOT NULL,
		pkgbuild_path TEXT NOT NULL,
		PRIMARY KEY(name)
	)"
}
