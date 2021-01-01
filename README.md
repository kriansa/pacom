# :package: pacom - Pacman companion

This is a very small AUR/non-central package manager for Arch Linux. This has very limited feature
set, but most importantly it does _locking_, so I can not only lock packages to specific versions
but later I can distribute that configuration and preferences with my Arch cluster, so they won't
need to manually approve packages on each node.

## Features

Pacom philosophy is to be a simple program, very close to what one would do if they didn't have a
AUR helper installed (`git pull && makepkg`).

It is meant to be a separate program, and not a "all-in-one" that wraps Pacman commands. It targets
the more advanced users that understand and will benefit from the two applications individually.

Moreover, it does not aim to be a frontend for AUR either - for that you have very mature tools such
as the [aur web][aur-web] or [aurutils][aurutils].

* Support for packages not listed on AUR, such as PKGBUILDs found on Github
* Package version locking*
* Uses a separate Pacman repository
* The removal actually delete packages from the Pacman repo
* Support for split-packages

### Package version locking?

When you add a package on `pacom` database - which is essentially a git repository - what it
actually does is clone that package into its git central "database" as a [git
submodule][git-submodule]. This repository can be synced with a remote and you are able to share
that package version metadata with other Arch boxes that you own and make your life easier -- you
won't need to manually approve that package version on all your boxes.

This mechanism also allows you to easily rebuild your entire system without being disrupted by the
package manager asking you to approve that PKGBUILD.

### Other hidden features

* No untrusted PKGBUILD sourcing
* Modular and well-documented codebase - easy to maintain and collaborate
* Use the power of Git and SQLite as databases and does not reinvent the wheel
* Well-documented interface: just type `pacom [<subcommand>] --help` when in doubt :memo:
* Shipped as a single-file: if you want, you can just download the binary and include it on your
  dotfiles.

## Dependencies

1. A local Pacman repository
2. A git repository for tracking and package version locking

## Setup

1. Install [`pacom`][pacom-aur] from AUR -- you can do it manually now, but don't worry, as soon as
   you install it then you can manage its installation within it (inception?)
2. Create the git and pacman repositories by running `pacom init`
3. Make sure you follow the steps described by the output of that command
4. _Optionally_, you can setup a remote for tracking changes in your git-db

## Releasing

1. Bump the `VERSION` file
2. `make`
3. A single binary is created at the `build` dir
4. Ship it as you like -- or update the [PKGBUILD][pacom-aur].

## License

The contents of this repository is licensed under the [Apache v2 License](LICENSE).

---
[aur-web]: https://aur.archlinux.org/
[aurutils]: https://github.com/AladW/aurutils
[git-submodule]: https://git-scm.com/book/en/v2/Git-Tools-Submodules
[pacom-aur]: https://aur.archlinux.org/packages/pacom/
