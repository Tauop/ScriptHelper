#!/bin/bash
#
# Copyright (c) 2010 Linagora
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

# Load library ---------------------------------------------------------------

if [ -r ../functions.lib.sh ]; then
  source ../functions.lib.sh
else
  echo "[ERROR] Unable to load function.lib.sh"
  exit 1
fi


TEST_FILE="/tmp/test.${RANDOM}"a
TEST_FILE2="${TEST_FILE}2"


touch "${TEST_FILE}"
if [ ! -w "${TEST_FILE}" ]; then
  echo "[ERROR] can't write to \"${TEST_FILE}\""
  exit 2
fi

touch "${TEST_FILE2}"
if [ ! -w "${TEST_FILE2}" ]; then
  echo "[ERROR] can't write to \"${TEST_FILE2}\""
  exit 2
fi

# Utility functions ----------------------------------------------------------

TEST_FAILED() {
  echo '[ERROR] Test failed'
  exit 1
}

check_TEST_FILE() {
  content=`cat ${TEST_FILE}`
  [ "${content}" != "$*" ] && TEST_FAILED
}

check_LOG_FILE() {
  local content=
  if [ -n "${__OUTPUT_LOG_FILE__}" ]; then
    # delete the date, at the beginning of each line
    content=`cat "${__OUTPUT_LOG_FILE__}" | cut -d ']' -f2- | sed -e 's/^ //'`
    [ "${content}" != "$*" ] && TEST_FAILED
  fi
}

check_ERROR_FILE() {
  local content=
  if [ -n "${__ERROR_LOG_FILE__}" ]; then
    # delete the date, at the beginning of each line
    content=`cat "${__ERROR_LOG_FILE__}" | cut -d ']' -f2- | sed -e 's/^ //'`
    [ "${content}" != "$*" ] && TEST_FAILED
  fi
}

reset_LOG_FILES() {
  [ -f "${__OUTPUT_LOG_FILE__}" ] && echo -n '' > "${__OUTPUT_LOG_FILE__}"
  [ -f "${__ERROR_LOG_FILE__}"  ] && echo -n '' > "${__ERROR_LOG_FILE__}"
}

mDOTHIS() { DOTHIS "$*"; reset_LOG_FILES; }
mOK() { OK; reset_LOG_FILES; }

# Make tests -----------------------------------------------------------------
# 1/ test MESSAGE() without setting up logs files

mDOTHIS "MESSAGE() without logs files"

  MESSAGE "hello" > "${TEST_FILE}"
  check_TEST_FILE "hello"

  MESSAGE --no-break "hello world" > "${TEST_FILE}"
  check_TEST_FILE "hello world"
  # check that there is no breakline in TEST_FILE
  content=`cat -e "${TEST_FILE}"`
  [ "${content}" != "hello world" ] && TEST_FAILED

  MESSAGE --no-print "hello world" > "${TEST_FILE}"
  check_TEST_FILE ""

  MESSAGE --useless-option "with useless option" > "${TEST_FILE}"
  check_TEST_FILE "with useless option"

  MSG "tosca's installation ?" > "${TEST_FILE}"
  check_TEST_FILE "tosca's installation ?"

mOK

# 2/ test SET_LOG_FILE() -----------------------------------------------------
mDOTHIS "SET_LOG_FILE()"

  SET_LOG_FILE "/tmp/set_log_file"
  [ ! -f "/tmp/set_log_file.output" ] && TEST_FAILED
  [ ! -f "/tmp/set_log_file.error"  ] && TEST_FAILED

mOK

# 3/ test MESSAGE() with setting up logs files -------------------------------
mDOTHIS "MESSAGE() with logs files"

  MESSAGE "hello world" > "${TEST_FILE}"
  check_TEST_FILE "hello world"
  check_LOG_FILE "hello world"
  reset_LOG_FILES

  MESSAGE --no-log "hello world" > "${TEST_FILE}"
  check_TEST_FILE "hello world"
  check_LOG_FILE ""
  reset_LOG_FILES

  MESSAGE --no-date "hello world" > "${TEST_FILE}"
  check_TEST_FILE "hello world"
  check_LOG_FILE "hello world"
  # check there is no date
  content=`cat "${__OUTPUT_LOG_FILE__}"`
  [ "${content}" != "hello world" ] && TEST_FAILED
  reset_LOG_FILES

  MESSAGE "tosca's installation ?" > "${TEST_FILE}"
  check_TEST_FILE "tosca's installation ?"
  check_LOG_FILE "tosca's installation ?"
  reset_LOG_FILES

