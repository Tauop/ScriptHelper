#!/bin/bash
#
# Copyright (c) 2010 Linagora
# Patrick Guiran <pguiran@linagora.com>
# http://github.com/Tauop/ScriptHelper
#
# ScriptHelper is free software, you can redistribute it and/or modify
# it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
#
# ScriptHelper is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# -f Disable pathname expansion.
# -u Unset variables
set -u

# Load library ---------------------------------------------------------------
LOAD() {
  if [ -r ../$1 ]; then
    . ../$1
  else
    echo "[ERROR] Unable to load $1"
    exit 1
  fi
}

LOAD message.lib.sh
LOAD mail.lib.sh

# Utility functions ----------------------------------------------------------

TEST_FAILED() {
  echo
  echo '[ERROR] Test failed'
  echo -e "$*"
  exit 1
}

# don't use function.lib.sh functions !
mDOTHIS() { echo -n "- $* ... "; }
mOK()     { echo 'OK';           }

reset_MAIL_CREATE() {
  rm -f /tmp/test_mail_lib_* \
    || TEST_FAILED 'reset_MAIL_CREATE cannot remove test files'
}

check_MAIL_CREATE() {
  parent_path="$1"
  counter="find -H '$parent_path' -maxdepth 1 -name test_mail_lib_* | wc -l"
  count_before=$( eval $counter )
  MAIL_CREATE "$parent_path/test_mail_lib_%"
  count_after=$( eval $counter )

  [ $count_after -gt $count_before ] \
    || TEST_FAILED "MAIL_CREATE cannot create mail file"
}

check_MAIL_APPEND() {
  lines_before=$( cat ${__MAIL_FILE__} | wc -l )
  MAIL_APPEND "$@"
  lines_after=$( cat ${__MAIL_FILE__} | wc -l )
  (( $lines_after - $lines_before == $# )) \
    || TEST_FAILED "MAIL_APPEND failed with" $*
}

check_MAIL_PRINT() {
  model="$1"
  diff=$( diff <(MAIL_PRINT) <(echo -e $model) )
  [ -z "$diff" ] || TEST_FAILED "MAIL_PRINT didn't output what was expected\n$diff"
}

check_MAIL_SEND() {
  echo -n "TODO "
}

# Make tests -----------------------------------------------------------------

parent_path='/tmp'

reset_MAIL_CREATE

mDOTHIS "MAIL_CREATE()"
  check_MAIL_CREATE $parent_path
mOK

mDOTHIS "MAIL_APPEND()"
  check_MAIL_APPEND "first test line"
  check_MAIL_APPEND "second test line" "with another line"
mOK

mDOTHIS "MAIL_PRINT()"
  check_MAIL_PRINT "first test line\nsecond test line\nwith another line"
mOK

mDOTHIS "MAIL_SEND()"
  check_MAIL_SEND "subject of mail" "address@ofthe.mail"
mOK

reset_MAIL_CREATE
