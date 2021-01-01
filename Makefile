.PHONY =: clean compile
.DEFAULT_GOAL := compile

# Temporary paths for building the artifacts
build_dir=build

# Dynamic version text
version       =$(shell cat VERSION)

# Header text
SHEBANG       =\#!/usr/bin/env bash
BANNER_SEP    =$(shell printf '%*s' 70 | tr ' ' '\#')
BANNER_TEXT   =This file was autogenerated by \`make\`. Do not edit it directly!
BANNER        =${BANNER_SEP}\n\# ${BANNER_TEXT}\n${BANNER_SEP}\n
HEADER_TEXT   =${SHEBANG}\n${BANNER}\n

# Libraries we will built into the output binary
LIBS_GLOB ?= lib/*.sh lib/**/*.sh

clean:
	@rm -rf ${build_dir}

$(build_dir):
	@mkdir ${build_dir}

$(build_dir)/pacom: ${build_dir}
	@echo Building Pacom...
	@for file in ${LIBS_GLOB} ; do \
		echo "---> $${file}"; \
		cat "$${file}" >> "${build_dir}/libs.sh" ; \
	done

	@echo "---> bin/pacom"
	@cp bin/pacom ${build_dir}/pacom.tpl
	@perl -i -0p \
		-e 's@# Load all required libs.*# /Load all required libs@<-- INSERT LIBS HERE  -->@gms;' \
		-e 's/VERSION=.*/VERSION="${version}"/;' \
		${build_dir}/pacom.tpl

	@printf "${HEADER_TEXT}" > "${build_dir}/pacom"
	@awk '/<-- INSERT LIBS HERE  -->/ { system ( "cat ${build_dir}/libs.sh" ) } \
     !/<-- INSERT LIBS HERE  -->/ { print; }' "${build_dir}/pacom.tpl" >> "${build_dir}/pacom"
	@chmod +x ${build_dir}/pacom
	@echo Done

compile: ${build_dir}/pacom

# This task uses my own release helper, available here:
# https://github.com/kriansa/dotfiles/blob/master/plugins/git/bin/git-release
release: ${build_dir}/pacom
	git release ${version} --sign --use-version-file --artifact="${build_dir}/pacom"
