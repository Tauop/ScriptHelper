#!/bin/bash
#
# copyright (c) 2010 linagora
# patrick guiran <pguiran@linagora.com>
# http://github.com/tauop/scripthelper
#
# scripthelper is free software, you can redistribute it and/or modify
# it under the terms of the gnu general public license as
# published by the free software foundation; either version 2 of
# the license, or (at your option) any later version.
#
# scripthelper is distributed in the hope that it will be useful,
# but without any warranty; without even the implied warranty of
# merchantability or fitness for a particular purpose.  see the
# gnu general public license for more details.
#
# you should have received a copy of the gnu lesser general public license
# along with this program.  if not, see <http://www.gnu.org/licenses/>.
#

# -f disable pathname expansion.
# -u unset variables
set -fu

# Load library ---------------------------------------------------------------
SCRIPT_HELPER_DIRECTORY='..'
[ -r /etc/ScriptHelper.conf ] && . /etc/ScriptHelper.conf

LOAD() {
  if [ -r "${SCRIPT_HELPER_DIRECTORY}/$1" ]; then
    . "${SCRIPT_HELPER_DIRECTORY}/$1"
  else
    echo "[ERROR] Unable to load $1"
    exit 2
  fi
}


LOAD ./record.lib.sh

var='ls "/tmp"'
RECORD "$var"

echo "======================"
echo "enregistrement terminé"
echo "======================"

sleep 1

RECORD_PLAY

var=$( RECORD_GET_TIME_FILE )
[ -f "${var}" ] && rm -f "${var}"

var=$( RECORD_GET_DATA_FILE )
[ -f "${var}" ] && rm -f "${var}"

echo "*** All Tests finished ***"
