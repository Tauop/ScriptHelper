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
# __LIB_MESSAGE__ : Indicate that this lib is loaded
# __MSG_INDENT__ : indentation for messages
# Methods ====================================================================
#
# MESSAGE()
#   usage: MESSAGE [<options>] "<message>"
#   desc: This function is used to display messages on standard output
#         and/or write messages into the output log file.
#   note: Message are display with indentation if MSG_INDENT_* functions
#         are called, or if the script call DOTHIS() and related functions
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
#    ERROR()   = MESSAGE "ERROR: <message>" + close DOTHIS if one
#    WARNING() = MESSAGE "WARN: <message>"  + close DOTHIS if one
#    BR()      = MESSAGE --no-log $'\n'
#    DOTHIS()  = MESSAGE --no-break -- '- <message> ... '
#    OK()      = MESSAGE --no-date -- "OK" + close DOTHIS if one
#    KO()      = MESSAGE --no-date -- "KO" + close DOTHIS if one + FATAL "<message>"
#
# MSG_INDENT_INC()
#   desc: increment indentation of MESSAGE() display by two spaces
#
# MSG_INDENT_DEC()
#   desc: decrement indentation of MESSAGE() display by two spaces
#
# FATAL()
#   usage: FATAL <error message>
#   desc: prefix message with "FATAL:" and call MESSAGE().
#         Then it call ROLLBACK() and exit(1).
#   note: close DOTHIS if one
#
# ROLLBACK()
#   desc: by default, it's done nothing. Its purpose is to be
#         override by the parent script
#
# ----------------------------------------------------------------------------

# don't source several times this file
if [ "${__LIB_MESSAGE__:-}" != 'Loaded' ]; then
  __LIB_MESSAGE__='Loaded'

  # IMPORTANT: Don't set those variables directly in the parent script
  __MSG_INDENT__=''
  __IN_DOTHIS__='false' # used to known if we are in a DOTHIS - OK/KO block

  # Utility functions -------------------------------------

  MSG_INDENT_INC () { __MSG_INDENT__="${__MSG_INDENT__:-}  "; }
  MSG_INDENT_DEC () { __MSG_INDENT__="${__MSG_INDENT__%  }";  }

  MESSAGE () {
    local do_print='true' do_log='true' do_indent='true'
    local msg= date= echo_opt=
    date=$(date +"[%D %T]")

    # parse arguments
    while [ true ]; do
      [ $# -eq 0 ] && break
      case "$1" in
        --no-break  ) shift; echo_opt='-n' ;;
        --no-date   ) shift; date=''            ;;
        --no-print  ) shift; do_print='false'   ;;
        --no-log    ) shift; do_log='false'     ;;
        --no-indent ) shift; do_indent='false'  ;;
        --          ) shift; break;             ;;
        --*         ) shift;                    ;; # ignore
        *           ) break;                    ;;
      esac
    done

    msg="$*"
    [ "${do_indent}" = 'true' ] && msg="${__MSG_INDENT__:-}${msg}"

    # don't put the date on standard output (STDOUT)
    [ "${do_print}" = 'true' ] && echo ${echo_opt} "${msg}"

    if [ "${do_log}" = 'true' -a -f "${__OUTPUT_LOG_FILE__:-}" ]; then
      [ -n "${date}" ] && msg="${date} ${msg}"
      echo ${echo_opt} "${msg}" >> "${__OUTPUT_LOG_FILE__:-}"
    fi
  }

  MSG ()    { MESSAGE $@; }
  LOG ()    { MESSAGE --no-indent --no-print $@; }
  NOTICE () { MESSAGE --no-indent "${__MSG_INDENT__:-}NOTICE: $*"; }
  BR ()     { MESSAGE --no-log --no-break --no-indent  $'\n'; }

  ERROR () {
    if [ "${__IN_DOTHIS__:-}" = 'true' ]; then
      MESSAGE --no-date --no-indent -- 'Err';
      __IN_DOTHIS__='false'
    fi
    MESSAGE --no-indent "${__MSG_INDENT__:-}ERROR: $*"
  }

  WARNING () {
    if [ "${__IN_DOTHIS__:-}" = 'true' ]; then
      MESSAGE --no-date --no-indent -- 'Warn';
      __IN_DOTHIS__='false'
    fi
    MESSAGE --no-indent "${__MSG_INDENT__:-}WARNING: $*"
  }

  DOTHIS () {
    MESSAGE --no-break --no-indent -- "${__MSG_INDENT__:-}- $* ... "
    __IN_DOTHIS__='true'
  }

  OK () {
    [ "${__IN_DOTHIS__:-}" = 'true' ] && MESSAGE --no-date --no-indent -- 'OK'
    __IN_DOTHIS__='false'
  }

  KO () {
    if [ "${__IN_DOTHIS__:-}" = 'true' ]; then
      MESSAGE --no-date --no-indent -- 'KO';
      __IN_DOTHIS__='false'
    fi
    FATAL "$*"
  }

  # do nothing. Can be override
  ROLLBACK () { echo >/dev/null; }

  FATAL () {
    if [ "${__IN_DOTHIS__:-}" = 'true' ]; then
      MESSAGE --no-date --no-indent -- 'Fatal';
      __IN_DOTHIS__='false'
    fi
    MESSAGE --no-indent "${__MSG_INDENT__:-}FATAL: $*"
    type DISPLAY_LOG_FILES >/dev/null 2>/dev/null
    [ $? -eq 0 ] && DISPLAY_LOG_FILES
    ROLLBACK
    exit 1
  }


fi # end of: if [ "${__LIB_MESSAGE__}" = 'Loaded' ]; then
