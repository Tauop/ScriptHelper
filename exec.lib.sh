#
# Copyright (c) 2006-2010 Linagora
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
# __LIB_EXEC__ : Indicate that this lib is loaded
# __OUTPUT_LOG_FILE__ : path to the output log file
# __ERROR_LOG_FILE__ : path to the error log file
# __SYSTEM_NAME__ : the name of the system (Debian, Ubuntu, ...)
# __SYSTEM_RELEASE_NAME__ : the code name of the release (Karmic, Lenny, ...)
#
# Methods ====================================================================
#
# SET_LOG_FILE()
#   usage: SET_LOG_FILE <filename>
#   desc: will create <filename>.output (output log file) and <filename>.error
#         (error log file) files, which will be used in CMD()
#
# DISPLAY_LOG_FILES()
#   desc: display log files set with SET_LOG_FILES()
#
# CHECK_ROOT()
#   desc: check that the user is 'root' user
#
# EXEC()
#   desc: execute a command.
#         Can redirect output to output log file and redirect error output
#         to error log file.
#         Can call KO() on error.
#   usage: EXEC [<options>] <command_to_run>
#   options:
#     --with-log : log outputs to LOGS files
#     --with-check : Call KO() if the command return a non-'0' value
#
#   aliases:
#     EXEC_WITH_CHECK()         = EXEC --with-check
#     EXEC_WITH_LOG()           = EXEC --with-log
#     EXEC_WITH_CHECK_AND_LOG() = EXEC --with-check --with-log
#     CMD()                     = EXEC --with-check --with-log
#
# ----------------------------------------------------------------------------

# don't source several times this file
if [ "${__LIB_EXEC__:-}" != 'Loaded' ]; then
  __LIB_EXEC__='Loaded'

  # IMPORTANT: Don't set those variables directly in the parent script
  __OUTPUT_LOG_FILE__=''
  __ERROR_LOG_FILE__=''
  __SYSTEM_NAME__=''
  __SYSTEM_RELEASE_NAME__=''


  # we don't want to be dependant on message.lib.sh
  if [ "${__LIB_MESSAGE__:-}" != 'Loaded' ]; then
    MESSAGE () { echo $*;         }
    NOTICE  () { echo $*;         }
    KO      () { echo $*; exit 1; }
  fi


  which lsb_release >/dev/null 2>/dev/null
  if [ $? -eq 0 ]; then
    __SYSTEM_NAME__=$( lsb_release -s -i )
    __SYSTEM_RELEASE_NAME__=$( lsb_release -s -c )
  else
    __SYSTEM_NAME__='unknown'
    __SYSTEM_RELEASE_NAME__='unknown'
  fi


  # Check for root privileges
  CHECK_ROOT () {
    user_id=`id -u`
    [ "${user_id}" != "0" ] \
      && KO "You must execute $0 with root privileges"
  }


  SET_LOG_FILE () {
    [ -z "$1"  ] && KO 'SET_OUTPUT_LOG_FILE is called without argument !'
    [ $# -gt 1 ] && KO 'SET_OUTPUT_LOG_FILE: too much arguments !'

    __OUTPUT_LOG_FILE__="$1.output"
    __ERROR_LOG_FILE__="$1.error"


    [ -f "${__OUTPUT_LOG_FILE__}" ] && EXEC_WITH_CHECK rm -f "${__OUTPUT_LOG_FILE__}"
    [ -f "${__ERROR_LOG_FILE__}"  ] && EXEC_WITH_CHECK rm -f "${__ERROR_LOG_FILE__}"
    EXEC_WITH_CHECK touch "${__OUTPUT_LOG_FILE__}"
    EXEC_WITH_CHECK touch "${__ERROR_LOG_FILE__}"

  }

  DISPLAY_LOG_FILES () {
    if [ -n "${__OUTPUT_LOG_FILE__:-}" -a -n "${__ERROR_LOG_FILE__:-}" ]; then
      NOTICE 'Here are where you can find log files'
      MESSAGE "   output: ${__OUTPUT_LOG_FILE__:-}"
      MESSAGE "   error: ${__ERROR_LOG_FILE__:-}"
    fi
  }

  EXEC () {
    local command= do_check='false' do_log='false' outputs= old_shell_opt= return_value=

    # parse arguments
    while true ; do
      [ $# -eq 0 ] && break
      case "$1" in
        --with-log   ) shift; do_log='true'   ;;
        --with-check ) shift; do_check='true' ;;
        --*          ) shift                  ;; # ignore this option
        --           ) shift; break           ;;
        *            ) break                  ;;
      esac
    done

    # build the command
    command=$*
    if [ "${do_log}" = 'true' ]; then
      [ -n "${__OUTPUT_LOG_FILE__:-}" ] && outputs="${outputs} >>\"${__OUTPUT_LOG_FILE__:-}\" "
      [ -n "${__ERROR_LOG_FILE__:-}"  ] && outputs="${outputs} 2>>\"${__ERROR_LOG_FILE__:-}\" "
    fi

    # disable shell debug, to not fucked up the log files content
    old_shell_opt=$-; set +x

    # exec the command
    if [ "${do_check}" = 'true' ]; then
      eval "(${command}) ${outputs} || ( r=\$?; F() { KO '$*'; return \$1; }; F \$r; )"
      return_value=$?
    else
      # execute the command
      eval "(${command}) ${outputs}"
      return_value=$?
    fi

    # restaure shell options
    set -${old_shell_opt}

    return ${return_value}
  }

  # aliases
  EXEC_WITH_CHECK ()         { EXEC --with-check -- "$*";            }
  EXEC_WITH_LOG ()           { EXEC --with-log -- "$*";              }
  EXEC_WITH_CHECK_AND_LOG () { EXEC --with-check --with-log -- "$*"; }
  CMD ()                     { EXEC_WITH_CHECK_AND_LOG $@;           }


fi # end of: if [ "${__LIB_EXEC__}" = 'Loaded' ]; then
