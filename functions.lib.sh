#
# Copyright (c) 2006-2010 Linagora
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
# Author: Patrick Guiran <pguiran@linagora.com>
# Creation: 04/05/2010
# Update: 09/06/2010
#
# Global variables ===========================================================
# IMPORTANT: Please to write to those variables
# __LIB_FUNCTIONS__ : Indicate that this lib is loaded
# __OUTPUT_LOG_FILE__ : path to the output log file
# __ERROR_LOG_FILE__ : path to the error log file
# __SYSTEM_NAME__ : the name of the system (Debian, Ubuntu, ...)
# __SYSTEM_RELEASE_NAME__ : the code name of the release (Karmic, Lenny, ...)
#
# Methods ====================================================================
#
# SET_LOG_FILE()
#   $1: path to log file
#   desc: will create $1.output (output log file) and $1.error (error log
#         file) files, which will be used in CMD()
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
# MESSAGE()
#   desc: This function is used to display messages on standard output
#         and/or write messages into  the output log file.
#  usage: MESSAGE [<options>] "<message>"
#  options:
#    --no-break : use 'echo -n' instead of 'echo' to display/write message
#    --no-date : Don't add the date in message written into the output log file
#    --no-print : Don't print message on standard output
#    --no-log : Don't write message into output log file
#
#  aliases:
#    MSG()     = MESSAGE
#    LOG()     = MESSAGE --no-print
#    NOTICE()  = MESSAGE "NOTICE: <message>"
#    ERROR()   = MESSAGE "ERROR: <message>"
#    BR()      = MESSAGE --no-log ""
#    DOTHIS()  = MESSAGE --no-break -- '- <message> ... '
#    OK()      = MESSAGE --no-date -- "OK" + close DOTHIS if one
#    KO()      = MESSAGE --no-date -- "KO" + close DOTHIS if one + FATAL "<message>"
#    WARNING() = MESSAGE --no-log "WARN: <message>"  + close DOTHIS if one
#
# FATAL()
#   $1: error message
#   desc: prefix message with "FATAL:" and call MESSAGE().
#         Then it call ROLLBACK() and exit(1).
#
# ROLLBACK()
#   desc: by default, it's done nothing. Its purpose is to be
#         override by the parent script
#
# SOURCE()
#   desc: 'source' a bash file, by checking if the file exists
#   usage: SOURCE <file>
#
#
# ----------------------------------------------------------------------------

