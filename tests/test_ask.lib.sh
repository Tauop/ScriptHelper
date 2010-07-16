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

SOURCE ../ask.lib.sh

TEST_FILE="/tmp/test.${RANDOM}"
SET_LOG_FILE "${TEST_FILE}"

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
    content=`cat "${__OUTPUT_LOG_FILE__}" | cut -d ']' -f2- | sed -e 's/^ //' | tr $'\n' ':'`
    content2=`echo "$*" | tr $'\n' ':'`
    [ "${content}" != "${content2}" ] && TEST_FAILED
    reset_FILES
  fi
}

reset_FILES() {
  echo -n '' > "${TEST_FILE}"
  [ -f "${__OUTPUT_LOG_FILE__}" ] && echo -n '' > "${__OUTPUT_LOG_FILE__}"
  [ -f "${__ERROR_LOG_FILE__}"  ] && echo -n '' > "${__ERROR_LOG_FILE__}"
}

# Make tests -----------------------------------------------------------------
MESSAGE --no-log "Test: HIT_TO_CONTINUE()"
HIT_TO_CONTINUE
check_LOG_FILE "
Press ENTER to continue, or CTRL+C to exit

User press ENTER"


result=
MESSAGE --no-log "Test: ASK anything"
ASK result "Type anything:"
MESSAGE --no-log "You have type \"${result}\""
MESSAGE --no-log ''

check_LOG_FILE "Type anything: => ${result}"


result=
MESSAGE --no-log "Test: ASK yes/no"
ASK --yesno result "yes or no ?"
MESSAGE --no-log "You have type \"${result}\""
MESSAGE --no-log ''

check_LOG_FILE "yes or no ? => ${result}"


result=
MESSAGE --no-log "Test: ASK yes/no with Yes in default"
ASK --yesno result "yes/no [Y] ?" 'Y'
MESSAGE --no-log "You have type \"${result}\""
MESSAGE --no-log ''

check_LOG_FILE "yes/no [Y] ? => ${result}"


result=
MESSAGE --no-log "Test: ASK number"
MESSAGE --no-log "Test: enter a bad response to see the error message \"Your answer is not a number\""
ASK --number result "Number:" '' 'Your answer is not a number'
MESSAGE --no-log "You have type \"${result}\""
MESSAGE --no-log ''

check_LOG_FILE "Number: => ${result}"


result=
MESSAGE --no-log "Test: ASK number with 9 in default"
ASK --number result "Number [9]:" '9'
MESSAGE --no-log "You have type \"${result}\""
MESSAGE --no-log ''

check_LOG_FILE "Number [9]: => ${result}"


result=
MESSAGE --no-log "Test: ASK --no-print"
ASK --pass result "Password:"
MESSAGE --no-log "You have type \"${result}\""
MESSAGE --no-log ''
check_LOG_FILE "Password: => ${result//?/#}"


result=
MESSAGE --no-log "Test: ASK --allow-empty"
MESSAGE --no-log "Just hit ENTER for this test, and check that the response is an empty string"
ASK --allow-empty result "Want to say something ?"
MESSAGE --no-log "You have type \"${result}\""
MESSAGE --no-log ''

check_LOG_FILE 'Want to say something ? =>'

result=
MESSAGE --no-log "Test: ASK --with-break and --useless-option"
MESSAGE --no-log "A LineBreak is added after the question"
ASK --with-break --useless-option result "Want to say something ?"
MESSAGE --no-log "You have type \"${result}\""
MESSAGE --no-log ''

check_LOG_FILE "Want to say something ? => ${result}"


exit 0
