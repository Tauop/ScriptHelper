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
# This lib helps to build a Command Line Interface.
#
# Global variables ===========================================================
# __LIB_CLI__ : 'Loaded' when the lib is 'source'd
# __CLI_CODE__ : Sed directives which are built with CLI_REGISTER_COMMAND() and
#                CLI_REGISTER_MENU() and run with CLI_RUN_COMMAND() and CLI_RUN()
# __CLI_KCODE__ : Sed directives which are built with CLI_REGISTER_KCOMMAND()
#                and interpret with CLI_RUN() to set context
# __CLI_PROMPT__ : Prompt of the interactive CLI (run with CLI_RUN())
# __CLI_CONTEXT_MENU__ : Use to store the current context of command
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

if [ "${__LIB_CLI__:-}" != 'Loaded' ]; then
  __LIB_CLI__='Loaded';
  __CLI_CODE__=
  __CLI_KCODE__=
  __CLI_PROMPT__=
  __CLI_CONTEXT_MENU__=

  __CLI_BUILD_HELP__='false'
  __CLI_HELP_FILE__=
  __CLI_GET_HELP__='private_CLI_DEFAULT_GET_HELP'
  __CLI_DISPLAY_HELP__='private_CLI_DEFAULT_DISPLAY_HELP'
  __CLI_DISPLAY_HELP_FOR__='private_CLI_DEFAULT_DISPLAY_HELP_FOR'

  # load dependencies
  load() {
    local var= value= file=

    var="$1"; file="$2"
    value=$( eval "echo \"\${${var}:-}\"" )

    [ -n "${value}" ] && return 1;
    if [ -f "${file}" ]; then
      . "${file}"
    else
      echo "ERROR: Unable to load ${file}"
      exit 2
    fi
    return 0;
  }

  # Load configuration file
  load SCRIPT_HELPER_DIRECTORY /etc/ScriptHelper.conf
  SCRIPT_HELPER_DIRECTORY="${SCRIPT_HELPER_DIRECTORY:-}"
  SCRIPT_HELPER_DIRECTORY="${SCRIPT_HELPER_DIRECTORY%%/}"

  load __LIB_MESSAGE__ "${SCRIPT_HELPER_DIRECTORY}/message.lib.sh"
  load __LIB_ASK__     "${SCRIPT_HELPER_DIRECTORY}/ask.lib.sh"
  load __LIB_RANDOM__  "${SCRIPT_HELPER_DIRECTORY}/random.lib.sh"

  # usage: private_PURIFY_COMMAND <cli-command>
  # desc: replace all <var> and [var] pattern into '?'
  private_PURIFY_CLI_COMMAND () {
    local result= word= first_char= last_char=
    echo "$1" | tr ' ' $'\n' \
      | ( while read word; do
            [ -z "${word}" ] && continue
            first_char="${word%"${word#?}"}";
            if [ "${first_char}" = '<' -o "${first_char}" = '[' ]; then
              last_char="${word#"${word%?}"}"
              if [ "${last_char}"  = '>' -o "${last_char}"  = ']' ]; then
                result="${result} ?"
                continue;
              fi
            fi
            result="${result} ${word}"
          done
          echo -n "${result# }"
        )
    return 0
  }

  # usage: CLI_SET_PROMPT "<string>"
  # desc: set the CLI prompt
  CLI_SET_PROMPT () { __CLI_PROMPT__="$1"; }

  # usage: CLI_USE_READLINE <options>
  # desc: Enable the readline functionnalities of read
  CLI_USE_READLINE () { ASK_ENABLE_READLINE $@; }

  # --------------------------------------------------------------------------
  # HELP generation related methods in this section

  # usage: private_CLI_DEFAULT_GET_HELP 'command' <cli-command> <bash-call> <help>
  # usage: private_CLI_DEFAULT_GET_HELP 'menu'<cli-menu> <help>
  # desc: Try to get help content for a registered command or menu
  # note: use to fill the cahe file of help content
  private_CLI_DEFAULT_GET_HELP() {
    local type="$1" cli_command="$2" help=
    [ "${type}" = 'command' ] && help="$4" || help="$3"
    if [ "${type}" = 'menu' ]; then
      cli_command=$( private_PURIFY_CLI_COMMAND "${cli_command}" )
      cli_command=$( echo "${cli_command}" | sed -e 's/?//g;s/ */ /g;' )
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

  # usage: private_CLI_SAVE_HELP <help-content>
  # desc: save <help-content> into cache file, if not presents
  private_CLI_SAVE_HELP () {
    [ $# -ne 1 ] && ERROR "private_CLI_SAVE_HELP: invalid arguments"
    [ "${__CLI_BUILD_HELP__}" = 'false' ] && return;
    grep "$1" < "${__CLI_HELP_FILE__}" >/dev/null 2>/dev/null
    [ $? -ne 0 ] && echo "$1" >> "${__CLI_HELP_FILE__}"
    return 0
  }

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

  # --------------------------------------------------------------------------

  # usage: private_SED_SEPARATOR <string> 
  # desc: determine a good sed separator
  private_SED_SEPARATOR () {
    for s in '/' '@' ',' '|'; do
      echo "$1" | grep "$s" >/dev/null
      if [ $? -ne 0 ]; then
        echo "$s"; return 0;
      fi
    done
    return 1;
  }

  # usage: private_BUILD_SED_COMMAND <simple-cli-command>
  # desc: build a sed pattern for parsing CLI command
  # note: <simple-cli-command> is the first argument of CLI_REGISTER_COMMAND methods-like
  private_BUILD_SED_COMMAND () {
    local command= word=
    command=$( private_PURIFY_CLI_COMMAND "$1" )
    echo -n "^"
    echo "${command}" | tr ' ' $'\n' \
      | while read word; do
          [ -z "${word}" ] && continue
          if [ "${word}" = '?' ]; then
            echo -n ' *\([^ ]*\)'
            continue
          fi
          echo -n " *${word}"
        done
    echo " *$"
  }

  #   usage: CLI_REGISTER_COMMAND "<cli_command>" <function>
  #   desc: register a cli command <cli_command>, which may call the <function>
  #   note: commands, registered with this method, will take care of the CLI context
  CLI_REGISTER_COMMAND () {
    [ $# -ne 2 -a $# -ne 3 ] && ERROR "CLI_REGISTER_COMMAND: invalid arguments"
    private_CLI_COMPIL "$1" "$2" "__CLI_CODE__"
    if [ "${__CLI_BUILD_HELP__}" = 'true' ]; then
      private_CLI_SAVE_HELP "$( eval "${__CLI_GET_HELP__} 'command' '$1' '$2' '${3:-}'" )"
    fi
  }

  # usage: CLI_REGISTER_KCOMMAND "<cli_command>" <function>
  # desc: register a cli command <cli_command>, which may call the <function>
  #       and don't take care of the CLI context
  CLI_REGISTER_KCOMMAND() {
    [ $# -ne 2 -a $# -ne 3 ] && ERROR "CLI_REGISTER_KCOMMAND: invalid arguments"
    private_CLI_COMPIL "$1" "$2" "__CLI_KCODE__"
    if [ "${__CLI_BUILD_HELP__}" = 'true' ]; then
      private_CLI_SAVE_HELP "$( eval "${__CLI_GET_HELP__} 'command' '$1' '$2' '${3:-}'" )"
    fi
  }

  # usage: private_CLI_COMPIL <cli-command> <bash-func> <type-of-code>
  # desc: compil a <cli-command> and <bash-func> into sed command for parsing.
  # note: <type-of-code> is equal to '__CLI_CODE__' for contextual command, and
  #       it's equal to '__CLI_KCODE__' for commands which don't care of the context
  private_CLI_COMPIL() {
    local cli_cmd="$1" func="$2" code="$3" sep=

    # delete trailing space
    cli_cmd="${cli_cmd%% }"; cli_cmd="${cli_cmd## }"
    func="${func%% }"; func="${func## }"

    [ "${cli_cmd:-}" = '' -o "${func:-}" = '' ] && ERROR "CLI_REGISTER_COMMAND: invalid arguments"

    sep=$( private_SED_SEPARATOR "${cli_cmd}" )
    cli_cmd=$( private_BUILD_SED_COMMAND "${cli_cmd}" )
    func=$( echo "${func}" | sed -e "s/\([\\][0-9]\)/'\1'/g" )

    # update the code
    eval "$code=\"\${${code}} s${sep}${cli_cmd}${sep}${func}${sep}p; t;\""
  }

  # usage: CLI_REGISTER_MENU "<cli_menu>"
  # desc: register a cli menu, which will be added at the beginnig of new CLI command.
  CLI_REGISTER_MENU () {
    local cli_menu= sep=
    [ $# -ne 1 -a $# -ne 2 ] && ERROR "CLI_REGISTER_MENU: invalid arguments"
    cli_menu="$1"

    sep=$( private_SED_SEPARATOR "${cli_menu}" )
    cli_menu=$( private_BUILD_SED_COMMAND "${cli_menu}" )

    __CLI_CODE__="${__CLI_CODE__} s${sep}\(${cli_menu}\)${sep}CLI_ENTER_MENU \1${sep}p; t;"
    if [ "${__CLI_BUILD_HELP__}" = 'true' ]; then
      private_CLI_SAVE_HELP "$( eval "${__CLI_GET_HELP__} 'menu' '$1' '${2:-}' ")"
    fi
  }

  # usage: CLI_RUN_COMMAND <command>
  # desc: Run a single command into the CLI
  # note: this function return 0 if a valid CLI command is passed in argument, otherwise 1
  CLI_RUN_COMMAND () {
    local cmd=
    [ $# -eq 0 ] && return;

    cmd=$( echo "$*" | sed -n -e "${__CLI_KCODE__}" )
    [ -z "${cmd}" ] && cmd=$( echo "$*" | sed -n -e "${__CLI_CODE__}" )

    if [ -n "${cmd}" ]; then
      eval "${cmd}"
      return $?
    fi
    return 1;
  }

  # usage: CLI_RUN_CMD <command>
  # desc: alias of CLI_RUN_COMMAND
  CLI_RUN_CMD() { CLI_RUN_COMMAND $@; return $?; }

  # usage: CLI_RUN
  # desc: Run the CLI
  # note: this function add some "sugar" CLI command, like 'quit', 'exit',
  #       and deal with CLI context menu for command registered with CLI_REGISTER_COMMAND()
  CLI_RUN () {
    CLI_UNKNOWN_COMMAND () { ERROR "Unknown CLI command"; }
    CLI_ENTER_MENU () { __CLI_CONTEXT_MENU__="$*"; }
    CLI_QUIT='[ -z "${__CLI_CONTEXT_MENU__:-}" ] \&\& break || __CLI_CONTEXT_MENU__= '

    local kcode= code= input= cmd=

    code="${__CLI_CODE__} ; a \ CLI_UNKNOWN_COMMAND;"

    # internal CLI special commands
    kcode="${__CLI_KCODE__}"
    kcode="${kcode} s/^ *help *$/${__CLI_DISPLAY_HELP__}/p; t;"
    kcode="${kcode} s/^ *help *\(.*\)$/${__CLI_DISPLAY_HELP_FOR__} \1/p; t;"
    kcode="${kcode} s/^ *quit *$/${CLI_QUIT}/p; t;"
    kcode="${kcode} s/^ *exit *$/break/p; t;"

    while [ true ]; do
      ASK --allow-empty input "${__CLI_PROMPT__} ${__CLI_CONTEXT_MENU__:+[${__CLI_CONTEXT_MENU__}]}>"
      [ -z "${input}" ] && continue
      cmd=$( echo "${input}" | sed -n -e "${kcode}" )
      [ -z "${cmd}" ] && \
        cmd=$( echo "${__CLI_CONTEXT_MENU__} ${input}" | sed -n -e "${code}" )
      eval "${cmd}"
    done

    return 0;
  }

fi # end of: if [ "${__LIB_CLI__:-}" != 'Loaded' ]; then
