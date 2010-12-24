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

LOAD random.lib.sh
LOAD message.lib.sh
LOAD exec.lib.sh # for SET_LOG_FILE
LOAD mail.lib.sh

TEST_FILE="/tmp/test.$(RANDOM)"
SET_LOG_FILE "${TEST_FILE}"

# Utility functions ----------------------------------------------------------

TEST_FAILED() {
  rm -f "${TEST_FILE}"
  echo '[ERROR] Test failed'
  exit 1
}

check_LOG_FILE() {
  local content=
  if [ -n "${__OUTPUT_LOG_FILE__:-}" ]; then
    # delete the date, at the beginning of each line
    content=`cat "${__OUTPUT_LOG_FILE__:-}" | cut -d ']' -f2- | sed -e 's/^ //' | tr $'\n' ':'`
    content2=`echo "$*" | tr $'\n' ':'`
    [ "${content}" != "${content2}" ] && TEST_FAILED
    reset_LOG_FILES
  fi
}

reset_LOG_FILES() {
  echo -n '' > "${TEST_FILE}"
  [ -f "${__OUTPUT_LOG_FILE__:-}" ] && echo -n '' > "${__OUTPUT_LOG_FILE__:-}"
  [ -f "${__ERROR_LOG_FILE__:-}"  ] && echo -n '' > "${__ERROR_LOG_FILE__:-}"
}


# don't use function.lib.sh functions !
mDOTHIS() { echo -n "- $* ... "; }
mOK()     { echo 'OK';           }


# Make tests -----------------------------------------------------------------

MAIL_FILE="/tmp/mail.lib.test.$(RANDOM)"
MAIL_FILE2="/tmp/mail.lib.test.$(RANDOM)"


# -------------------------------------------------------------
mDOTHIS 'test MAIL_CREATE()'
  res=$( MAIL_CREATE '' )
  [ $? -eq 0 ] && TEST_FAILED
  [ "${res}" = '' ] && TEST_FAILED
  check_LOG_FILE "FATAL: Can't create a mail with empty filename"
  reset_LOG_FILES

  # -------------------------------------------------------------
  MAIL_CREATE "${MAIL_FILE}"
  [ $? -ne 0 ] && TEST_FAILED
  check_LOG_FILE "MAIL_CREATE: ${MAIL_FILE}"
  reset_LOG_FILES

  # -------------------------------------------------------------
  touch ${MAIL_FILE2}; chmod 0000 "${MAIL_FILE2}"
  res=$( MAIL_CREATE "${MAIL_FILE2}" )
  [ $? -eq 0 ] && TEST_FAILED
  [ "${res}" = '' ] && TEST_FAILED
  check_LOG_FILE "FATAL: MAIL_CREATE can't create temp mail file ${MAIL_FILE2}"
  reset_LOG_FILES

  # -------------------------------------------------------------
  MAIL_CREATE
  [ $? -ne 0 ] && TEST_FAILED
  check_LOG_FILE "MAIL_CREATE: $( MAIL_GET_FILE )"
  reset_LOG_FILES
mOK

# -------------------------------------------------------------
mDOTHIS "MAIL_SET_FILE()"
  res=$( MAIL_SET_FILE )
  [ $? -eq 0 ] && TEST_FAILED
  [ "${res}" = '' ] && TEST_FAILED
  check_LOG_FILE "FATAL: MAIL_SET_FILE: Bad argument(s)"
  reset_LOG_FILES

  # -------------------------------------------------------------
  chmod a-w "${MAIL_FILE}"
  res=$( MAIL_SET_FILE "${MAIL_FILE}")
  [ $? -eq 0 ] && TEST_FAILED
  [ "${res}" = '' ] && TEST_FAILED
  check_LOG_FILE "FATAL: MAIL_SET_FILE: ${MAIL_FILE} is not writable"
  reset_LOG_FILES
  chmod a+w "${MAIL_FILE}"
mOK

