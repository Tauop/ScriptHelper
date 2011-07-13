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
# This library helps to deal with template
#
# Global variables ===========================================================
# IMPORTANT: Please to write to those variables
# __LIB_TEMPLATE__ : 'Loaded' when the lib is 'source'd
# __TEMPLATE_FILE__ : path the log file in which messages will be stored
# ----------------------------------------------------------------------------

# don't load several times this file
if [ "${__LIB_TEMPLATE__:-}" != 'Loaded' ]; then
  __LIB_TEMPLATE__='Loaded'
  __TEMPLATE_FILE__=''

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

  # usage: TEMPLATE_PREPARE <template_file> [ <temp_file> ]
  # desc: create a temporary file, a copy of the template file, for replacing variable
  # arguments:
  # - <template_file> is a file containing variable in ${variable} format
  # - <temp_file> is the temporary file to create
  # note: if <temp_file> isn't specify, create a random file into /tmp
  TEMPLATE_PREPARE () {
    local file= tmp_file=

    [ $# -ne 1 -a $# -ne 2 ] && FATAL "Bad arguments"

    file="$1"
    [ ! -r "${file}" ] && FATAL "Can't read file ${file}."
    [ $# -eq 2 ] && tmp_file="$2" || tmp_file="/tmp/file.$(RANDOM)"

    cp "${file}" "${tmp_file}" 2>/dev/null
    [ $? -ne 0 ] && FATAL "Can't write into file ${tmp_file}."

    TEMPLATE_CLEAN
    __TEMPLATE_FILE__="${tmp_file}"
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

  # usage: TEMPLATE_REPL_VAR <variable> [<value>]
  # desc: Replace a variable in template file
  # arguments:
  #   - <variable> to replace
  #   - <value> to set
  # note: if <value> is not set, use <variable> value
  # note: variable must be in ${variable} format
  TEMPLATE_REPL_VAR () {
    local var= value= tmp_file= sep=

    [ $# -eq 1 -a $# -eq 2 ] && FATAL "Bad arguments"
    var="$1"
    [ $# -eq 1 ] && eval "value=\"\${${1}}\"" || value="$2"

    sep=$( private_SED_SEPARATOR "${var}${value}" )

    tmp_file="${__TEMPLATE_FILE__}.$(RANDOM)"
    sed -e "s${sep}[$][{]${var}[}]${sep}${value}${sep}g" < "${__TEMPLATE_FILE__}" > "${tmp_file}"
    mv "${tmp_file}" "${__TEMPLATE_FILE__}"
  }

  # usage: TEMPLATE_GET_FILE
  # desc: echo-return the filepath of the prepared file
  TEMPLATE_GET_FILE () {
    printf "%s" "${__TEMPLATE_FILE__}"
  }

  # usage: TEMPLATE_CLEAN
  # desc: remove the temporary file create for template manipulation
  TEMPLATE_CLEAN () {
    [ -w "${__TEMPLATE_FILE__}" ] && rm -f "${__TEMPLATE_FILE__}"
  }

fi # end of: if [ "${__LIB_TEMPLATE__:-}" != 'Loaded' ]; then
