#!/usr/bin/env pmake -f

# Makefile
#
# Static weblog engine

#####
## LICENSE
###

# Quinoa, a static quotation website engine using a BSD Makefile
# Copyright (C) 2012 DOSSMANN Olivier
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

#####

# use make Q= to enable the debug mode.
Q ?= @
# use conf= to change configuration file
conf ?= quinoa.rc
# use mainscript= to change script file
mainscript ?= process.lua
# Quinoa version
VERSION = 0.0

# directories
TMPLDIR          = ./template
BINDIR           = ./bin
LANGDIR          = ./lang
SRCDIR           = ./src
DESTDIR          = ./pub
DBDIR            = ./db
TMPDIR           = ./tmp
DOCDIR           = ./doc
STATICDIR        = ./static
SPECIALDIR       = ./special
BACKUPDIR        = ./mbackup
TOOLSDIR         = ./tools
MAKEFLYDIR       != pwd

# programs
markdown ?= markdown
lua      ?= lua
parser   ?= ${lua} ${BINDIR}/parser.lua
rm       ?= rm
date     ?= date
tar      ?= tar
PUBLISH_SCRIPT_NAME = publish.sh
COMPRESS_TOOL ?= gzip
COMPRESS_EXT = .gz

# include some VARIABLES
# first main variables
.include "${conf}"
PAGE_EXT ?= .html
BLOG_URL ?= http://localhost/~${USER}
# then theme VARIABLES
THEMEDIR = ${TMPLDIR}/${THEME}
theme_config ?= ${THEMEDIR}/config.mk

