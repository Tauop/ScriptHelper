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

LOAD random.lib.sh
LOAD message.lib.sh
LOAD exec.lib.sh
LOAD ask.lib.sh
LOAD conf.lib.sh

# Utility functions ----------------------------------------------------------
TEST_FILE="/tmp/test.$(RANDOM)"
SET_LOG_FILE "${TEST_FILE}"

TEST_ANSWER_FILE="/tmp/test_answer.$(RANDOM)"
ASK_SET_ANSWER_LOG_FILE "${TEST_ANSWER_FILE}"

# Utility functions ----------------------------------------------------------

TEST_FAILED() {
  rm -f "${TEST_FILE}" "${TEST_ANSWER_FILE}"
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
mDOTHIS() { echo -n "- $* ... "; reset_LOG_FILES; }
mOK()     { echo 'OK';           reset_LOG_FILES; }

reset_LOG_FILES

# Make tests -----------------------------------------------------------------

test_conf_file="/tmp/conf.$(RANDOM)"

mDOTHIS 'Test CONF_SET_FILE()'
  res=$( CONF_SET_FILE )
  [ $? -eq 0      ] && TEST_FAILED
  [ "${res}" = '' ] && TEST_FAILED
  check_LOG_FILE 'FATAL: SET_CONF_FILE: bad arguments'
  reset_LOG_FILES

  CONF_SET_FILE "${test_conf_file}"
  [ $? -ne 0 ] && TEST_FAILED
  check_LOG_FILE "Configuration file ${test_conf_file} created"
  reset_LOG_FILES
mOK

# --------------------------------------------------------------------------
mDOTHIS 'Test CONF_LOAD()'
  echo 'TEST=true' >> "${test_conf_file}"
  CONF_LOAD
  [ $? -ne 0 ] && TEST_FAILED
  check_LOG_FILE "CONF_LOAD: ${test_conf_file}"
  reset_LOG_FILES
  [ "${TEST}" != 'true' ] && TEST_FAILED
  rm -f "${test_conf_file}"

  # --------------------------------------------------------------------------
  test_conf_file="/tmp/conf.$(RANDOM)"
  res=$( CONF_LOAD "${test_conf_file}" )
  [ $? -eq 0 ] && TEST_FAILED
  check_LOG_FILE "FATAL: CONF_LOAD: Can't read from '${test_conf_file}'"
  reset_LOG_FILES

  # --------------------------------------------------------------------------
  test_conf_file="/tmp/conf.$(RANDOM)"
  echo 'TEST=false' >> "${test_conf_file}"
  CONF_SET_FILE "${test_conf_file}"
  CONF_LOAD "${test_conf_file}"
  [ $? -ne 0 ] && TEST_FAILED
  check_LOG_FILE "CONF_LOAD: ${test_conf_file}"
  reset_LOG_FILES
  [ "${TEST}" != 'false' ] && TEST_FAILED
mOK

# --------------------------------------------------------------------------
mDOTHIS 'Test CONF_SAVE()'
  res=$( CONF_SAVE )
  [ $? -eq 0 ] && TEST_FAILED
  check_LOG_FILE "FATAL: CONF_SAVE: Bad number of arguments"
  reset_LOG_FILES

  # --------------------------------------------------------------------------
  res=$( CONF_SAVE riri fifi loulou )
  [ $? -eq 0 ] && TEST_FAILED
  check_LOG_FILE "FATAL: CONF_SAVE: Bad number of arguments"
  reset_LOG_FILES

  # --------------------------------------------------------------------------
  test_file2="/tmp/conf.$(RANDOM)"
  touch "${test_file2}" && chmod 000 "${test_file2}" || TEST_FAILED

  res=$( CONF_SAVE --conf-file "${test_file2}" test_file2 )
  [ $? -eq 0 ] && TEST_FAILED
  check_LOG_FILE "FATAL: CONF_SAVE: Can't write into configuration file '${test_file2}'"
  reset_LOG_FILES

  # --------------------------------------------------------------------------
  res=$( CONF_SAVE '' )
  [ $? -eq 0 ] && TEST_FAILED
  check_LOG_FILE "FATAL: CONF_SAVE: variable name is empty"
  reset_LOG_FILES

  # --------------------------------------------------------------------------
  TOTO='patrick'
  CONF_SAVE TOTO
  [ $? -ne 0 ] && TEST_FAILED
  check_LOG_FILE "CONF_SAVE: TOTO=\"patrick\""
  reset_LOG_FILES

  # --------------------------------------------------------------------------
  TOTO=
  CONF_LOAD
  reset_LOG_FILES
  [ "${TOTO}" != 'patrick' ] && TEST_FAILED

  # --------------------------------------------------------------------------
  TOTO=
  echo '  TOTO="patrick"' > "${test_conf_file}"
  CONF_LOAD
  reset_LOG_FILES
  [ "${TOTO}" != 'patrick' ] && TEST_FAILED

  # --------------------------------------------------------------------------
  long_sentence="coucou tout le monde"
  CONF_SAVE long_sentence
  [ $? -ne 0 ] && TEST_FAILED
  check_LOG_FILE "CONF_SAVE: long_sentence=\"coucou tout le monde\""
  reset_LOG_FILES

mOK

# --------------------------------------------------------------------------
mDOTHIS 'Test CONF_GET()'

  res=$( CONF_GET )
  [ $? -eq 0 ] && TEST_FAILED
  check_LOG_FILE "FATAL: CONF_GET: bad number of arguments"
  reset_LOG_FILES

  # --------------------------------------------------------------------------
  res=$( CONF_GET riri fifi loulou )
  [ $? -eq 0 ] && TEST_FAILED
  check_LOG_FILE "FATAL: CONF_GET: bad number of arguments"
  reset_LOG_FILES

  # --------------------------------------------------------------------------
  res=$( CONF_GET --conf-file "${test_file2}" )
  [ $? -eq 0 ] && TEST_FAILED
  check_LOG_FILE "FATAL: CONF_GET: bad number of arguments"
  reset_LOG_FILES

  # --------------------------------------------------------------------------
  res=$( CONF_GET --conf-file "${test_file2}" TOTO )
  [ $? -eq 0 ] && TEST_FAILED
  check_LOG_FILE "FATAL: CONF_GET: Can't read from '${test_file2}'"
  reset_LOG_FILES

  # --------------------------------------------------------------------------
  CONF_GET long_sentence
  [ "${long_sentence}" != 'coucou tout le monde' ] && TEST_FAILED
  check_LOG_FILE "CONF_GET: long_sentence=\"coucou tout le monde\""
  reset_LOG_FILES

  # --------------------------------------------------------------------------
  CONF_GET long_sentence other_var
  [ $? -ne 0 ] && TEST_FAILED
  [ "${other_var}" != 'coucou tout le monde' ] && TEST_FAILED
  check_LOG_FILE "CONF_GET: other_var=\"coucou tout le monde\""
  reset_LOG_FILES

  # --------------------------------------------------------------------------
  res=$( CONF_GET '' )
  [ $? -eq 0 ] && TEST_FAILED
  check_LOG_FILE "FATAL: CONF_GET: variable name is empty"
  reset_LOG_FILES
mOK

# --------------------------------------------------------------------------
mDOTHIS 'Test CONF_DEL()'
  echo -n '' > "${test_conf_file}"
  CONF_SAVE --conf-file "${test_conf_file}" long_setence "coucou tout le monde"
  reset_LOG_FILES

  CONF_DEL toto
  [ $? -ne 0 ] && TEST_FAILED
  check_LOG_FILE "CONF_DEL: remove 'toto'"
  reset_LOG_FILES

  # --------------------------------------------------------------------------
  echo -n '' > "${test_conf_file}"
  CONF_SAVE long_setence "coucou tout le monde"
  CONF_SAVE again "coucou tout le monde"
  reset_LOG_FILES

  CONF_DEL long_setence
  [ $? -ne 0 ] && TEST_FAILED
  check_LOG_FILE "CONF_DEL: remove 'long_setence'"
  reset_LOG_FILES

  # --------------------------------------------------------------------------
  echo -n '' > "${test_conf_file}"
  CONF_SAVE --conf-file "${test_conf_file}" toto "coucou"
  CONF_SAVE --conf-file "${test_conf_file}" tata "tout le monde"
  reset_LOG_FILES
  CONF_DEL --conf-file "${test_conf_file}" toto
  [ $# -ne 0 ] && TEST_FAILED
  check_LOG_FILE "CONF_DEL: remove 'toto'"
  res=$( CONF_GET toto )
  [ -n "${res}" ] && TEST_FAILED
  reset_LOG_FILES

  CONF_DEL --conf-file "${test_conf_file}" tata
  [ $? -ne 0 ] && TEST_FAILED
  check_LOG_FILE "CONF_DEL: remove 'tata'"$'\n'"CONF_DEL: '${test_conf_file}' deleted"
  [ -f "${test_conf_file}" ] && TEST_FAILED
  reset_LOG_FILES

  # --------------------------------------------------------------------------
  echo -n '' > "${test_conf_file}"
  CONF_SAVE --conf-file "${test_conf_file}" toto "coucou"
  chmod a-w "${test_conf_file}"
  reset_LOG_FILES

  res=$( CONF_DEL --conf-file "${test_conf_file}" toto )
  [ $? -eq 0 ] && TEST_FAILED
  check_LOG_FILE "FATAL: CONF_DEL: Can't write to '${test_conf_file}'"
  chmod a+w "${test_conf_file}"
  reset_LOG_FILES

  # --------------------------------------------------------------------------
  res=$( CONF_DEL --conf-file "${test_conf_file}" )
  [ $? -eq 0 ] && TEST_FAILED
  check_LOG_FILE "FATAL: CONF_DEL: bad number of arguments"
  reset_LOG_FILES

  res=$( CONF_DEL toto tata )
  [ $? -eq 0 ] && TEST_FAILED
  check_LOG_FILE "FATAL: CONF_DEL: bad number of arguments"
  reset_LOG_FILES

  res=$( CONF_DEL '' )
  [ $? -eq 0 ] && TEST_FAILED
  check_LOG_FILE "FATAL: CONF_DEL: variable name is empty"
  reset_LOG_FILES
mOK

find /tmp -maxdepth 1 \( -name "test.*" -o -name "conf.*" -o -name "test_answer.*" \) -exec rm -f {} \;

echo
echo "*** All Tests OK ***"
