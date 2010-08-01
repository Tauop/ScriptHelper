#
# Copyright (c) 2010 Linagora
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
# __LIB_ASK__ : 'Loaded' when the lib is 'source'd
#
# Methods ====================================================================
#
# HIT_TO_CONTINUE()
#   desc: display a message to the user, which ask to press ENTER to continue
#
# ASK()
#   desc: Ask a question to the user, get the user response and store it in
#         the variable which name is stored in <variable>.
#         Control can be made on user answer, and ASK() repeat question if
#         the user answer is not valid.
#         Display message and user answer are logged, if possible.
#   usage: ASK [ <options> ] <variable> [ "<text>" ] [ <default value> ] [ "<error>" ]
#   arguments: 
#      <options> =
#        --no-print : Don't print what the user type
#        --number : The user answer must be a number
#        --yesno : The asked question is a yes/no question.
#                  Control the user answer.
#        --pass : implies --no-print + don't log clear text password
#      <variable> = The name of the variable in which we have to store
#                   the user response.
#      <text> = The question to ask to the user.
#      <default value> = value of the answer of the user, when he only
#                        press ENTER. Set this variable to empty string
#                        when you don't want default value.
#      <error> = The custom error message displayed to the user if its
#                answer is not valid.
#                default: "Invalid answer."
#
# ----------------------------------------------------------------------------

# -f Disable pathname expansion.
# -u Unset variables
set -fu

