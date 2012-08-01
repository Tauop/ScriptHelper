#
# Copyright (c) 2010-2011 Linagora
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
# This lib helps to build an help interface for CLI lib.
# The goal is to generate help thanks to the command there is in code
#
# the CLI library call private_CLI_SAVE_HELP() to add help content
#
# Global variables ===========================================================
# __LIB_CLI_HELP__ : 'Loaded' when the lib is 'source'd
# __CLI_BUILD_HELP__ : 'true' if we want to generate help automaticaly.
#                       default: false
# __CLI_HELP_FILE__ : Filepath of the cache file for help content
# __CLI_GET_HELP__ : the function to used to get help content.
#                    (can be set with CLI_REGISTER_HELP)
# __CLI_DISPLAY_HELP__ : the function to use to display help sections.
#                        (can be set with CLI_REGISTER_HELP)
# __CLI_DISPLAY_HELP_FOR__ : the function to use to display help content.
#                            (can be set with CLI_REGISTER_HELP)
# ----------------------------------------------------------------------------

if [ "${__LIB_CLI_HELP__:-}" != 'Loaded' ]; then
  __LIB_CLI_HELP__='Loaded';

  __CLI_BUILD_HELP__='false'
  __CLI_HELP_FILE__=
  __CLI_GET_HELP__='private_CLI_DEFAULT_GET_HELP'
  __CLI_DISPLAY_HELP__='private_CLI_DEFAULT_DISPLAY_HELP'
  __CLI_DISPLAY_HELP_FOR__='private_CLI_DEFAULT_DISPLAY_HELP_FOR'

  # load dependencies
  load() {
    local var= value= file=

    var="$1"; file="$2"
    value=$( eval "printf \"%s\" \"\${${var}:-}\"" )

    [ -n "${value}" ] && return 1;
    if [ -f "${file}" ]; then
      . "${file}"
    else
      printf "ERROR: Unable to load ${file}"
      exit 2
    fi
    return 0;
  }

  # Load configuration file
  load SCRIPT_HELPER_DIRECTORY /etc/ScriptHelper.conf
  SCRIPT_HELPER_DIRECTORY="${SCRIPT_HELPER_DIRECTORY:-}"
  SCRIPT_HELPER_DIRECTORY="${SCRIPT_HELPER_DIRECTORY%%/}"

  load __LIB_MESSAGE__ "${SCRIPT_HELPER_DIRECTORY}/cli.lib.sh"

  # --------------------------------------------------------------------------

  # usage: CLI_REGISTER_HELP <file> [<get_help_func> [ <display_help_func> [ <display_help_for_func> ] ] ]
  # desc: register a function to call to get help information for a CLI command, and the
  #       cache file where to save help information.
  # note: if <get_help_func> is not given, use private_CLI_DEFAULT_GET_HELP
  # note: if <display_help_func> is not given, use private_CLI_DEFAULT_DISPLAY_HELP
  # note: if <display_help_for_func> is not given, use private_CLI_DEFAULT_DISPLAY_HELP_FOR
  # note: <get_help_func> is called in two different ways. Here are the usage :
  #       - <get_help_func> 'command' <cli_command> <sh_function> <help>
  #       - <get_help_func> 'menu' <cli_command> <help>
  # note: last argument given to <get_help_func> can be an empty string
  # note: <display_help_func> is called when 'help' CLI command is run
  # note: <display_help_for_func> is called when 'help ?' CLI command is run, ie
  #       'help' CLI command with arguments
  CLI_REGISTER_HELP () {
    [ $# -lt 1 -o $# -gt 4 ] && ERROR "CLI_REGISTER_HELP: invalid arguments"
    [ -z "$1" ] && ERROR "CLI_REGISTER_HELP: arguments are empty"

    __CLI_HELP_FILE__="$1"
    [ $# -gt 1 ] && __CLI_GET_HELP__="$2"
    [ $# -gt 2 ] && __CLI_DISPLAY_HELP__="$3"
    [ $# -gt 3 ] && __CLI_DISPLAY_HELP_FOR__="$4"

    if [ ! -f "${__CLI_HELP_FILE__}" ]; then
      touch "${__CLI_HELP_FILE__}" || ERROR "CLI_REGISTER_HELP: can't create help file"
      __CLI_BUILD_HELP__='true'
    else
      __CLI_BUILD_HELP__='false'
    fi
    return 0;
  }

  # usage: CLI_CLEAR_HELP_CACHE [<file>]
  # desc: Clear the cli help cache
  CLI_CLEAR_HELP_CACHE () {
    if [ $# -eq 1 ]; then
      [ -f "$1" ] && rm -f "$1"
    else
      [ -f "${__CLI_HELP_FILE__}" ] && rm -f "${__CLI_HELP_FILE__}"
    fi
  }

  # usage: private_CLI_SAVE_HELP <help-content>
  # desc: save <help-content> into cache file, if not presents
  private_CLI_SAVE_HELP () {
    [ $# -ne 1 ] && ERROR "private_CLI_SAVE_HELP: invalid arguments"
    [ "${__CLI_BUILD_HELP__}" = 'false' ] && return;

    grep "$1" < "${__CLI_HELP_FILE__}" >/dev/null 2>/dev/null
    [ $? -ne 0 ] && printf "%s\n" "$1" >> "${__CLI_HELP_FILE__}"
    return 0
  }

  # --------------------------------------------------------------------------

  # usage: private_CLI_DEFAULT_GET_HELP 'command' <cli-command> <bash-call> <help>
  # usage: private_CLI_DEFAULT_GET_HELP 'menu' <cli-menu> <help>
  # desc: Try to get help content for a registered command or menu
  # note: use to fill the cahe file of help content
  private_CLI_DEFAULT_GET_HELP() {
    local type="$1" cli_command="$2" help=
    [ "${type}" = 'command' ] && help="$4" || help="$3"
    if [ "${type}" = 'menu' ]; then
      # make clean up
      cli_command=$( printf "%s" "${cli_command}" \
        | sed -e 's/<[^>]*>//g;s/\[[^]]*\]//g;s/"<[^>]*>"//g;s/  */ /g;' )
    fi
    printf "%s\t%s\t%s" "${type}" "${cli_command}" "${help}"
    return 0;
  }

  # usage: private_CLI_DEFAULT_DISPLAY_HELP
  # desc: display help section, which correspond to registered menus
  private_CLI_DEFAULT_DISPLAY_HELP () {
    grep $'^menu\t' < "${__CLI_HELP_FILE__}" \
      | cut -d $'\t' -f 2-
  }

  # usage: private_CLI_DEFAULT_DISPLAY_HELP_FOR <pattern>
  # desc: display help content for command which matches to <pattern>
  private_CLI_DEFAULT_DISPLAY_HELP_FOR () {
    grep $'^command' < "${__CLI_HELP_FILE__}" \
      | cut -d $'\t' -f 2-                    \
      | grep "^$* "
  }

fi # end of: if [ "${__LIB_CLI_HELP__:-}" != 'Loaded' ]; then