# some files'list
DOCFILES := ${DOCDIR}/*.md
DOCFILESRESULT != echo ${DOCFILES}

# DIRECTORIES
.for DIR in DESTDIR TMPDIR STATICDIR SPECIALDIR BACKUPDIR DOCDIR INSTALLDIR TMPLDIR
${${DIR}}:
	$Q[ -d "${${DIR}}" ] || { \
		echo "-- Creating ${${DIR}}..." ; \
		mkdir -p "${${DIR}}" || { \
			echo "-- Error while creating ${${DIR}}" >&2 ; \
			false ; \
		}; \
	}
.endfor

# BEGIN
all:
	$QCURDIR="${.OBJDIR}" DBDIR="${DBDIR}" SRCDIR="${SRCDIR}" TMPDIR="${TMPDIR}" TMPLDIR="${TMPLDIR}" STATICDIR="${STATICDIR}" SPECIALDIR="${SPECIALDIR}" LANGDIR="${LANGDIR}" DESTDIR="${DESTDIR}" BLOG_URL=${BLOG_URL} VERSION="${VERSION}" conf="${conf}" ${lua} ${mainscript} || exit 1

# Clean all directories
# EXAMPLE: pub/* AND tmp/*
clean:
	$Q${rm} -rf ${DESTDIR}/ && echo "-- Removed: ${DESTDIR} directory"
	$Q${rm} -rf ${TMPDIR}/ && echo "-- Removed: ${TMPDIR} directory"
	$Q${rm} -f ${DOCDIR}/*${PAGE_EXT} && echo "-- Removed: ${DOCDIR}/*${PAGE_EXT} files"

# Create documentation
.for FILE in ${DOCFILESRESULT}

${FILE:S/.md$/${PAGE_EXT}/}: ${DOCDIR}
	$Q{                                                      \
		cat ${DOCDIR}/header.xhtml > ${FILE:S/.md$/${PAGE_EXT}/} && \
		${markdown} ${FILE} >> ${FILE:S/.md$/${PAGE_EXT}/} && \
		cat ${DOCDIR}/footer.xhtml >> ${FILE:S/.md$/${PAGE_EXT}/} || \
		{                                                    \
			echo "-- Could not build doc file: $@" ;        \
		} ;                                                  \
	} && echo "-- Doc file built: $@"

.endfor

doc: ${DOCFILESRESULT:S/.md$/${PAGE_EXT}/}

# Backup: save important files
TODAY != ${date} '+%Y%m%d'
backup: quinoa.rc ${BACKUPDIR}
	$Q{ \
		${tar} cf - quinoa.rc ${STATICDIR:S/^.\///} ${DBDIR:S/^.\///} ${SRCDIR:S/^.\///} ${SPECIALDIR:S/^.\///} ${THEMEDIR:S/^.\///} | ${COMPRESS_TOOL} > ${BACKUPDIR}/${TODAY}_quinoa.tar${COMPRESS_EXT} || \
		{ \
			echo "-- Backup failed!" ; \
			false ; \
		} ; \
	} && echo "-- Files successfully saved in ${BACKUPDIR}: quinoa.rc, ${STATICDIR}, ${DBDIR}, ${SRCDIR}, ${SPECIALDIR} and ${THEMEDIR}."

# Publish: send files out
publish_script = ${TOOLSDIR}/${PUBLISH_SCRIPT_NAME}
PUBDIR != echo ${DESTDIR:S/^.\//${MAKEFLYDIR}\//}
publish: ${DESTDIR}
	$Q{ \
		cat ${publish_script} |${parser} \
			"DESTDIR=${PUBDIR}" \
			"PUBLISH_DESTINATION=${PUBLISH_DESTINATION}" \
			> ${TMPDIR}/${PUBLISH_SCRIPT_NAME} && \
			chmod +x ${TMPDIR}/${PUBLISH_SCRIPT_NAME} && \
			${TMPDIR}/${PUBLISH_SCRIPT_NAME} && \
			${rm} -f ${TMPDIR}/${PUBLISH_SCRIPT_NAME} || \
		{ \
			${rm} -f ${TMPDIR}/${PUBLISH_SCRIPT_NAME} ; \
			echo "-- Publication failed!" ; \
			false ; \
		} ; \
	} && echo "-- Publish ${DESTDIR} content with ${publish_script}: OK."

# Install: send files to INSTALLDIR variable
install: ${DESTDIR} ${INSTALLDIR}
	$Q{ \
		cat ${TOOLSDIR}/install.sh |${parser} \
		"SRCDIR=${DESTDIR}" \
		"DESTDIR=${INSTALLDIR}" > ${TMPDIR}/install.sh && \
		chmod +x ${TMPDIR}/install.sh && \
		${TMPDIR}/install.sh && \
		${rm} ${TMPDIR}/install.sh || \
		{ \
			${rm} -rf ${TMPDIR}/install.sh && \
			echo "-- Installation failed!" ; \
			false ; \
		} ; \
	} && echo "-- Installation achieved."

# theme: create a new theme
theme: ${TMPLDIR}
.if ! defined(name)
	$Qecho 'No name found. Launch command like this to create a new theme: \n\tpmake theme name="myTheme"' && exit 1
.else
	$Q{ \
		cp -r ${TMPLDIR}/base ${TMPLDIR}/${name} && \
		cat ${TMPLDIR}/${name}/config.mk |sed -e 's#\(CSS_NAME = \).*#\1${name}#g' > ${TMPLDIR}/${name}/config.mk.new && \
		mv ${TMPLDIR}/${name}/config.mk.new ${TMPLDIR}/${name}/config.mk || \
		{ \
			${rm} -rf ${TMPLDIR}/${name} && \
			echo "-- Theme creation for "${name}" failed!" ; \
			false ; \
		} ; \
	} && echo "-- New theme '${name}' created!\nThis theme is available in '${TMPLDIR}/${name}' directory."
.endif

# Create post: simple post creation
# note: create_post.sh -q do not display any editor
# TODO: title="myTitle" tags="myTags" quiet="1" pmake add
createpost: ${DBDIR} ${SRCDIR} ${TMPDIR}
	$Q{ cat ${TOOLSDIR}/create_post.sh |${parser} \
		"DBDIR=${DBDIR}" \
		"SRCDIR=${SRCDIR}" > ${TMPDIR}/create_post.sh && \
		chmod +x ${TMPDIR}/create_post.sh && \
		${TMPDIR}/create_post.sh && \
		${rm} ${TMPDIR}/create_post.sh || \
		{ \
			${rm} -rf ${TMPDIR}/create_post.sh && \
			echo "-- New post failed!" ; \
			false ; \
		} ; \
	} && echo "-- New post added successfully."

add: createpost

version: 
	$Qecho "${VERSION}"

# list: list all available command as a help command
list: 
	$Qecho -e "List of available commands: \n \
		list       list all available commands \n \
		help       same as 'list' command \n \
		clean      clean up current directory from generated files \n \
		all        create all entire weblog \n \
		createpost create a new post \n \
		add        same as 'createpost' \n \
		backup     make a backup from your current quinoa directory \n \
		install    install 'pub' directory into INSTALLDIR directory (set in quinoa.rc) \n \
		publish    publish your weblog using tools/publish.sh script \n \
		theme      copy 'base' theme to create a new one named using 'name' variable \n \
		version    give version of the current program"

help: list

# END
.MAIN: all

# vim:tabstop=2:softtabstop=2:shiftwidth=2:noexpandtab
