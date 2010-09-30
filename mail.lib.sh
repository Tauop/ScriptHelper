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
# __MAIL_ID__ : the current session number
#
# Methods ====================================================================
#
# MAIL_CREATE()
#   usage: MAIL_CREATE <file_name>
#   desc: creates a file to store the mail content.
#   arguments:
#     <file_name> : the name of the file. If it contains a % symbol,
#                   it will be replaced by a random number.
#                   ex: /tmp/mail_lib_%
#
# MAIL_APPEND()
#   usage: MAIL_APPEND <message>
#   desc: adds <message> to the mail file
#   arguments:
#     <message> : the message to add to the mail content.
#
# MAIL_PRINT()
#   usage: MAIL_PRINT
#   desc: prints the content of the mail to send
#
# MAIL_SEND()
#   usage: MAIL_SEND <subject> <addresse> ...
#   desc: use default system mail options to send the mail
#   arguments:
#     <subject> : subject of the mail.
#     <addresse> ... : A space separated list of mail addresses.
#   note: for more specific usages of the mail command use
#         MAIL_PRINT | mail [options] ...
# ----------------------------------------------------------------------------

# don't load several times this file
if [ "${__LIB_MAIL__:-}" != 'Loaded' ]; then
  __LIB_MAIL__='Loaded'

  # IMPORTANT: Don't set those variables directly in the parent script
  __MAIL_FILE__=''
  __MAIL_ID__=0

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

  MAIL_CREATE() {
    [ -z "$1" ] && KO "MAIL_CREATE is called without argument !"

    __MAIL_ID__="${RANDOM}"
    __MAIL_FILE__=$( echo "$1" | sed "s/%/${__MAIL_ID__}/g" )

    touch ${__MAIL_FILE__} \
      || KO "MAIL_CREATE can't create temp mail file ${__MAIL_FILE__}"
  }

  # ----------------------------------------------------------------------------
  MAIL_APPEND() {
    [ -z "$1" ] && KO "MAIL_APPEND is called without argument !"

    while [ $# -ne 0 ]; do
      echo "$1" >> ${__MAIL_FILE__}
      shift
    done
  }

  # ----------------------------------------------------------------------------
  MAIL_PRINT() {
    [ -s ${__MAIL_FILE__} ] && cat ${__MAIL_FILE__}
  }

  # ----------------------------------------------------------------------------
  MAIL_SEND() {
    [ -z "$1" ] && KO "MAIL_SEND is called without argument !"
    [ $# -lt 2 ] && KO "MAIL_SEND: not enough arguments !"

    subject="$1"
    shift
    mails=$( echo "$*" | tr ' ' ',' )

    MAIL_PRINT | mail -s "$subject" "$mails"
  }
fi
