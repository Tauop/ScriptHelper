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
# This library helps to deal with configuration files
#
# Global variables ===========================================================
# IMPORTANT: Please to write to those variables
# __LIB_CONF__ : 'Loaded' when the lib is 'source'd
# __CONF_FILE__ : configuration file to deal with when not given with --file
# ----------------------------------------------------------------------------


# don't load several times this file
if [ "${__LIB_CONF__:-}" != 'Loaded' ]; then
  __LIB_CONF__='Loaded'
  __CONF_FILE__=

  # load dependencies
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

  load __LIB_MESSAGE__ "${SCRIPT_HELPER_DIRECTORY}/message.lib.sh"
  load __LIB_RANDOM__  "${SCRIPT_HELPER_DIRECTORY}/random.lib.sh"

  # ----------------------------------------------------------------------------

  # usage: SET_CONF_FILE <file>
  # desc: Save a file path where you will read/write data
  # note: if the directory doesn't exist, it will be created
  # note: if the configuration file doesn't exist, it will be created
  CONF_SET_FILE () {
    local dir= file=

    [ $# -ne 1 ] && FATAL 'SET_CONF_FILE: bad arguments'
    __CONF_FILE__="$1"

    if [ -z "${__CONF_FILE__}" ]; then
      LOG "Configuration file reset"
      return 0
    fi

    file="${__CONF_FILE__##*/}"
    dir="${__CONF_FILE__%${file}}"

    # create the configuration file if it doesn't exist
    if [ ! -e "${__CONF_FILE__}" ]; then
      [ -d "${dir:-./}" ] || CMD mkdir -p "${dir}"
      touch "${__CONF_FILE__}"
      chmod u+wr "${__CONF_FILE__}"
      chmod a-x "${__CONF_FILE__}"
      LOG "Configuration file ${__CONF_FILE__} created"
    fi
  }

  # usage: private_SED_SEPARATOR <string> 
  # desc: determine a good sed separator
  private_SED_SEPARATOR () {
    for s in '/' '@' ',' '|'; do
      printf '%s' "$1" | grep "$s" >/dev/null
      if [ $? -ne 0 ]; then
        printf '%s' "$s"; return 0;
      fi
    done
    return 1;
  }

  # usage: CONF_SAVE [ <option> ] <conf_var> [ <value> ]
  # desc: save a variable into the configuration file
  # options: --conf-file <file> : the configuration file to use
  CONF_SAVE () {
    local var= value= sep= conf_file="${__CONF_FILE__}" s='[[:space:]]'

    while true ; do
      [ $# -eq 0 ] && break;
      case "$1" in
        --conf-file) shift; conf_file="$1"; shift ;;
        *) break;
      esac
    done

    [ $# -eq 0 -o $# -gt 2 ] && FATAL 'CONF_SAVE: Bad number of arguments'
    [ ! -w "${conf_file}" ] && FATAL "CONF_SAVE: Can't write into configuration file '${conf_file}'"

    var="$1";
    [ -z "${var}" ] && FATAL "CONF_SAVE: variable name is empty"
    [ $# -eq 2 ] && value="$2"
    [ $# -eq 1 ] && eval "value=\"\${${1}}\""

    sep=$( private_SED_SEPARATOR "${var}${value}" )

    # save data into the configuration file
    tmp_file="/tmp/conf.$(RANDOM)"
    grep "^$s*${var}$s*=" < "${conf_file}" >/dev/null 2>/dev/null
    if [ $? -eq 0 ]; then # found -> replace
      sed -e "s${sep}^\($s*${var}\)$s*=.*\$${sep}\1=\"${value}\"${sep}" < "${conf_file}" > "${tmp_file}"
      mv "${tmp_file}" "${conf_file}"
    else # append
      printf '%s\n' "${var}=\"${value}\"" >> "${conf_file}"
    fi

    LOG "CONF_SAVE: ${var}=\"${value}\""
  }

  # usage: CONF_GET [ <options> ] <conf_var> [ <result_var> ]
  # desc: read a variable from the configuration file
  # options: --conf-file <file> : the configuration file to use
  CONF_GET () {
    local result= resultvar= confvar= sep= conf_file="${__CONF_FILE__}" s='[[:space:]]'

    while true ; do
      [ $# -eq 0 ] && break
      case "$1" in
        --conf-file) shift; conf_file="$1"; shift ;;
        *) break;
      esac
    done

    [ $# -eq 0 -o $# -gt 2 ] && FATAL 'CONF_GET: bad number of arguments'
    [ ! -r "${conf_file}" ] && FATAL "CONF_GET: Can't read from '${conf_file}'"

    confvar="$1"
    resultvar="${2:-$1}"
    [ -z "${confvar}" ] && FATAL "CONF_GET: variable name is empty"

    sep=$( private_SED_SEPARATOR "${confvar}${resultvar}" )
    result=$( sed -n -e "s${sep}^$s*${confvar}$s*=$s*\(.*\)$s*\$${sep}\1${sep}p" "${conf_file}" )
    eval "${resultvar}=${result}"
    LOG "CONF_GET: ${resultvar}=${result}"
  }

  # usage: CONF_DEL [ <options> ] <conf_var>
  # desc: remove the <conf_var> from the configuration file
  # options: --conf-file <file> : the configuration file to use
  CONF_DEL () {
    local confvar= tmp_file= conf_file="${__CONF_FILE__}" s='[[:space:]]'

   while true ; do
     [ $# -eq 0 ] && break
     case "$1" in
       --conf-file) shift; conf_file="$1"; shift ;;
       *) break;
     esac
   done

   [ $# -ne 1 ] && FATAL 'CONF_DEL: bad number of arguments'
   confvar="$1"
   [ ! -w "${conf_file}" ] && FATAL "CONF_DEL: Can't write to '${conf_file}'"
   [ -z "${confvar}" ] && FATAL 'CONF_DEL: variable name is empty'

   tmp_file="/tmp/conf.$(RANDOM)"
   grep -v "^$s*${confvar}$s*=.*\$" < "${conf_file}" > "${tmp_file}"
   mv "${tmp_file}" "${conf_file}"
   LOG "CONF_DEL: remove '${confvar}'"

   if [ ! -s "${conf_file}" ]; then
     rm -f "${conf_file}"
     LOG "CONF_DEL: '${conf_file}' deleted"
   fi
   return 0;
  }

  # usage: CONF_LOAD [ <file> ]
  # desc: load a configuration file.
  # note: if called without argument, use the file set by CONF_SET_FILE
  CONF_LOAD () {
    local file=${1:-${__CONF_FILE__}}
    if [ -n "${file}" ]; then
      [ ! -r "${file}" ] && FATAL "CONF_LOAD: Can't read from '${file}'"
      . "${file}"
      LOG "CONF_LOAD: ${file}"
    fi
  }

fi # end of: if [ "${__LIB_CONF__}" != 'Loaded' ]; then
