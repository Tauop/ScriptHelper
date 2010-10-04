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
#   note: if called without --mail-file, try to use the last mail file used, ie
#         use __MAIL_FILE__ filename.
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

  # ----------------------------------------------------------------------------

  MAIL_CREATE () {
    [ $# -eq 0 ] && __MAIL_FILE__="/tmp/mail.${RANDOM}"

    touch ${__MAIL_FILE__} \
      || KO "MAIL_CREATE can't create temp mail file ${__MAIL_FILE__}"
  }

  # ----------------------------------------------------------------------------

  MAIL_GET_FILE () {
    echo "${__MAIL_FILE__:-}";
    return 0;
  }

  MAIL_SET_FILE () {
    [ $# -ne 1  ] && KO "MAIL_SET_FILE: Bad argument(s)"
    [ ! -w "$1" ] && KO "MAIL_SET_FILE: $1 is not writable"
    __MAIL_FILE__="$1"
    return 0;
  }

  # ----------------------------------------------------------------------------

  MAIL_APPEND () {
    local mail_file=

    [ $# -ne 1 -a $# -ne 2 ] && KO "MAIL_APPEND: Bad argument(s)"
    [ $# -eq 2 ] && mail_file="$1" || mail_file="${__MAIL_FILE__:-}"

    [ -z "${mail_file}" ] && KO "MAIL_APPEND: no mail file was setup"
    [ -w "${mail_file}" ] || KO "MAIL_APPEND: can't write to mail file"

    echo "$*" >> "${__MAIL_FILE__}"
    return 0;
  }

  # ----------------------------------------------------------------------------

  MAIL_PRINT () {
    local mail_file=
    [ $# -eq 1 ] && mail_file="$1" || mail_file="${__MAIL_FILE__:-}"

    [ -z "${mail_file}" ] && KO "MAIL_APPEND: no mail file was setup"
    [ -r "${mail_file}" ] || KO "MAIL_APPEND: can't write to mail file"

    cat "${__MAIL_FILE__}"
    return 0;
  }

  # ----------------------------------------------------------------------------

  MAIL_SEND () {
    local mail_file=
    [ $# -ne 2 -a $# -ne 3 ] && KO "MAIL_SEND: Bad argument(s)"
    [ $# -eq 3 ] && ( mail_file="$1"; shift ) || mail_file="${__MAIL_FILE__:-}"

    [ -z "${mail_file}" ] && KO "MAIL_APPEND: no mail file was setup"

    if [ ! -s "${mail_file}" ]; then
      NOTICE "No modification noticed. Prepared e-mail will not be sent."
      rm -f "${mail_file}"
      return 2;
    fi

    MAIL_PRINT | mail -s "$1" "$2"
    rm -f "${mail_file}"
    return $?
  }

fi
