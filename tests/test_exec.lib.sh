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

# Load library ---------------------------------------------------------------
if [ -r ../exec.lib.sh ]; then
  . ../exec.lib.sh
else
  echo "[ERROR] Unable to load exec.lib.sh"
  exit 1
fi

TEST_FILE="/tmp/test.${RANDOM}"
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
  if [ -n "${__OUTPUT_LOG_FILE__}" ]; then
    # delete the date, at the beginning of each line
    content=`cat "${__OUTPUT_LOG_FILE__}" | cut -d ']' -f2- | sed -e 's/^ //'`
    [ "${content}" != "$*" ] && TEST_FAILED "$*"
  fi
}

check_ERROR_FILE() {
  local content=
  if [ -n "${__ERROR_LOG_FILE__}" ]; then
    # delete the date, at the beginning of each line
    content=`cat "${__ERROR_LOG_FILE__}" | cut -d ']' -f2- | sed -e 's/^ //'`
    [ "${content}" != "$*" ] && TEST_FAILED "$*"
  fi
}

reset_LOG_FILES() {
  [ -f "${__OUTPUT_LOG_FILE__}" ] && echo -n '' > "${__OUTPUT_LOG_FILE__}"
  [ -f "${__ERROR_LOG_FILE__}"  ] && echo -n '' > "${__ERROR_LOG_FILE__}"
}

# don't use function.lib.sh functions !
mDOTHIS() { echo -n "- $* ... "; reset_LOG_FILES; }
mOK()     { echo 'OK';           reset_LOG_FILES; }



# Make tests -----------------------------------------------------------------
mDOTHIS "SET_LOG_FILE()"

  SET_LOG_FILE "/tmp/set_log_file"
  [ ! -f "/tmp/set_log_file.output" ] && TEST_FAILED
  [ ! -f "/tmp/set_log_file.error"  ] && TEST_FAILED

mOK

mDOTHIS "EXEC() and CMD()"

  EXEC ls > "${TEST_FILE}"
  ls > "${TEST_FILE2}"
  res=`diff "${TEST_FILE}" "${TEST_FILE2}"`
  [ "${res}" != '' ] && TEST_FAILED

  EXEC --with-log ls -la ~
  ls -la ~ > "${TEST_FILE}"
  res=`diff "${TEST_FILE}" "${__OUTPUT_LOG_FILE__}"`
  [ "${res}" != '' ] && TEST_FAILED
  reset_LOG_FILES

  EXEC_WITH_LOG ls -A ~
  ls -A ~ > "${TEST_FILE}"
  res=`diff "${TEST_FILE}" "${__OUTPUT_LOG_FILE__}"`
  [ "${res}" != '' ] && TEST_FAILED
  reset_LOG_FILES

  ret=`EXEC false`
  # no error, because no --with-check
  [ "$ret" != '' ] && TEST_FAILED
  reset_LOG_FILES

  ret=`EXEC --with-check false`
  [ "$ret" = '' ] && TEST_FAILED
  reset_LOG_FILES

  ret=`EXEC_WITH_CHECK false`
  [ "$ret" = '' ] && TEST_FAILED
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
  [ "${ret}" = '' ] && TEST_FAILED
  reset_LOG_FILES

mOK

# 6/ test ROLLBACK() ---------------------------------------------------------
mDOTHIS "ROLLBACK()"

  # use real ROLLBACK function !
  if [ -r ../message.lib.sh ]; then
    . ../message.lib.sh
  else
    echo "[ERROR] Unable to load message.lib.sh"
    exit 1
  fi

  # define a ROLLBACK function. if it's called, TOTO will be egual to 5
  touch "${TEST_FILE}" "${TEST_FILE2}"
  ROLLBACK() { rm -f "${TEST_FILE}" "${TEST_FILE2}"; }

  ret=`CMD false`
  [ "${ret}" = '' ] && TEST_FAILED
  [ -f "${TEST_FILE}" -o -f "${TEST_FILE}" ] && TEST_FAILED

mOK

echo
echo "*** All Tests OK ***"