mOK

# 4/ test SOURCE() -----------------------------------------------------------
mDOTHIS "SOURCE()"

  cat > "${TEST_FILE}" <<EOF
TOTO=3
EOF

  SOURCE "${TEST_FILE}"
  [ "${TOTO}" != "3" ] && TEST_FAILED

  ret=`SOURCE "${TEST_FILE}${RANDOM}"`
  # $ret must contain error messages
  [ "${ret}" = "" ] && TEST_FAILED
  reset_LOG_FILES

  # remove all privilege on TEST_FILE. source must failed
  chmod -rwx "${TEST_FILE}" >/dev/null 2>/dev/null
  ret=`SOURCE "${TEST_FILE}"`
  # $ret must contain error messages
  [ "${ret}" = "" ] && TEST_FAILED
  # restore mode on TEST_FILE and delete it ;)
  chmod +rwx "${TEST_FILE}" >/dev/null 2>/dev/null;
  rm -f "${TEST_FILE}" >/dev/null 2>/dev/null
  reset_LOG_FILES

mOK

# 4/ test EXEC() and CMD() commands ------------------------------------------
mDOTHIS "EXEC() and CMD()"

  EXEC ls > "${TEST_FILE}"
  ls > "${TEST_FILE2}"
  res=`diff "${TEST_FILE}" "${TEST_FILE2}"`
  [ "${res}" != "" ] && TEST_FAILED

  EXEC --with-log ls -la ~
  ls -la ~ > "${TEST_FILE}"
  res=`diff "${TEST_FILE}" "${__OUTPUT_LOG_FILE__}"`
  [ "${res}" != "" ] && TEST_FAILED
  reset_LOG_FILES

  EXEC_WITH_LOG ls -A ~
  ls -A ~ > "${TEST_FILE}"
  res=`diff "${TEST_FILE}" "${__OUTPUT_LOG_FILE__}"`
  [ "${res}" != "" ] && TEST_FAILED
  reset_LOG_FILES

  ret=`EXEC false`
  # no error, because no --with-check
  [ "$ret" != "" ] && TEST_FAILED
  reset_LOG_FILES

  ret=`EXEC --with-check false`
  [ "$ret" = "" ] && TEST_FAILED
  reset_LOG_FILES

  ret=`EXEC_WITH_CHECK false`
  [ "$ret" = "" ] && TEST_FAILED
  reset_LOG_FILES

  EXEC --with-log echo "hello world" ">&2"
  content=`cat "${__ERROR_LOG_FILE__}"`
  [ "${content}" != "hello world" ] && TEST_FAILED
  reset_LOG_FILES

  CMD ls
  ls > "${TEST_FILE}"
  content=`cat "${__OUTPUT_LOG_FILE__}"`
  content2=`cat "${TEST_FILE}"`
  [ "${content}" != "${content2}" ] && TEST_FAILED
  reset_LOG_FILES

mOK

# 5/ test CHECK_ROOT() -------------------------------------------------------
mDOTHIS "CHECK_ROOT()"

  ret=`CHECK_ROOT`
  [ "${ret}" = "" ] && TEST_FAILED
  reset_LOG_FILES

mOK

# 6/ test ROLLBACK() ---------------------------------------------------------
mDOTHIS "ROLLBACK()"

  # define a ROLLBACK function. if it's called, TOTO will be egual to 5
  touch "${TEST_FILE}" "${TEST_FILE2}"
  ROLLBACK() { rm -f "${TEST_FILE}" "${TEST_FILE2}"; }

  ret=`CMD false`
  [ "${ret}" = "" ] && TEST_FAILED
  [ -f "${TEST_FILE}" -o -f "${TEST_FILE}" ] && TEST_FAILED

mOK

exit 0
