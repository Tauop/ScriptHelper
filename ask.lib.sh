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
# __LIB_ASK__ : 'Loaded' when the lib is 'source'd
# __ANSWER_LOG_FILE__ : filepath of the file in which user's answer, get with
#                       ASK(), will be recorded.
# __AUTOANSWER_FILE__ : filepath of the file from which answer will be taken
# __AUTOANSWER_FP__ : file pointer, which determine the last line number of
#                     the file __AUTOANSWER_FILE__ which has been read
#
# Methods ====================================================================
#
# ASK_SET_ANSWER_LOG_FILE()
#   usage: ASK_SET_ANSWER_LOG_FILE <file>
#   desc: create a log file, which will be used to store all user answers,
#         one per line
#   arguments:
#     <file> : path to the file in which to log answers.
#   note: the <file> will be deleted before use
#
# ASK_SET_AUTOANSWER_FILE()
#   usage: ASK_SET_AUTOANSWER_FILE <file>
#   desc: set a file which contains previously recorded user's answers,
#         ie a file which contain a answer per line. Each line of this
#         file will be returned at each call of ASK().
#   arguments:
#     <file> : path to the file from which answers will be read
#   note: Call of HIT_TO_CONTINUE() will have no interactive effect, if
#         ASK_SET_AUTOANSWER_FILE has been used.
#
# HIT_TO_CONTINUE()
#   desc: display a message to the user, which ask to press ENTER to continue
#
# ASK_ENABLE_READLINE()
#   usage: ASK_ENABLE_READLINE [ <options> ]
#   desc: enable readline module, used by read shell builtin, if we are in zsh or bash
#   arguments:
#      <options> =
#        --force : force usage of read -e
#        --history-file : set history file to use
#   note: if --history-file is not specified, history builtin will use HISTFILE env var
#
# ASK_DISABLE_READLINE()
#   usage: ASK_DISABLE_READLINE
#   desc: disable readline module, used by read shell builtin
#
# ASK()
#   usage: ASK [ <options> ] <variable> [ "<text>" ] [ <default value> ] [ "<error>" ]
#   desc: Ask a question to the user, get the user response and store it in
#         the variable which name is stored in <variable>.
#         Control can be made on user answer, and ASK() repeat question if
#         the user answer is not valid.
#         Display message and user answer are logged, if possible.
#   arguments:
#      <options> =
#        --no-print : all call of MESSAGE() won't print anything
#        --no-echo : Don't print what the user type
#        --with-break : make a break-line after the question printing.
#        --pass : implies --no-print + don't log clear text password
#        --number : The user answer must be a number
#        --yesno : The asked question is a yes/no question.
#                  Control the user answer.
#        --allow-empty : user can hit enter, which reply to the question.
#                        In this case, the answer will be a empty string
#      <variable> = The name of the variable in which we have to store
#                   the user response.
#      <text> = The question to ask to the user.
#      <default value> = value of the answer of the user, when he only
#                        press ENTER. Set this variable to empty string
#                        when you don't want default value.
#      <error> = The custom error message displayed to the user if its
#                answer is not valid.
#                default: "Invalid answer."
#   note: format options are ignored if a __AUTOANSWER_FILE__ was set
# ----------------------------------------------------------------------------

