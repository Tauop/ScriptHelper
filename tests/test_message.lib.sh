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
set -fu

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


TEST_FILE="/tmp/test.${RANDOM}"a
TEST_FILE2="${TEST_FILE}2"


touch "${TEST_FILE}"
if [ ! -w "${TEST_FILE}" ]; then
  echo "[ERROR] can't write to \"${TEST_FILE}\'"
  exit 2
fi

touch "${TEST_FILE2}"
if [ ! -w "${TEST_FILE2}" ]; then
  echo "[ERROR] can't write to \"${TEST_FILE2}\'"
  exit 2
fi

# Utility functions ----------------------------------------------------------

TEST_FAILED() {
  echo
  echo '[ERROR] Test failed'
  echo "param = $*"
  echo
  echo "test file = ${TEST_FILE}"
  exit 1
}

check_TEST_FILE() {
  content=`cat ${TEST_FILE} | hexdump`
  must_have=`echo -n "$*" | hexdump`
  [ "${content}" != "${must_have}" ] && TEST_FAILED "$*"
}

check_LOG_FILE() {
  local content=
  if [ -n "${__OUTPUT_LOG_FILE__:-}" ]; then
    # delete the date, at the beginning of each line
    content=`cat "${__OUTPUT_LOG_FILE__:-}" | cut -d ']' -f2- | sed -e 's/^ //'`
    [ "${content}" != "$*" ] && TEST_FAILED "$*"
  fi
}

check_ERROR_FILE() {
  local content=
  if [ -n "${__ERROR_LOG_FILE__:-}" ]; then
    # delete the date, at the beginning of each line
    content=`cat "${__ERROR_LOG_FILE__:-}" | cut -d ']' -f2- | sed -e 's/^ //'`
    [ "${content}" != "$*" ] && TEST_FAILED "$*"
  fi
}

reset_LOG_FILES() {
  [ -f "${__OUTPUT_LOG_FILE__:-}" ] && echo -n '' > "${__OUTPUT_LOG_FILE__}"
  [ -f "${__ERROR_LOG_FILE__:-}"  ] && echo -n '' > "${__ERROR_LOG_FILE__}"
}

# don't use function.lib.sh functions !
mDOTHIS() { echo -n "- $* ... "; reset_LOG_FILES; }
mOK()     { echo 'OK';           reset_LOG_FILES; }

# Make tests -----------------------------------------------------------------
# 1/ test MESSAGE() without setting up logs files

mDOTHIS "MESSAGE() without logs files"

  MESSAGE "hello" > "${TEST_FILE}"
  check_TEST_FILE $'hello\n'


  MESSAGE --no-break "hello world" > "${TEST_FILE}"
  check_TEST_FILE 'hello world'
  # check that there is no breakline in TEST_FILE
#  content=`cat -e "${TEST_FILE}"`
#  [ "${content}" != "hello world" ] && TEST_FAILED

  MESSAGE --no-print "hello world" > "${TEST_FILE}"
  check_TEST_FILE ''

  MESSAGE --useless-option "with useless option" > "${TEST_FILE}"
  check_TEST_FILE $'with useless option\n'

  MSG "tosca's installation ?" > "${TEST_FILE}"
  check_TEST_FILE $'tosca\'s installation ?\n'

mOK

if [ -r ../exec.lib.sh ]; then
  . ../exec.lib.sh
else
  echo "[ERROR] Unable to load exec.lib.sh"
  exit 1
fi

# 2/ test SET_LOG_FILE() -----------------------------------------------------
mDOTHIS "SET_LOG_FILE()"

  SET_LOG_FILE "/tmp/set_log_file"
  [ ! -f "/tmp/set_log_file.output" ] && TEST_FAILED
  [ ! -f "/tmp/set_log_file.error"  ] && TEST_FAILED

mOK

