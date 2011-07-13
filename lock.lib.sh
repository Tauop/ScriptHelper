#
# Copyright (c) 2010-2011 Linagora
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
# README ---------------------------------------------------------------------
# This is a bash library helping to exclusive lock a resource
# Important : this library is really simple and doesn't print any error message
# Global variables ===========================================================
# IMPORTANT: Please to write to those variables
# __LIB_LOCK__ : 'Loaded' when the lib is 'source'd
# ----------------------------------------------------------------------------

if [ "${__LIB_LOCK__:-}" != 'Loaded' ]; then
  __LIB_LOCK__='Loaded'

  # usage: LOCK <file>
  # desc: Lock a <file> for exclusive access. It returns 0 if lock can be made, a non-zero value otherwise
  # note: If the lock already exists, LOCK returns 1
  LOCK () {
    [ -z "${1:-}" ] && return 1
    ln -s "$1" "$1.lock" 2>/dev/null || return 1
    ln -s "$1" "$1.lock.$$"
    return 0
  }

  # usage: UNLOCK <file>
  # desc: Revoke a lock on <file>. It returns 0 on success, a non-zero value otherwise
  UNLOCK () { [ -n "${1:-}" -a -L "${1:-}.lock.$$" ] && rm -f "$1.lock.$$" "$1.lock" || false ; return $? ; }

  # usage: IS_LOCKED <file>
  # desc: Look if the lock was made by an other process on <file>
  # note: return 0 if <file> is locked, 1 otherwise
  IS_LOCKED () { [ -z "${1:-}" -o -L "${1:-}.lock" ] && true || false ; return $? ; }

  # usage: WAIT_FOR_UNLOCK <file>
  # desc: wait until the lock on <file> is removed
  # note: if an argument is not present, it doesn't wait
  # WARNING: this method can tell that the resource is not locked, whereas it's looked some
  #          CPU ticks later (due to 'method return' time and 'thread context switch' time.
  #          Prefer to use WAIT_AND_LOCK if you want to take a lock
  WAIT_FOR_UNLOCK () {
    local is_locked=
    IS_LOCKED "${1:-}" && is_locked='true' || is_locked='false'
    while [ "${is_locked}" = 'true' ]; do
      sleep 1
      IS_LOCKED "${1:-}" && is_locked='true' || is_locked='false'
    done
  }

  # usage: WAIT_AND_LOCK <file>
  # desc: wait until the lock on <file> can done and is done
  WAIT_AND_LOCK () {
    while [ true ]; do
      LOCK "${1:-}" && return 0
      sleep 1
    done
  }
fi # end of: if [ "${__LIB_LOCK__:-}" != 'Loaded' ]; then
