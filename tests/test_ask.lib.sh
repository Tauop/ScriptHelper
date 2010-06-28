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

# Make tests -----------------------------------------------------------------
MESSAGE "Test: HIT_TO_CONTINUE()"
HIT_TO_CONTINUE

result=
MESSAGE "Test: ASK anything"
ASK result "Type anything:"
MESSAGE "You have type \"${result}\""
MESSAGE ""

result=
MESSAGE "Test: ASK yes/no"
ASK --yesno result "yes or no ?"
MESSAGE "You have type \"${result}\""
MESSAGE ""

result=
MESSAGE "Test: ASK yes/no with Yes in default"
ASK --yesno result "yes/no [Y] ?:" 'Y'
MESSAGE "You have type \"${result}\""
MESSAGE ""

result=
MESSAGE "Test: ASK number"
MESSAGE "Test: enter a bad response to see the error message \"Your answer is not a number\""
ASK --number result "Number:" '' 'Your answer is not a number'
MESSAGE "You have type \"${result}\""
MESSAGE ""

result=
MESSAGE "Test: ASK number with 9 in default"
ASK --number result "Number [9]:" '9'
MESSAGE "You have type \"${result}\""
MESSAGE ""

result=
MESSAGE "Test: ASK --no-print"
ASK --no-print result "Password:"
MESSAGE "You have type \"${result}\""
MESSAGE ""

result=
MESSAGE "Test: ASK --allow-empty"
MESSAGE "Just hit ENTER for this test, and check that the response is an empty string"
ASK --allow-empty result "Want to say something ?"
MESSAGE "You have type \"${result}\""
MESSAGE ""

result=
MESSAGE "Test: ASK --with-break and --useless-option"
MESSAGE "A LineBreak is added after the question"
ASK --with-break --useless-option result "Want to say something ?"
MESSAGE "You have type \"${result}\""
MESSAGE ""

