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
SCRIPT_HELPER_DIRECTORY='..'
[ -r /etc/ScriptHelper.conf ] && . /etc/ScriptHelper.conf

LOAD() {
  if [ -r "${SCRIPT_HELPER_DIRECTORY}/$1" ]; then
    . "${SCRIPT_HELPER_DIRECTORY}/$1"
  else
    echo "[ERROR] Unable to load $1"
    exit 1
  fi
}

LOAD random.lib.sh
LOAD lock.lib.sh

# Utility functions ----------------------------------------------------------

TEST_FAILED () { echo "TEST FAILED"; rm -f "${TEST_FILE}" ; exit 1 ; }
FORK () {
  local code="$*"
  bash -c "SCRIPT_HELPER_DIRECTORY=${SCRIPT_HELPER_DIRECTORY}
    . \"${SCRIPT_HELPER_DIRECTORY}/random.lib.sh\"
    . \"${SCRIPT_HELPER_DIRECTORY}/lock.lib.sh\"
    ${code}"
  return $?
}

FORK_BG () {
  local code="$*"
  bash -c "SCRIPT_HELPER_DIRECTORY=${SCRIPT_HELPER_DIRECTORY}
    . \"${SCRIPT_HELPER_DIRECTORY}/random.lib.sh\"
    . \"${SCRIPT_HELPER_DIRECTORY}/lock.lib.sh\"
    ${code}" &
  sleep 1
}

TEST_FILE="/tmp/test.$(RANDOM)"

# Make tests -----------------------------------------------------------------

# one thread
LOCK "${TEST_FILE}"      || TEST_FAILED
LOCK "${TEST_FILE}"      && TEST_FAILED # can't lock 2 times
IS_LOCKED "${TEST_FILE}" || TEST_FAILED
UNLOCK "${TEST_FILE}"    || TEST_FAILED
UNLOCK "${TEST_FILE}"    && TEST_FAILED # can't unlock 2 times

# two thread
LOCK "${TEST_FILE}"
# other thread can't make those actions
FORK "LOCK \"${TEST_FILE}\""      && TEST_FAILED
FORK "IS_LOCKED \"${TEST_FILE}\"" || TEST_FAILED
FORK "UNLOCK \"${TEST_FILE}\""    && TEST_FAILED
UNLOCK "${TEST_FILE}"
FORK "IS_LOCKED \"${TEST_FILE}\"" && TEST_FAILED

FORK_BG "res=0;
         LOCK \"${TEST_FILE}\" || res=1;
         sleep 5;
         UNLOCK \"${TEST_FILE}\" || res=1;
         exit \$?"
pid=$!

WAIT_FOR_UNLOCK "${TEST_FILE}"
wait ${pid} || TEST_FAILED

FORK_BG "res=0;
         LOCK \"${TEST_FILE}\" || res=1;
         sleep 5;
         UNLOCK \"${TEST_FILE}\" || res=1;
         exit \$?"
pid=$!

WAIT_AND_LOCK "${TEST_FILE}"

wait ${pid}           || TEST_FAILED
UNLOCK "${TEST_FILE}" || TEST_FAILED

rm -f "${TEST_FILE}"
echo "*** All Tests OK ***"
exit 0
