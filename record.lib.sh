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
# This is a bash library for record tty session
#
# Global variables ===========================================================
# IMPORTANT: Please to write to those variables
# __LIB_RECORD__ : 'Loaded' when the lib is 'source'd
# __RECORD_FILE__ : filepath basename for the record files
# ----------------------------------------------------------------------------

if [ "${__LIB_RECORD__:-}" != 'Loaded' ]; then
  __LIB_RECORD__='Loaded'
  __RECORD_FILE__=

  # Load dependencies
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

  load __LIB_RANDOM__ "${SCRIPT_HELPER_DIRECTORY}/random.lib.sh"

  # ----------------------------------------------------------------------------

  # usage: RECORD_START [<options>] [<command>]
  # desc: alias of RECORD()
  RECORD_START () { RECORD $*; }

  # usage: RECORD [<options>] [<command>]
  # desc: Start recording the terminal session
  # options: --file <filename>: specify the basename of the recorded files
  # note: if no <command> is given, enter in interactive mode (recorded shell)
  # note: if --file option is not used, generate a random file name which can be get
  #       with RECORD_GET_TIME_FILE() and RECORD_GET_DATA_FILE()
  RECORD () {
    # start a new record file
    __RECORD_FILE__=

    while true ; do
      [ $# -eq 0 ] && break;
      case "$1" in
        --file ) shift; [ $# -ne 0 ] && __RECORD_FILE__="$1"; shift; break ;;
        --*    ) shift ;;
        *      ) break ;;
      esac
    done

    [ -z "${__RECORD_FILE__}" ] && __RECORD_FILE__="/tmp/record.$(RANDOM)"

    if [ $# -eq 0 ]; then
      script -q -t 2>"${__RECORD_FILE__}.time" "${__RECORD_FILE__}.data"
    else
      script -q -c "$*" -t 2>"${__RECORD_FILE__}.time" "${__RECORD_FILE__}.data"
    fi

    # workaround to display all line recorded in *.data file !
    # in fact, scriptreplay doesn't want to display 'exit', but it's create some mistakes.
    printf '0.000000 1\n' >> "${__RECORD_FILE__}.time"
  }

  # usage: RECORD_GET_TIME_FILE
  # desc: ECho-return the file path of recorded session (timestamp information)
  RECORD_GET_TIME_FILE () { printf '%s' "${__RECORD_FILE__}.time"; }
  # usage: RECORD_GET_DATA_FILE
  # desc: Echo-return the file path of recorded session (data information)
  RECORD_GET_DATA_FILE () { printf '%s' "${__RECORD_FILE__}.data"; }

  # usage: RECORD_REALTIME [<options>]
  # desc: alias of RECORD_TIME --real
  # desc: compute the total time of a recorded session
  # options: --file <filename>: specify the basename of the recorded files
  # note: if --file option is not used, use the last file used with RECORD()/RECORD_PLAY()
  RECORD_REALTIME () { RECORD_TIME --real $* ; }

  # usage: RECORD_TIME [<options>]
  # desc: compute the total of time needed to replay the recorded session
  # options: --file <filename>: specify the basename of the recorded files
  #          --real : compute the "real" time of the recorded session
  # note: if --file option is not used, use the last file used with RECORD()/RECORD_PLAY()
  RECORD_TIME () {
    local record_file= real_time='false' time_file= total_time= speed_factor=

    while true ; do
      [ $# -eq 0 ] && break;
      case "$1" in
        --file ) shift; [ $# -ne 0 ] && record_file="$1"; shift ;;
        --real ) real_time='true'; shift;; 
        --*    ) shift ;;
        *      ) break ;;
      esac
    done

    [ -z "${record_file}" ] && record_file="${__RECORD_FILE__}"
    record_file="${record_file}.time"

    if [ ! -f "${record_file}" ]; then
      printf "ERROR: can't find ${record_file}.time\n"
      return 1
    fi

    [ $# -eq 1 ] && speed_factor="$1" || speed_factor=1

    total_time=0
    if [ "${real_time}" = 'true' ]; then
      printf 'scale=6\n';
      printf '(';
      < "${record_file}" cut -d' ' -f1 | tr $'\n' '+';
      printf '%s\n' "0)/${speed_factor}"
    else
      printf 'scale=6\n';
      printf '(';
      while read time nb_char; do
        [ "$( expr "${nb_char}" '<' '100' )" = '1' ] && time="0.${time#*.}"
        [ "$( expr "${time%.*}" '>' '1'   )" = '1' ] && time="1.${time#*.}"
        printf '%s' "${time}+"
      done < "${record_file}"
      printf '%s\n' "0)/${speed_factor}"
    fi | bc

    return 0;
  }

  # usage: RECORD_PLAY [<options>]
  # desc: Replay a recorded sessions
  # options: --file <filename>: specify the basename of the recorded files
  #          --real: replay session in real time (can spend a long time)
  # note: if no --file option is used, get the last recorded session files
  RECORD_PLAY () {
    local record_file= real_time='false' time_file= speed_factor= time= nb_char=

    while true ; do
      [ $# -eq 0 ] && break;
      case "$1" in
        --file ) shift; [ $# -ne 0 ] && record_file="$1"; shift ;;
        --real ) real_time='true'; shift ;;
        --*    ) shift ;;
        *      ) break ;;
      esac
    done

    [ -z "${record_file}" ] && record_file="${__RECORD_FILE__}"
    if [ ! -f "${record_file}.time" -o ! -f "${record_file}.data" ]; then
      printf "ERROR: can't find ${record_file}.time or ${record_file}.data\n"
      return 1
    fi

    [ $# -eq 1 ] && speed_factor="$1" || speed_factor=1

    if [ "${real_time}" = 'false' ]; then
      time_file="/tmp/time.$(RANDOM)"
      while read time nb_char; do
        [ "$( expr "${nb_char}" '<' '100' )" = '1' ] && time="0.${time#*.}"
        [ "$( expr "${time%.*}" '>' '1'   )" = '1' ] && time="1.${time#*.}"
        printf '%s\n' "${time} ${nb_char}"
      done < "${record_file}.time" > "${time_file}"
    else
      time_file="${record_file}.time"
    fi

    scriptreplay "${time_file}" "${record_file}.data" "${speed_factor}"

    [ -z "${time_file}" -a -f "${time_file}" ] && rm -f "${time_file}"
    return 0
  }

fi # end of: if [ "${__LIB_RECORD__:-}" != 'Loaded' ]; then