# don't load several times this file
if [ "${__LIB_ASK__:-}" != 'Loaded' ]; then
  __LIB_ASK__='Loaded'

  # IMPORTANT: Don't set those variables directly in the parent script
  __AUTOANSWER_FILE__=''
  __AUTOANSWER_FP__=0
  __ANSWER_LOG_FILE__=''
  __USE_READLINE__='false'

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

  HIT_TO_CONTINUE () {
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
  ASK_SET_AUTOANSWER_FILE () {
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
  ASK_SET_ANSWER_LOG_FILE () {
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
  ASK_ENABLE_READLINE () {
    local shell=${SHELL##*/} do_force='false'

    while true; do
      [ $# -eq 0 ] && break
      case "$1" in
        --force        ) do_force='true'; shift ;;
        --history-file ) shift; [ $# -ge 1 ] && HISTFILE="$1"; shift ;;
        --*            ) shift        ;;
        --             ) shift; break ;;
        *              ) break        ;;
      esac
    done

    if [    "${do_force}" = 'true' \
         -o "${shell}" = 'bash'    \
         -o "${shell}" = 'zsh' ]; then
      set +o emacs
      set +o history
      history -r
      __USE_READLINE__='true'
    fi
  }

  ASK_DISABLE_READLINE () {
    set -o emacs
    set -o history
    __USE_READLINE__='false'
  }

  # ----------------------------------------------------------------------------
  ASK () {
    local question= variable= default= error=
    local answer= read_opt='' check='' allow_empty= message_opt=
    local do_break='false' do_pass='false' no_print='false' no_echo='false'

    # parse argument
    while true; do
      [ $# -eq 0 ] && break
      case "$1" in
        # display options
        --no-print      ) shift; no_print='true'    ;;
        --no-echo       ) shift; no_echo='true'     ;;
        --with-break    ) shift; do_break='true'    ;;
        --pass          ) shift; do_pass='true'     ;;

        # answer format options
        --number        ) shift; check='number'     ;;
        --yesno         ) shift; check='yesno'      ;;
        --allow-empty   ) shift; allow_empty='true' ;;

        --*             ) shift ;; # ignore
        *               ) break ;;
      esac
    done

    # interprete some options
    [ "${do_break}" = 'false' ] && message_opt="${message_opt} --no-break "
    [ "${no_print}" = 'true'  ] && message_opt="${message_opt} --no-print"

    [ "${no_echo}" = 'true' -o "${do_pass}" = 'true' ] && read_opt="${read_opt} -s "
    [ "${__USE_READLINE__}" = 'true' ] && read_opt="${read_opt} -e "

    # parse trailing arguments
    # note: the while is just a workaround, as bash has no GOTO statement
    while true ; do
      [ $# -gt 0 ] && variable="$1" || FATAL "ASK: Missing argument (question)"
      [ $# -gt 1 ] && question="$2" || break
      [ $# -gt 2 ] && default="$3"  || break
      [ $# -gt 3 ] && error="$4"    || break
      break
    done

    [ -n "${question}" -a "${question}" = "${question%  }" ] && question="${question}  "

    # reset global variable
    eval "${variable}=''"

    if [ -f "${__AUTOANSWER_FILE__}" ]; then
      # automatic mode
      MESSAGE --no-log ${message_opt} "${question}"
      [ "${do_break}" = 'true' ] && MESSAGE ${message_opt} --no-log --no-break $''

      __AUTOANSWER_FP__=$((__AUTOANSWER_FP__ + 1 ))
      answer=$( sed -n "${__AUTOANSWER_FP__}p" "${__AUTOANSWER_FILE__}" )

      [ -z "${answer}" -a -n "${default}" ] && answer="${default}"
      [ "${no_echo}" = 'false' -a "${do_pass}" = 'false' ] && MESSAGE --no-break --no-log "${answer}"
      [ "${no_print}" = 'false' ] && BR
    else
      # interactive mode
      if [ "${no_print}" = 'false' ]; then
        question="${__MSG_INDENT__}${question}"
        [ "${do_break}" = 'true'  ] && question=${question}$'\n'${__MSG_INDENT__}
        read_opt="${read_opt} -p '${question}' "
      fi

      while eval "read ${read_opt} answer"; do
        # deal with default, when user only press ENTER
        if [ -z "${answer}" ]; then
          if [ -n "${default}" ]; then
            answer="${default}"
            break;
          fi
          [ "${allow_empty}" = 'true' ] && break;
        else
          # delete useless space
          answer=$( echo "${answer}" | sed -e 's/^ *//;s/ *$//;' )

          # check user response
          case "${check}" in
            "yesno" )
                  answer=$( echo "${answer}" | tr '[:lower:]' '[:upper:]' )
                  if [ "${answer}" = 'Y'   \
                    -o "${answer}" = 'YES' \
                    -o "${answer}" = 'N'   \
                    -o "${answer}" = 'NO' ]; then
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

        # NOTE: with --pass, no \n is printed out to the STDOUT, due to '-s' option of 'read'
        [ "${read_opt/-s/}" != "${read_opt}" -a "${no_print}" = 'false' ] && BR

        # display error
        # FIXME: Ugly. Don't use ERROR() alias, as it doesn't support --no-log options :/
        if [ -n "${error}" ]; then
          MESSAGE --no-log --no-indent "${__MSG_INDENT__}ERROR: ${error}"
        else
          MESSAGE --no-log --no-indent "${__MSG_INDENT__}ERROR: invalid answer"
        fi
      done # enf of while read
    fi

    if [ "${do_pass}" = 'true' ]; then
      LOG "${question}  => ${answer//?/#}"
    else
      LOG "${question}  => ${answer}"
      [ "${__USE_READLINE__}" ] && history -s "${answer}"
    fi

    # NOTE: with --pass, no \n is printed out to the STDOUT, due to '-s' option of 'read'
    [ "${read_opt/-s/}" != "${read_opt}" -a "${no_print}" = 'false' ] && BR

    [ -n "${__ANSWER_LOG_FILE__}" ] &&  echo "${answer}" >> "${__ANSWER_LOG_FILE__}"
    eval "${variable}=\"${answer}\"";
  }

fi # enf of: if [ "${__LIB_ASK__}" = 'Loaded' ]; then