# -------------------------------------------------------------
mDOTHIS "MAIL_APPEND()"
  rm -f "${MAIL_FILE}" "${MAIL_FILE2}"
  echo "first test line" >> "${MAIL_FILE2}"
  echo "second test line" >> "${MAIL_FILE2}"

  MAIL_CREATE "${MAIL_FILE}"
  reset_LOG_FILES
  MAIL_APPEND "first test line"
  check_LOG_FILE "MAIL_APPEND[${MAIL_FILE}]> first test line"
  reset_LOG_FILES
  MAIL_APPEND "second test line"
  check_LOG_FILE "MAIL_APPEND[${MAIL_FILE}]> second test line"
  reset_LOG_FILES

  res=$( cat "${MAIL_FILE}" | wc -l )
  [ ${res} -ne 2 ] && TEST_FAILED

  diff "${MAIL_FILE}" "${MAIL_FILE2}" >/dev/null
  [ $? -ne 0 ] && TEST_FAILED

  res=$( tail -n 1 < "${MAIL_FILE}" )
  [ "${res}" != 'second test line' ] && TEST_FAILED

  # -------------------------------------------------------------
  rm -f "${MAIL_FILE}"
  MAIL_CREATE "${MAIL_FILE}"
  MAIL_APPEND "${MAIL_FILE}" "first test line"
  MAIL_APPEND "${MAIL_FILE}" "second test line"
  reset_LOG_FILES

  diff "${MAIL_FILE2}" "${MAIL_FILE}" >/dev/null
  [ $? -ne 0 ] && TEST_FAILED

  # -------------------------------------------------------------
  chmod a-w "${MAIL_FILE}"
  res=$( MAIL_APPEND "${MAIL_FILE}" "test failed" )
  [ $? -eq 0 ] && TEST_FAILED
  [ "${res}" = '' ] && TEST_FAILED
  check_LOG_FILE "FATAL: MAIL_APPEND: can't write to mail file"
  reset_LOG_FILES

  # -------------------------------------------------------------
  res=$( MAIL_APPEND )
  [ $? -eq 0 ] && TEST_FAILED
  [ "${res}" = '' ] && TEST_FAILED
  check_LOG_FILE "FATAL: MAIL_APPEND: Bad argument(s)"
  reset_LOG_FILES

  # -------------------------------------------------------------
  __MAIL_FILE__=
  res=$( MAIL_APPEND "test failed" )
  [ $? -eq 0 ] && TEST_FAILED
  [ "${res}" = '' ] && TEST_FAILED
  check_LOG_FILE "FATAL: MAIL_APPEND: no mail file was setup"
  reset_LOG_FILES
mOK

# -------------------------------------------------------------
mDOTHIS "MAIL_PRINT()"
  chmod a+r "${MAIL_FILE}" "${MAIL_FILE2}"
  MAIL_SET_FILE "${MAIL_FILE2}"
  test_file="/tmp/test.$(RANDOM)"
  MAIL_PRINT > ${test_file}
  diff "${test_file}" "${MAIL_FILE}" >/dev/null
  [ $? -ne 0 ] && TEST_FAILED
  rm -f "${test_file}"

  # -------------------------------------------------------------
  res=$( MAIL_PRINT '' )
  [ $? -eq 0 ] && TEST_FAILED
  [ "${res}" = '' ] && TEST_FAILED
  check_LOG_FILE "FATAL: MAIL_PRINT: no mail file was setup"
  reset_LOG_FILES

  # -------------------------------------------------------------

  chmod a-r "${MAIL_FILE}"
  res=$( MAIL_PRINT "${MAIL_FILE}" )
  [ $? -eq 0 ] && TEST_FAILED
  [ "${res}" = '' ] && TEST_FAILED
  check_LOG_FILE "FATAL: MAIL_PRINT: can't read mail file"
  reset_LOG_FILES
mOK

mDOTHIS "MAIL_SEND()"
  res=$( MAIL_SEND "1" "2" "3" "failed" )
  [ $? -eq 0 ] && TEST_FAILED
  [ "${res}" = '' ] && TEST_FAILED
  check_LOG_FILE "FATAL: MAIL_SEND: Bad argument(s)"
  reset_LOG_FILES

  # -------------------------------------------------------------
  __MAIL_FILE__=''
  res=$( MAIL_SEND "mail@mail.com" "failed" )
  [ $? -eq 0 ] && TEST_FAILED
  [ "${res}" = '' ] && TEST_FAILED
  check_LOG_FILE "FATAL: MAIL_SEND: no mail file was setup"
  reset_LOG_FILES
mOK

find /tmp -maxdepth 1 \( -name "test.*" -o -name "mail.*" \) -exec rm -f {} \;

exit 0
