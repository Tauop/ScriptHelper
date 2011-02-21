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
# This library purpose is to print and log messages (posix compatibility is
# the real purpose)
#
# Global variables ===========================================================
# IMPORTANT: Please to write to those variables
# __LIB_MESSAGE__ : Indicate that this lib is loaded
# __MSG_INDENT__ : indentation for messages
# __IN_DOTHIS__ : used to know if we are in a DOTHIS - OK/KO block
# ----------------------------------------------------------------------------

# don't source several times this file
if [ "${__LIB_MESSAGE__:-}" != 'Loaded' ]; then
  __LIB_MESSAGE__='Loaded'
  __MSG_INDENT__=''
  __IN_DOTHIS__='false'

  # Utility functions -------------------------------------

  # usage: MSG_INDENT_INC
  # desc: increment indentation of MESSAGE() display by two spaces
  MSG_INDENT_INC () { __MSG_INDENT__="${__MSG_INDENT__:-}  "; }

  # usage: MSG_INDENT_DEC
  # desc: decrement indentation of MESSAGE() display by two spaces
  MSG_INDENT_DEC () { __MSG_INDENT__="${__MSG_INDENT__%  }";  }

  # usage: MESSAGE [<options>] "<message>"
  # desc: This function is used to display messages on standard output
  #       and/or write messages into the output log file.
  # note: Message are display with indentation if MSG_INDENT_* functions
  #       are called, or if the script call DOTHIS() and related functions
  #  options:
  #  --no-break : use 'echo -n' instead of 'echo' to display/write message
  #  --no-date : Don't add the date in message written into the output log file
  #  --no-print : Don't print message on standard output
  #  --no-log : Don't write message into output log file
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

  # usage: MSG [<option>] <string>
  # desc: alias of MESSAGE [<option>] <string>
  MSG ()    { MESSAGE $@; }

  # usage: LOG [<option>] <string>
  # desc: alias of MESSAGE --no-indent --no-print [<option>] <string>
  LOG ()    { MESSAGE --no-indent --no-print $@; }

  # usage: NOTICE <string>
  # desc: alias of MESSAGE --no-indent <string> prefixed by "NOTICE: "
  NOTICE () { MESSAGE --no-indent "${__MSG_INDENT__:-}NOTICE: $*"; }

  # usage: BR
  # desc: print a break return
  BR ()     { MESSAGE --no-log --no-break --no-indent  $'\n'; }

  # usage: ERROR <string>
  # desc: close the current DOTHIS if needed and print a message prefixed by "ERROR: "
  ERROR () {
    if [ "${__IN_DOTHIS__:-}" = 'true' ]; then
      MESSAGE --no-date --no-indent -- 'Err';
      __IN_DOTHIS__='false'
    fi
    MESSAGE --no-indent "${__MSG_INDENT__:-}ERROR: $*"
  }

  # usage: WARNING <string>
  # desc: close the current DOTHIS if needed and print a message prefixed by "WARNING: "
  WARNING () {
    if [ "${__IN_DOTHIS__:-}" = 'true' ]; then
      MESSAGE --no-date --no-indent -- 'Warn';
      __IN_DOTHIS__='false'
    fi
    MESSAGE --no-indent "${__MSG_INDENT__:-}WARNING: $*"
  }

  # usage: DOTHIS <string>
  # desc: print "- <string> ... "
  DOTHIS () {
    MESSAGE --no-break --no-indent -- "${__MSG_INDENT__:-}- $* ... "
    __IN_DOTHIS__='true'
  }

  # usage: OK
  # desc: close the current DOTHIS and print "OK"
  OK () {
    [ "${__IN_DOTHIS__:-}" = 'true' ] && MESSAGE --no-date --no-indent -- 'OK'
    __IN_DOTHIS__='false'
  }

  # usage: KO <message>
  # desc: close the current DOTHIS and print "KO" and call FATAL with <message>
  KO () {
    if [ "${__IN_DOTHIS__:-}" = 'true' ]; then
      MESSAGE --no-date --no-indent -- 'KO';
      __IN_DOTHIS__='false'
    fi
    FATAL "$*"
  }

  # usage: ROLLBACK
  # desc: by default, it's done nothing. Its purpose is to be
  #       override by the parent script
  ROLLBACK () { echo >/dev/null; }

  # usage: FATAL <error message>
  # desc: prefix message with "FATAL:" and call MESSAGE().
  #       Then it call ROLLBACK() and exit(1).
  # note: close DOTHIS if needed
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


fi # end of: if [ "${__LIB_MESSAGE__}" != 'Loaded' ]; then