# 3/ test MESSAGE() with setting up logs files -------------------------------
mDOTHIS "MESSAGE() with logs files"

  MESSAGE "hello world" > "${TEST_FILE}"
  check_TEST_FILE $'hello world\n'
  check_LOG_FILE "hello world"
  reset_LOG_FILES

  MESSAGE --no-log "hello world" > "${TEST_FILE}"
  check_TEST_FILE $'hello world\n'
  check_LOG_FILE ''
  reset_LOG_FILES

  MESSAGE --no-print "hello no print" > "${TEST_FILE}"
  check_TEST_FILE ''
  check_LOG_FILE 'hello no print'
  reset_LOG_FILES

  MESSAGE --no-date "hello world" > "${TEST_FILE}"
  check_TEST_FILE $'hello world\n'
  check_LOG_FILE "hello world"
  # check there is no date
  content=`cat "${__OUTPUT_LOG_FILE__}"`
  [ "${content}" != "hello world" ] && TEST_FAILED
  reset_LOG_FILES

  MESSAGE "tosca's installation ?" > "${TEST_FILE}"
  check_TEST_FILE $'tosca\'s installation ?\n'
  check_LOG_FILE "tosca's installation ?"
  reset_LOG_FILES

mOK

mDOTHIS "MESSAGE() alias functions"

  echo -n '' > "${TEST_FILE}"
  LOG "foin foin"
  check_TEST_FILE ''
  check_LOG_FILE "foin foin"
  reset_LOG_FILES

  MSG "tosca's installation ?" > "${TEST_FILE}"
  check_TEST_FILE $'tosca\'s installation ?\n'
  check_LOG_FILE "tosca's installation ?"
  reset_LOG_FILES

  MSG --no-print "does it print ?" > "${TEST_FILE}"
  check_TEST_FILE ''
  check_LOG_FILE "does it print ?"
  reset_LOG_FILES

  MESSAGE --no-log "hello world" > "${TEST_FILE}"
  check_TEST_FILE $'hello world\n'
  check_LOG_FILE ''
  reset_LOG_FILES

  BR > "${TEST_FILE}"
  BR >> "${TEST_FILE}"
  check_TEST_FILE $'\n\n'
  check_LOG_FILE ''
  reset_LOG_FILES

  NOTICE "test" > "${TEST_FILE}"
  check_TEST_FILE $'NOTICE: test\n'
  check_LOG_FILE 'NOTICE: test'
  reset_LOG_FILES

  DOTHIS "A test" >  "${TEST_FILE}"
  OK              >> "${TEST_FILE}"
  check_TEST_FILE $'- A test ... OK\n'
  check_LOG_FILE '- A test ... OK'
  reset_LOG_FILES

  MSG 'this test'   >  "${TEST_FILE}"
  MSG_INDENT_INC
  MSG 'is made'     >> "${TEST_FILE}"
  MSG_INDENT_INC
  MSG 'to test'     >> "${TEST_FILE}"
  MSG_INDENT_DEC
  MSG 'indentation' >> "${TEST_FILE}"
  MSG_INDENT_DEC
  MSG 'nice ;)'     >> "${TEST_FILE}"
  check_TEST_FILE $'this test\n  is made\n    to test\n  indentation\nnice ;)\n'
  check_LOG_FILE  $'this test\n  is made\n    to test\n  indentation\nnice ;)'
  reset_LOG_FILES

  MSG 'an other test'    >  "${TEST_FILE}"
  MSG_INDENT_INC
  MSG 'with indent'      >> "${TEST_FILE}"
  MSG --no-indent 'oups' >> "${TEST_FILE}"
  MSG_INDENT_INC
  ERROR 'test an error'  >> "${TEST_FILE}"
  MSG_INDENT_DEC
  NOTICE 'huhu'          >> "${TEST_FILE}"
  WARNING 'attention :p' >> "${TEST_FILE}"
  MSG_INDENT_DEC
  MSG 'the end !'        >> "${TEST_FILE}"
  check_TEST_FILE $'an other test\n  with indent\noups\n    ERROR: test an error\n  NOTICE: huhu\n  WARNING: attention :p\nthe end !\n'
  check_LOG_FILE $'an other test\n  with indent\noups\n    ERROR: test an error\n  NOTICE: huhu\n  WARNING: attention :p\nthe end !'
  reset_LOG_FILES

mOK

find /tmp -maxdepth 1 \( -name "test.*" -o -name "set_log_file.*" \) -exec rm -f {} \;
echo
echo "*** All Tests OK ***"
