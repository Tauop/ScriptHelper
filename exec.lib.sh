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
# This library purpose is to execute command, check the result and log all
# outputs
#
# Global variables ===========================================================
# IMPORTANT: Please to write to those variables
# __LIB_EXEC__ : Indicate that this lib is loaded
# __OUTPUT_LOG_FILE__ : path to the output log file
# __ERROR_LOG_FILE__ : path to the error log file
# __SYSTEM_NAME__ : the name of the system (Debian, Ubuntu, ...)
# __SYSTEM_RELEASE_NAME__ : the code name of the release (Karmic, Lenny, ...)
# ----------------------------------------------------------------------------

# don't source several times this file
if [ "${__LIB_EXEC__:-}" != 'Loaded' ]; then
  __LIB_EXEC__='Loaded'
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

  # get system information which is often need when
  # executing command on it (portability checks)
  which lsb_release >/dev/null 2>/dev/null
  if [ $? -eq 0 ]; then
    __SYSTEM_NAME__=$( lsb_release -s -i )
    __SYSTEM_RELEASE_NAME__=$( lsb_release -s -c )
  else
    __SYSTEM_NAME__='unknown'
    __SYSTEM_RELEASE_NAME__='unknown'
  fi


  # usage: CHECK_ROOT
  # desc: check that the user is 'root' user
  CHECK_ROOT () {
    user_id=`id -u`
    [ "${user_id}" != "0" ] \
      && KO "You must execute $0 with root privileges"
  }

  # usage: SET_LOG_FILE <filename>
  # desc: will create <filename>.output (output log file) and <filename>.error
  #       (error log file) files, which will be used in CMD()
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

  # usage: DISPLAY_LOG_FILES
  # desc: display log files set with SET_LOG_FILES()
  DISPLAY_LOG_FILES () {
    if [ -n "${__OUTPUT_LOG_FILE__:-}" -a -n "${__ERROR_LOG_FILE__:-}" ]; then
      MESSAGE --no-log  'NOTICE: Here are where you can find log files'
      MESSAGE --no-log "   output: ${__OUTPUT_LOG_FILE__:-}"
      MESSAGE --no-log "   error: ${__ERROR_LOG_FILE__:-}"
    fi
  }

  # usage: EXEC [<options>] <command>
  # desc: execute a command.
  # usage: EXEC [<options>] <command_to_run>
  # options: --with-log : log outputs to LOGS files
  #          --with-check : Call KO() if the command return a non-'0' value
  # note: Can redirect output to output log file and redirect error output to error log file.
  # note: Can call KO() on error.
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

  # usage: EXEC_WITH_CHECK <command>
  # desc: alias of EXEC --with-check -- <command>
  EXEC_WITH_CHECK ()         { EXEC --with-check -- "$*";            }

  # usage: EXEC_WITH_LOG <command>
  # desc: alias of EXEC --with-log -- <command>
  EXEC_WITH_LOG ()           { EXEC --with-log -- "$*";              }

  # usage: EXEC_WITH_CHECK_AND_LOG <command>
  # desc: alias of EXEC --with-check --with-log -- <command>
  EXEC_WITH_CHECK_AND_LOG () { EXEC --with-check --with-log -- "$*"; }

  # usage: CMD <command>
  # desc: alias of EXEC_WITH_CHECK_AND_LOG <command>
  CMD ()                     { EXEC_WITH_CHECK_AND_LOG $@;           }


fi # end of: if [ "${__LIB_EXEC__}" != 'Loaded' ]; then
