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
# __LIB_MAIL__ : 'Loaded' when the lib is 'source'd
# __MAIL_FILE__ : path the log file in which messages will be stored
#
# Methods ====================================================================
#
# MAIL_CREATE()
#   usage: MAIL_CREATE [ <mail_filename> ]
#   desc: creates a file to store the mail content.
#   arguments:
#     <mail_filename> : mail file to use, which MUST exist
#   note: if no file is given, a random-named file is created in /tmp
#
# MAIL_GET_FILE()
#   usage: MAIL_GET_FILE
#   desc: return the content of __MAIL_FILE__, ie the current mail file used
#
# MAIL_SET_FILE()
#   usage: MAIL_SET_FILE <mail_filename>
#   desc: set the current mail file to use, ie the content of __MAIL_FILE__
#   arguments:
#     <mail_filename> : mail file to use, which MUST exist
#
# MAIL_APPEND()
#   usage: MAIL_APPEND [ <mail_filename> ] <message>
#   desc: adds <message> to the mail file
#   arguments:
#     <mail_filename> : mail file to use (optional)
#     <message> : the message to add to the mail content.
#   note: if <mail_filename> is not given, use __MAIL_FILE__ instead
#
# MAIL_PRINT()
#   usage: MAIL_PRINT [ <mail_filename> ]
#   desc: prints the content of the mail to send
#   arguments:
#     <mail_filename> : mail file to use (optional)
#   note: if <mail_filename> is not given, use __MAIL_FILE__ instead
#
# MAIL_SEND()
#   usage: MAIL_SEND [ <mail_filename> ] <subject> <addresses>
#   desc: use default system mail options to send the mail
#   arguments:
#     <mail_filename> : mail file to use (optional)
#     <subject> : subject of the mail.
#     <addresse> : A commat separated list of mail addresses.
#   note: if <mail_filename> is not given, use __MAIL_FILE__ instead
#   note: for more specific usages of the mail command use
#         MAIL_PRINT | mail [options] ...
# ----------------------------------------------------------------------------

# don't load several times this file
if [ "${__LIB_MAIL__:-}" != 'Loaded' ]; then
  __LIB_MAIL__='Loaded'

  # IMPORTANT: Don't set those variables directly in the parent script
  __MAIL_FILE__=''

  # Load common lib
  if [ "${__LIB_MESSAGE__:-}" != "Loaded" ]; then
    if [ -r ./message.lib.sh ]; then
      . ./message.lib.sh
    else
      echo "ERROR: Unable to load ./message.lib.sh library"
      exit 2
    fi
  fi
  if [ "${__LIB_RANDOM__:-}" != "Loaded" ]; then
    if [ -r ./random.lib.sh ]; then
      . ./random.lib.sh
    else
      echo "ERROR: Unable to load ./random.lib.sh library"
      exit 2
    fi
  fi

  # ----------------------------------------------------------------------------

  MAIL_CREATE () {
    local mail_file=
    [ $# -eq 0 ] && mail_file="/tmp/mail.$(RANDOM)" || mail_file="$1"

    [ -z "${mail_file}" ] && FATAL "Can't create a mail with empty filename"

    touch "${mail_file}" 2>/dev/null
    if [ $? -ne 0 -o ! -w "${mail_file}" ]; then
      FATAL "MAIL_CREATE can't create temp mail file ${mail_file}"
      return 1;
    fi

    __MAIL_FILE__="${mail_file}"
    LOG "MAIL_CREATE: ${__MAIL_FILE__}"
    return 0;
  }

  # ----------------------------------------------------------------------------

  MAIL_GET_FILE () {
    echo "${__MAIL_FILE__}";
    return 0;
  }

  MAIL_SET_FILE () {
    [ $# -ne 1  ] && FATAL "MAIL_SET_FILE: Bad argument(s)"
    [ ! -w "$1" ] && FATAL "MAIL_SET_FILE: $1 is not writable"
    __MAIL_FILE__="$1"
    return 0;
  }

  # ----------------------------------------------------------------------------

  MAIL_APPEND () {
    local mail_file="${__MAIL_FILE__:-}"

    [ $# -ne 1 -a $# -ne 2 ] && FATAL "MAIL_APPEND: Bad argument(s)"
    if [ $# -eq 2 ]; then
      mail_file="$1"; shift
    fi

    [ -z "${mail_file}" ] && FATAL "MAIL_APPEND: no mail file was setup"
    [ -w "${mail_file}" ] || FATAL "MAIL_APPEND: can't write to mail file"

    echo "$*" >> "${mail_file}"
    LOG "MAIL_APPEND[${mail_file}]> $*"
    return 0;
  }

  # ----------------------------------------------------------------------------

  MAIL_PRINT () {
    local mail_file=
    [ $# -eq 1 ] && mail_file="$1" || mail_file="${__MAIL_FILE__:-}"

    [ -z "${mail_file}" ] && FATAL "MAIL_PRINT: no mail file was setup"
    [ -r "${mail_file}" ] || FATAL "MAIL_PRINT: can't read mail file"

    cat "${mail_file}"
    return 0;
  }

  # ----------------------------------------------------------------------------

  MAIL_SEND () {
    local mail_file="${__MAIL_FILE__:-}"
    [ $# -ne 2 -a $# -ne 3 ] && FATAL "MAIL_SEND: Bad argument(s)"
    if [ $# -eq 3 ]; then
      mail_file="$1"; shift
    fi

    [ -z "${mail_file}" ] && FATAL "MAIL_SEND: no mail file was setup"

    if [ ! -s "${mail_file}" ]; then
      NOTICE "No modification noticed. Prepared e-mail will not be sent."
      LOG "MAIL_SEND[${mail_file}] Not sent, as file is empty"
      rm -f "${mail_file}"
      return 2;
    fi

    which mail >/dev/null
    if [ $? -eq 0 ]; then
      MAIL_PRINT | mail -s "$1" "$2"
      rm -f "${mail_file}"
      LOG "MAIL_SEND[${mail_file}] Mail sent"
    else
      NOTICE "'mail' command can't be found. The mail wasn't sent. See '${mail_file}' file."
      LOG "MAIL_SEND[${mail_file}] Not sent, as 'mail' command wasn't found."
    fi
    return 0;
  }

fi
