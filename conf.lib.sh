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
# README ---------------------------------------------------------------------
# This is a bash library for helping writing shell script for simples
# operations.
#
# Global variables ===========================================================
# IMPORTANT: Please to write to those variables
# __LIB_CONF__ : 'Loaded' when the lib is 'source'd
#
# Methods ====================================================================
#
# CONF_SET_FILE()
#   usage: SET_CONF_FILE <file>
#   desc: Save a file path where you will read/write data
#   note: if the directory doesn't exist, it will be created
#   note: if the configuration file doesn't exist, it will be created
#
# CONF_SAVE()
#   usage: CONF_SAVE <conf_var> [ <value> ]
#   desc: save a variable into the configuration file
#
# CONF_GET()
#   usage: CONF_GET <conf_var> [ <result_var> ]
#   desc: read a variable from the configuration file
#
# CONF_LOAD()
#   usage: CONF_LOAD [<file>]
#   desc: load a configuration file.
#   note: if called without argument, use the file set by CONF_SET_FILE
#
# ----------------------------------------------------------------------------


# don't load several times this file
if [ "${__LIB_CONF__:-}" != 'Loaded' ]; then
  __LIB_CONF__='Loaded'

  # Load common lib
  if [ "${__LIB_MESSAGE__:-}" != "Loaded" ]; then
    if [ -r ./message.lib.sh ]; then
      . ./message.lib.sh
    else
      echo "ERROR: Unable to load ./message.lib.sh library"
      exit 2
    fi
  fi

  # ----------------------------------------------------------------------------
  __CONF_FILE__=

  # ----------------------------------------------------------------------------

  CONF_SET_FILE() {
    local dir= file=

    [ $# -ne 1 ] && FATAL "SET_CONF_FILE: bad arguments"
    __CONF_FILE__="$1"

    file="${__CONF_FILE__##*/}"
    dir="${__CONF_FILE__##${file}}"

    # create the configuration file if it doesn't exist
    if [ ! -e "${__CONF_FILE__}" ]; then
      [ -d "${dir:-./}" ] || CMD mkdir -p "${dir}"
      touch "${__CONF_FILE__}"
      chmod u+wr "${__CONF_FILE__}"
      chmod a-x "${__CONF_FILE__}"
      LOG "Configuration file ${__CONF_FILE__} created"
    fi
  }

  CONF_SAVE() {
    local var= value= s='[[:space:]]'

    [ $# -eq 0 ] && FATAL "CONF_SAVE: Bad number of arguments"
    [ ! -w "${__CONF_FILE__}" ] && FATAL "Can't write into configuration file ${__CONF_FILE__}"

    var="$1";
    [ $# -eq 2 ] && value="$2"
    [ $# -eq 1 ] && value="${!1}"

    # save data into the configuration file
    sed -i -e \
        ":loop
         n; s/^$s*\(${var}\)$s*=.*$/\1=${value}/; t
         \$! b loop
         \$ a ${name}=${value}" \
         "${__CONF_FILE__}"

    LOG "CONF_SAVE: ${var}=${value}"
  }

  CONF_GET() {
    local result= resultvar= confvar= s='[[:space:]]'

    [ $# -ne 0 ] && FATAL "CONF_GET: bad number of arguments"

    confvar="$1"
    resultvar="${2:-$1}"

    result=` sed -e -n "s/^$s*${confvar}$s*=$s*\(.*\)$s*$/\1/p" "${__CONF_FILE__}" `
    eval "${resultvar}=${result}"
    LOG "CONF_GET: ${resultvar}=${result}"
  }

  CONF_LOAD() {
    local file=${1:-${__CONF_FILE__}}
    . "${file}"
    LOG "CONF_LOAD: ${file}"
  }

fi # end of: if [ "${__LIB_ASK__}" = 'Loaded' ]; then