# don't source several times this file
if [ "${__LIB_FUNCTIONS__}" != 'Loaded' ]; then
  __LIB_FUNCTIONS__="Loaded"

  # IMPORTANT: Don't set those variables directly in the parent script
  __OUTPUT_LOG_FILE__=''
  __ERROR_LOG_FILE__=''
  __SYSTEM_NAME__=''
  __SYSTEM_RELEASE_NAME__=''

  # used to known if we are in a DOTHIS - OK/KO block
  # note: do not modify this variable
  __IN_DOTHIS__="false"

  which lsb_release >/dev/null 2>/dev/null
  if [ $? -eq 0 ]; then
    __SYSTEM_NAME__=$( lsb_release -s -i )
    __SYSTEM_RELEASE_NAME__=$( lsb_release -s -c )
  else
    __SYSTEM_NAME__="unknown"
    __SYSTEM_RELEASE_NAME__="unknown"
  fi

  # Utility functions -------------------------------------

  MESSAGE() {
    local do_print="true" do_log="true" msg= date=$(date +"[%D %T]") echo_opt=

    # parse arguments
    while [ true ]; do
      case $1 in
        "--no-break" ) shift; echo_opt='-n' ;;
        "--no-date"  ) shift; date=''            ;;
        "--no-print" ) shift; do_print="false"   ;;
        "--no-log"   ) shift; do_log="false"     ;;
        "--"         ) shift; break;             ;;
        --*          ) shift;                    ;; # ignore
        *            ) break;                    ;;
      esac
    done

    msg="$*"
    if [ "${do_print}" = "true" ]; then
      # don't put the date on standard output (STDOUT)
      echo ${echo_opt} "${msg}"
    fi

    if [ "${do_log}" = "true" -a -f "${__OUTPUT_LOG_FILE__}" ]; then
      [ -n "${date}" ] && msg="${date} ${msg}"
      echo ${echo_opt} "${msg}" >> "${__OUTPUT_LOG_FILE__}"
    fi
  }

  MSG()    { MESSAGE $*;                        }
  NOTICE() { MESSAGE "NOTICE: $*";              }
  LOG()    { MESSAGE --no-print $@;             }
  BR()     { MESSAGE --no-log --no-break $'\n'; }

  ERROR() {
    if [ "${__IN_DOTHIS__}" = "true" ]; then
      MESSAGE --no-date -- "Err";
      __IN_DOTHIS__="false"
    fi
    MESSAGE --no-log "ERROR: $*"
  }

  WARNING() {
    if [ "${__IN_DOTHIS__}" = "true" ]; then
      MESSAGE --no-date -- "Warn";
      __IN_DOTHIS__="false"
    fi
    MESSAGE --no-log "WARNING: $*"
  }

  DOTHIS() {
    MESSAGE --no-break -- "- $* ... "
    __IN_DOTHIS__="true"
  }

  OK() {
    [ "${__IN_DOTHIS__}" = "true" ] && MESSAGE --no-date -- "OK"
    __IN_DOTHIS__="false"
  }

  KO() {
    if [ "${__IN_DOTHIS__}" = "true" ]; then
      MESSAGE --no-date -- "KO";
      __IN_DOTHIS__="false"
    fi
    FATAL "$*"
  }

  # do nothing. Can be override
  ROLLBACK() { echo >/dev/null; }

  FATAL() {
    MESSAGE "fATAL: $*"
    ROLLBACK
    exit 1
  }


  EXEC() {
    local command= do_check="false" do_log="false" outputs= old_shell_opt=

    # parse arguments
    while true ; do
      case "$1" in
        "--with-log"   ) shift; do_log="true"   ;;
        "--with-check" ) shift; do_check="true" ;;
        --*            ) shift                  ;; # ignore this option
        "--"           ) shift; break           ;;
        *              ) break                  ;;
      esac
    done

    # build the command
    command=$*
    if [ "${do_log}" = "true" ]; then
      [ -n "${__OUTPUT_LOG_FILE__}" ] && outputs="${outputs} >>\"${__OUTPUT_LOG_FILE__}\" "
      [ -n "${__ERROR_LOG_FILE__}"  ] && outputs="${outputs} 2>>\"${__ERROR_LOG_FILE__}\" "
    fi

    # disable shell debug, to not fucked up the log files content
    old_shell_opt=$-; set +x

    # exec the command
    if [ "${do_check}" = "true" ]; then
      eval "(${command}) ${outputs} || KO '$*'"
    else
      # execute the command
      eval "(${command}) ${outputs}"
    fi

    # restaure shell options
    set -${old_shell_opt}
  }

  # aliases
  EXEC_WITH_CHECK()         { EXEC --with-check -- "$*";            }
  EXEC_WITH_LOG()           { EXEC --with-log -- "$*";              }
  EXEC_WITH_CHECK_AND_LOG() { EXEC --with-check --with-log -- "$*"; }
  CMD()                     { EXEC_WITH_CHECK_AND_LOG $@;           }

  # Check for root privileges
  CHECK_ROOT() {
    user_id=`id -u`
    [ "${user_id}" != "0" ] \
      && KO "You must execute $0 with root privileges"
  }

  SET_LOG_FILE() {
    [ -z "$1" ] && KO "SET_OUTPUT_LOG_FILE is called without argument !"
    __OUTPUT_LOG_FILE__="$1.output"
    __ERROR_LOG_FILE__="$1.error"


    if [ -f "${__OUTPUT_LOG_FILE__}" ]; then
      rm -f "${__OUTPUT_LOG_FILE__}" \
        || KO "Unable to delete existing output log file '${__OUTPUT_LOG_FILE__}'."
    fi

    touch "${__OUTPUT_LOG_FILE__}" \
      || KO "Unable to create output log file '${__OUTPUT_LOG_FILE__}'"

    if [ -f "${__ERROR_LOG_FILE__}" ]; then
      rm -f "${__ERROR_LOG_FILE__}" \
        || KO "Unable to delete existing error log file '${__ERROR_LOG_FILE__}'."
    fi

    touch "${__ERROR_LOG_FILE__}" \
      || KO "Unable to create error log file '${__ERROR_LOG_FILE__}'"

  }

  private_DISPLAY_LOG_FILES() {
    if [ -n "${__OUTPUT_LOG_FILE__}" -a -n "${__ERROR_LOG_FILE__}" ]; then
      NOTICE "Here are where you can find log files"
      MESSAGE "   output: ${__OUTPUT_LOG_FILE__}"
      MESSAGE "   error: ${__ERROR_LOG_FILE__}"
    fi
  }

  SOURCE() {
    if [ -r "$1" ]; then
      source "$1" || KO "Can't source $1"
    else
      KO "$1 hasn't been find"
    fi
  }

fi # end of: if [ "${__LIB_FUNCTIONS__}" = 'Loaded' ]; then
