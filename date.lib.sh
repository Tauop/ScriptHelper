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
# This is a bash library purpose is to give some utilities to print date in
# easy readable fomrat
#
# Global variables ===========================================================
# IMPORTANT: Please to write to those variables
# __LIB_DATE__ : 'Loaded' when the lib is 'source'd
# ----------------------------------------------------------------------------

# don't load several times this file
if [ "${__LIB_DATE__:-}" != 'Loaded' ]; then
  __LIB_DATE__='Loaded'

  # Load dependencies
  load() {
    local var= value= file=

    var="$1"; file="$2"
    value=$( eval "printf \"%s\" \"\${${var}:-}\"" )

    [ -n "${value}" ] && return 1;
    if [ -f "${file}" ]; then
      . "${file}"
    else
      printf "ERROR: Unable to load ${file}"
      exit 2
    fi
    return 0;
  }

  # Load configuration file
  load SCRIPT_HELPER_DIRECTORY /etc/ScriptHelper.conf
  SCRIPT_HELPER_DIRECTORY="${SCRIPT_HELPER_DIRECTORY:-}"
  SCRIPT_HELPER_DIRECTORY="${SCRIPT_HELPER_DIRECTORY%%/}"

  load __LIB_MESSAGE__ "${SCRIPT_HELPER_DIRECTORY}/message.lib.sh"

  # ----------------------------------------------------------------------------

  #usage: DATE_STRING <timestamp> [<format>]
  DATE_STRING () {
    local date_from= format='+%a %e %b %Y %H:%M:%S %Z' result=

    if [ $# -ne 1 -a $# -ne 2 ]; then
      WARNING "DATE_STRING() called without argument"; return 1;
    fi

    date_from="$1"
    [ $# -eq 2 ] && format="$2"

    result=$( date -d "1970-01-01 UTC + ${date_from} seconds" "${format}" 2>/dev/null )
    if [ $? -ne 0 ]; then
      result=$( date -r "${date_from}" "${format}" 2>/dev/null )
      [ $? -ne 0 ] && result="${date_from}"
    fi

    printf "%s" "${result}"
  }

  # ----------------------------------------------------------------------------

  # usage: DATE_AGO [<timestamp>]
  # desc: echo-return a "pretty and human readable" date
  DATE_AGO () {
    local date_from= date_now=$(date +%s) compute= what= w= div= in_past="true" format=
    local one_second=1 one_minute=60 one_hour=3600 one_day=86400 one_week=604800 one_month=2592000 one_year=31622400

    if [ $# -ne 1 ]; then
      WARNING "DATE_AGO() called without argument"; return 1;
    fi

    date_from="$1"
    compute=$(( date_now - date_from ))
    if [ $compute -lt 0 ]; then
      in_past="false"
      compute=$(( -compute ))
    fi

    for w in "year" "month" "week" "day" "hour" "minute" "second"; do
      eval "div=\$one_$w"
      if [ $compute -ge $div ]; then
        compute=$(( compute / div ))
        what="$w"
        break;
      fi
    done

    [ $compute -ne 1 ] && what="${what}s"

    if [ "$in_past" = "true" ]; then
      format="%s %s ago"
    else
      format="in %s %s"
    fi
    printf "$format" "$compute" "$what"
  }

  # ----------------------------------------------------------------------------

  # usage: DATE_PRETTY [<timestamp>]
  # desc: echo-return a "pretty and human readable" date, like gmail
  DATE_PRETTY () {
    local date_from= date_now=$(date +%s) compute=
    local year_now= year_from=
    local one_day=86400

    if [ $# -ne 1 ]; then
      WARNING "DATE_PRETTY() called without argument"; return 1;
    fi

    date_from="$1"
    year_now=$( date +%Y )
    year_from=$( DATE_STRING "${date_from}" "+%Y" )

    compute=$(( date_now - date_from ))
    [ $compute -lt 0 ] && compute=$(( -compute ))

    if [ $compute -lt $one_day ]; then
      DATE_STRING "${date_from}" "+%H:%M"
    else
      if [ "${year_now}" = "${year_from}" ]; then
        DATE_STRING "${date_from}" "+%e %b %H:%M"
      else
        DATE_STRING "${date_from}" "+%d/%m/%y %H:%M"
      fi
    fi
  }

fi # enf of: if [ "${__LIB_ASK__}" != 'Loaded' ]; then
