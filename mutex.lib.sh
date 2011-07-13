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
# This is a bash library for dealing with mutex on resource (files ATM)
#
# Global variables ===========================================================
# IMPORTANT: Please to write to those variables
# __LIB_MUTEX__ : 'Loaded' when the lib is 'source'd
# ----------------------------------------------------------------------------

if [ "${__LIB_MUTEX__:-}" != 'Loaded' ]; then
  __LIB_MUTEX__='Loaded'

  # Load dependencies
  load() {
    local var= value= file=

    var="$1"; file="$2"
    value=$( eval "printf '%s' \"\${${var}:-}\"" )

    [ -n "${value}" ] && return 1;
    if [ -f "${file}" ]; then
      . "${file}"
    else
      printf "ERROR: Unable to load ${file}\n"
      exit 2
    fi
    return 0;
  }

  # Load configuration file
  load SCRIPT_HELPER_DIRECTORY /etc/ScriptHelper.conf
  SCRIPT_HELPER_DIRECTORY="${SCRIPT_HELPER_DIRECTORY:-}"
  SCRIPT_HELPER_DIRECTORY="${SCRIPT_HELPER_DIRECTORY%%/}"

  load __LIB_LOCK__ "${SCRIPT_HELPER_DIRECTORY}/lock.lib.sh"

  # ----------------------------------------------------------------------------

  # usage: private_MUTEX_REGISTER_TOKEN <resource> <token> <priority>
  # desc: add a token with its priority into the mutex, and order the mutex file
  # note: We don't move the first line of the mutex file (current running task)
  private_MUTEX_REGISTER_TOKEN () {
    local resource= mutex= token= priority= mutex_len= number=

    [ $# -ne 3 ] && return 1;
    resource="$1"; token="$2"; priority="$3"
    mutex="${resource}.mutex"

    # check if we have already registered for taking the resource
    if [ -f "${mutex}" ]; then
      result=$( grep "^[0-9]:${token}\$" < "${mutex}" 2>/dev/null | cut -d':' -f1 )
      if [ -n "${result}" ]; then
        [ ${priority} -eq ${result} ] && return 0;
        # we have to update priority
        MUTEX_RELEASE "${resource}" "${token}"
      fi
    fi

    # critical section. not atomic :-(
    WAIT_AND_LOCK "${mutex}"
      # add us into the mutex
      printf '%s\n' "${priority}:${token}" >> "${mutex}"

      mutex_len=$( < "${mutex}" grep -v '^$' | wc -l | cut -d' ' -f1 )
      if [ ${mutex_len} -gt 2 ]; then
        tail -n $(( ${mutex_len} - 1 )) < "${mutex}" > "${mutex}.tmp"
        head -n 1 < "${mutex}" > "${mutex}.res"
        if [ -f "${mutex}.tmp" ]; then
          for number in `seq 9 -1 0`; do
            grep "^${number}:" < "${mutex}.tmp" >> "${mutex}.res"
          done
        fi
        mv "${mutex}.res" "${mutex}"
        [ -f "${mutex}.tmp" ] && rm -f "${mutex}.tmp"
      fi
    UNLOCK "${mutex}"
    return 0;
  }

  # usage: MUTEX_GET <resource> [<priority>]
  # desc: Try to get the ressource
  # arguments: <argument> is a file
  #            <priority> is a number, between 0 and 9 (higher is better to get the mutex)
  MUTEX_GET () {
    local resource= token= priority= mutex= holder= result=
    if [ $# -ne 1 -a $# -ne 2 ]; then
      printf "ERROR: MUTEX_GET: no resource given\n"; return 1;
    fi

    token=$$
    resource="$1"; mutex="${resource}.mutex"
    [ $# -eq 2 ] && priority="$2" || priority=0

    if [ -z "${resource}" ]; then
      printf "ERROR: can't get an empty resource.\n"; return 1;
    fi
    if ! test ${priority} -eq ${priority} 2>/dev/null ; then
      printf "ERROR: priority must be a number\n"; return 1;
    fi
    if [ ${#priority} -ne 1 -o ${priority} -lt 0 -o ${priority} -gt 9 ]; then
      printf "ERROR: priority must be between 0 and 9\n"; return 1;
    fi

    # register our token into the mutex.
    private_MUTEX_REGISTER_TOKEN "${resource}" "${token}" "${priority}"

    # wait until we are the holder of the mutex
    while [ "${holder}" != "$$" ]; do
      holder=$( head -n 1 < "${mutex}" | cut -d':' -f2 )

      # check that the resource holder is not dead
      ps -A | grep "^ *${holder} *" >/dev/null 2>/dev/null
      if [ $? -ne 0 ]; then
        MUTEX_RELEASE "${resource}" "${holder}"
        continue; # get the next holder and don't sleep :-)
      fi
      sleep 1 # don't burst the cpu !
    done

    return 0;
  }

  # usage: MUTEX_RELEASE <resource> [<token>]
  # desc: remove us (or the <token>) from the mutex pipeline
  MUTEX_RELEASE () {
    local resource= mutex= token= nb_line=

    if [ $# -ne 1 -a $# -ne 2 ]; then
      printf "ERROR: MUTEX_RELEASE: Bad arguments\n"; return 1;
    fi

    resource="$1"; mutex="${resource}.mutex" ;
    [ $# -eq 2 ] && token="$2" || token="$$"

    WAIT_AND_LOCK "${mutex}"
      grep -v "^[0-9]:${token}$" < "${mutex}" > "${mutex}.tmp"
      nb_line=$( wc -l < "${mutex}.tmp" | cut -d' ' -f1 )
      [ -f "${mutex}.tmp" ] && mv "${mutex}.tmp" "${mutex}"
      [ "${nb_line}" = '0' ] && rm -f "${mutex}"
    UNLOCK "${mutex}"
    return 0;
  }

fi # end of: if [ "${__LIB_MUTEX__:-}" != 'Loaded' ]; then
