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

  # usage: MUTEX_GET <resource>
  # desc: Try to get the ressource
  MUTEX_GET () {
    local resource= mutex= owner=
    if [ $# -ne 1 ]; then
      echo "ERROR: MUTEX_GET: no resource given"; return 1;
    fi

    resource="$1"; mutex="${resource}.mutex"

    if [ -z "${resource}" ]; then
      echo "ERROR: can't get an empty resource."; return 1;
    fi

    if [ -f "${mutex}" ]; then
      # check if we are already the owner of the resource
      grep "^$$\$" < "${mutex}" >/dev/null 2>/dev/null
      [ $? -eq 0 ] && return 0;
    fi

    # add us into the mutex
    echo "$$" >> "${mutex}"

    # wait until we are the owner of the mutex
    while [ "${owner}" != "$$" ]; do
      owner=$( head -n 1 < "${mutex}" )
      ps -A | cut -d' ' -f1 | grep "^${owner}$" >/dev/null 2>/dev/null
      if [ $? -ne 0 ]; then
        MUTEX_RELEASE "${resource}" "${owner}"
        continue; # get the next owner and don't sleep :-)
      fi
      sleep 1 # don't burst the cpu !
    done

    return 0;
  }

  # usage: MUTEX_RELEASE <resource> [<token>]
  # desc: remove us (or the <token>) from the mutex pipeline
  MUTEX_RELEASE () {
    local resource= mutex= token=

    if [ $# -ne 1 -a $# -ne 2 ]; then
      echo "ERROR: MUTEX_RELEASE: Bad arguments"; return 1;
    fi

    resource="$1"; mutex="${resource}.mutex" ;
    [ $# -eq 2 ] && token="$2" || token="$$"

    grep -v "^${token}$" < "${mutex}" > "${mutex}.tmp"
    [ -f "${mutex}.tmp" ] && mv "${mutex}.tmp" "${mutex}"

    return 0;
  }

fi # end of: if [ "${__LIB_MUTEX__:-}" != 'Loaded' ]; then