# don't load several times this file
if [ "${__LIB_ASK__-}" != 'Loaded' ]; then
  __LIB_ASK__='Loaded'

  # IMPORTANT: Don't set those variables directly in the parent script
  __AUTOANSWER_FILE__=''
  __AUTOANSWER_FP__=0
  __ANSWER_LOG_FILE__=''

  # Load common lib
  if [ "${__LIB_FUNCTIONS__-}" != "Loaded" ]; then
    if [ -r ./functions.lib.sh ]; then
      source ./functions.lib.sh
    else
      echo "ERROR: Unable to load ./functions.lib.sh library"
      exit 2
    fi
  fi

  # ----------------------------------------------------------------------------

  HIT_TO_CONTINUE() {
    if [ ! -f "${__AUTOANSWER_FILE__}" ]; then
      MESSAGE --no-log ""
      MESSAGE --no-log "Press ENTER to continue, or CTRL+C to exit"
      MESSAGE --no-log ""
      read
    else
      MESSAGE --no-log ''
    fi
    LOG "User press ENTER to continue"
  }

  # ----------------------------------------------------------------------------
  ASK_SET_AUTOANSWER_FILE() {
    [ -z "$1" ] && KO "ASK_SET_ANSWER_FILE is called without argument !"
    [ $# -gt 1 ] && KO "ASK_SET_ANSWER_FILE: too much arguments !"

    __AUTOANSWER_FILE__="$1"
    __AUTOANSWER_FP__=0
    if [ ! -r "${__AUTOANSWER_FILE__}" ]; then
      __AUTOANSWER_FILE__=''
      KO "${__AUTOANSWER_FILE__} can't be read"
    fi
  }

  # ----------------------------------------------------------------------------
  ASK_SET_ANSWER_LOG_FILE() {
    [ -z "$1" ] && KO "ASK_SET_ANSWER_FILE is called without argument !"
    [ $# -gt 1 ] && KO "ASK_SET_ANSWER_FILE: too much arguments !"

    __ANSWER_LOG_FILE__="$1"
    if [ -f "${__ANSWER_LOG_FILE__}" ]; then
      rm -f "${__ANSWER_LOG_FILE__}" \
        || KO "Unable to delete existing answer log file '${__ANSWER_LOG_FILE__}'."
    fi

    touch "${__ANSWER_LOG_FILE__}" \
      || KO "Unable to create answer log file '${__ANSWER_LOG_FILE__}'."
  }

  # ----------------------------------------------------------------------------
  ASK() {
    local question= variable= default= error=
    local answer= read_opt='' check='' allow_empty= message_opt=
    local do_break='false' do_pass='false' no_print='false' no_echo='false'

    # parse argument
    while true; do
      [ $# -eq 0 ] && break
      case "$1" in
        --no-print      ) shift; no_print='true'    ;;
        --no-echo       ) shift; no_echo='true'     ;;
        --number        ) shift; check='number'     ;;
        --yesno         ) shift; check='yesno'      ;;
        --allow-empty   ) shift; allow_empty='true' ;;
        --with-break    ) shift; do_break='true'    ;;
        --pass          ) shift; do_pass='true'     ;;
        --*             ) shift ;; # ignore
        *               ) break ;;
      esac
    done
    [ "${do_break}" = 'false' ] && message_opt="${message_opt} --no-break "
    [ "${no_print}" = 'true'  ] && message_opt="${message_opt} --no-print"

    [ "${no_echo}" = 'true' -o "${do_pass}" = 'true' ] && read_opt="${read_opt} -s"

    # parse trailing arguments
    # note: the while is just a workaround, as bash has no GOTO statement
    while true ; do
      [ $# -gt 0 ] && variable="$1" || FATAL "ASK: Missing argument (question)"
      [ $# -gt 1 ] && question="$2" || break
      [ $# -gt 2 ] && default="$3"  || break
      [ $# -gt 3 ] && error="$4"    || break
      break
    done

    # reset global variable
    eval "${variable}=''"

    MESSAGE --no-log ${message_opt} "${question}  "

    if [ -f "${__AUTOANSWER_FILE__}" ]; then
      # automatic mode
      __AUTOANSWER_FP__=$((__AUTOANSWER_FP__ + 1 ))
      answer=$( sed -n "${__AUTOANSWER_FP__}p" "${__AUTOANSWER_FILE__}" )
      [ -z "${answer}" -a -n "${default}" ] && answer="${default}"
      MESSAGE ${message_opt} --no-log ''
    else
      # interactive mode
      while read ${read_opt} answer; do
        # deal with default, when user only press ENTER
        if [ -z "${answer}" ]; then
          if [ -n "${default}" ]; then
            answer="${default}"
            break;
          fi
          [ "${allow_empty}" = 'true' ] && break;
        else
          # delete useless space
          answer=`echo "${answer}" | sed -e 's/^ *//;s/ *$//;'`

          # check user response
          case "${check}" in
            "yesno" )
                  if [ "${answer^^}" = 'Y'   \
                    -o "${answer^^}" = 'YES' \
                    -o "${answer^^}" = 'N'   \
                    -o "${answer^^}" = 'NO' ]; then
                    answer=${answer^^}           # uppercase
                    answer=${answer:0:1} # keep the first char
                    break;
                  fi
              ;; # enf of "yesno"
            "number" )
                  echo "${answer}" | grep '^[0-9]*$' >/dev/null 2>/dev/null
                  [ $? -eq 0 ] && break;
                ;; # end of "number"
            * ) break  ;;
          esac
        fi

        # NOTE: with --no-print, no \n is printed out to the STDOUT.
        #       This test has to be changed if there is more read options
        #       deal with this script.
        [ -n "${read_opt}" ] && MESSAGE --no-log ""

        # display error
        if [ -n "${error}" ]; then
          ERROR "${error}"
        else
          ERROR "invalid answer"
        fi

        # display the question again
        MESSAGE --no-log ${message_opt} "${question}  "

      done # enf of while read
    fi

    if [ "${do_pass}" = 'true' ]; then
      LOG "${question}  => ${answer//?/#}"
    else
      LOG "${question}  => ${answer}"
    fi

    # NOTE: with --no-print, no \n is printed out to the STDOUT.
    #       This test has to be changed if there is more read options
    #       deal with this script.
    [ -n "${read_opt}" ] && MESSAGE --no-log ""

    [ -n "${__ANSWER_LOG_FILE__}" ] &&  echo "${answer}" >> "${__ANSWER_LOG_FILE__}"
    eval "${variable}=\"${answer}\"";
  }

fi # enf of: if [ "${__LIB_ASK__}" = 'Loaded' ]; then
