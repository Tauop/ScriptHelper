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
# This lib helps to build a Command Line Interface.
#
# You can use cli-help library, as this library rely on private_CLI_SAVE_HELP()
# to add help content when CLI command are registered
#
# Global variables ===========================================================
# __LIB_CLI__ : 'Loaded' when the lib is 'source'd
# __CLI_BUILD__ : Do we have to build the code cache files __CLI_CODE_FILE__
#                 and __CLI_KCODE_FILE__ (default: false)
# __CLI_CODE_FILE__ : Sed directives which are built with CLI_REGISTER_COMMAND() and
#                     CLI_REGISTER_MENU() and run with CLI_RUN_COMMAND() and CLI_RUN()
# __CLI_KCODE_FILE__ : Sed directives which are built with CLI_REGISTER_KCOMMAND()
#                      and interpret with CLI_RUN() to set context
# __CLI_PROMPT__ : Prompt of the interactive CLI (run with CLI_RUN())
# __CLI_CONTEXT_MENU__ : Use to store the current context of command
#
# __CLI_BUILD_HELP__ is not defined in this library, but in the cli-help library.
# We rely on it to know if we have to add help content, and to know if cli-help
# is loaded.
# ----------------------------------------------------------------------------

if [ "${__LIB_CLI__:-}" != 'Loaded' ]; then
  __LIB_CLI__='Loaded';

  __CLI_PROMPT__=
  __CLI_CONTEXT_MENU__=

  __CLI_BUILD__='false'
  __CLI_CODE_FILE__="/tmp/scripthelper.cli.code"
  __CLI_KCODE_FILE__="/tmp/scripthelper.cli.kcode"

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

  load __LIB_MESSAGE__ "${SCRIPT_HELPER_DIRECTORY}/message.lib.sh"
  load __LIB_ASK__     "${SCRIPT_HELPER_DIRECTORY}/ask.lib.sh"
  load __LIB_RANDOM__  "${SCRIPT_HELPER_DIRECTORY}/random.lib.sh"

  # usage: CLI_SET_PROMPT "<string>"
  # desc: set the CLI prompt
  CLI_SET_PROMPT () { __CLI_PROMPT__="$1"; }

  # usage: CLI_USE_READLINE <options>
  # desc: Enable the readline functionnalities of read
  CLI_USE_READLINE () { ASK_ENABLE_READLINE $@; }

  # --------------------------------------------------------------------------
  # usage: CLI_REGISTER_CODE_CACHE <file>
  # desc: setup the code cache files
  CLI_REGISTER_CODE_CACHE () {
    [ $# -ne 1 ] && ERROR "CLI_REGISTER_CODE_CACHE: invalid argument"

    __CLI_CODE_FILE__="$1.code"
    __CLI_KCODE_FILE__="$1.kcode"

    if [ ! -f "${__CLI_CODE_FILE__}" ]; then
      touch "${__CLI_CODE_FILE__}"  || ERROR "CLI_REGISTER_CODE_CACHE: can't create help file"
      touch "${__CLI_KCODE_FILE__}" || ERROR "CLI_REGISTER_CODE_CACHE: can't create help file"
      __CLI_BUILD__='true'
    else
      __CLI_BUILD__='false'
    fi
    return 0;
  }

  CLI_CLEAR_CODE_CACHE () {
    rm -f "${__CLI_CODE_FILE__}"
    rm -f "${__CLI_KCODE_FILE__}"
    __CLI_BUILD__='true'
  }

  # --------------------------------------------------------------------------

  # usage: private_SED_SEPARATOR <string>
  # desc: determine a good sed separator
  private_SED_SEPARATOR () {
    for s in '/' '@' ',' '|'; do
      printf '%s\n' "$1" | grep "$s" >/dev/null
      if [ $? -ne 0 ]; then
        printf '%s\n' "$s"; return 0;
      fi
    done
    return 1;
  }

  # usage: private_GET_FIRST_AND_LAST_CHAR <string>
  # desc: return the first and the last character. concatened in a string
  private_GET_FIRST_AND_LAST_CHAR () {
    local word="$1"
    if [ ${#word} -gt 0 ]; then
      printf '%c%c' "${word%"${word#?}"}" "${word#"${word%?}"}"
    else
      printf ''
    fi
  }

  # usage: private_EAT_FIRST_AND_LAST_CHAR <string>
  # desc: return the <string> removing the first and last character
  private_EAT_FIRST_AND_LAST_CHAR () {
    local str="${1#?}"; str="${str%?}";
    printf '%s' "${str}";
  }

  # usage: private_GET_CHAR <string>
  # desc: return the first character
  private_GET_FIRST_CHAR () {
    local word="$1"
    if [ ${#word} -gt 0 ]; then
      printf '%c' "${word%"${word#?}"}" #"
    else
      printf ''
    fi
  }

  # usage: private_GET_NEXT_TOKEN <cli-command>
  # desc: Get the next token in the <cli-command>
  private_GET_NEXT_TOKEN () {
    local cmd="$1" first= srch= pos= offset=
    first=$( private_GET_FIRST_CHAR "${cmd}" )
    case "${first}" in
      ' ') srch=' *[^ ]'   ; offset=1 ;;
      '[') srch='[^]]*[]]' ; offset=0 ;;
      '<') srch='[^>]*[>]' ; offset=0 ;;
      '"') srch='[^"]*["]' ; offset=0 ;;
      *)   srch='[^ ]* '   ; offset=1 ;;
    esac

    pos=$( expr "${cmd}" : "${srch}" )
    if [ $pos -gt 1 ]; then
      printf '%s' "${cmd}" | cut -c -$(( ${pos} - ${offset} ))
    else
      printf '%s' "${first}"
    fi
  }

  # usage: private_TOKEN_TO_SED <token>
  # desc: return a sed pattern toward the given <token>
  # note: Doesn't work for nested [...]
  private_TOKEN_TO_SED () {
    local token="$1" englobe_char= result=

    if [ -n "${token}" ]; then
      englobe_char=$( private_GET_FIRST_AND_LAST_CHAR "${token}" )
      case "${englobe_char}" in
        '""' ) # TODO: usefull ?
          token=$( private_EAT_FIRST_AND_LAST_CHAR "${token}" )
          englobe_char=$( private_GET_FIRST_AND_LAST_CHAR "${token}" )
          if [ "${englobe_char}" = '<>' ]; then
            result="\"\([^\"]*\)\""
          else
            result="\"${token}\""
          fi
          ;;
        '[]' )
          # FIXME : error when [<protocol>://]<host>[:<port>]
          token=$( private_EAT_FIRST_AND_LAST_CHAR "${token}" )
          result=$( private_BUILD_SED_SUB_COMMAND "${token}" )
          result="\(${result}\)\{0,1\}"
          ;;
        '<>' ) result="\([^ ]*\)" ;;
        '  ' ) result=" *"        ;;
        *    ) result="${token}"  ;;
      esac
    fi
    printf '%s' "${result}"
  }

  # usage: private_EAT_TOKEN <cli-command> <token>
  # desc: return the <cli-command> without the <token>
  private_EAT_TOKEN() { printf '%s' "${1}" | cut -c "$(( ${#2} + 1 ))-" ; }

  # usage: private_BUILD_SED_SUB_COMMAND <simple-cli-command>
  # desc: build a sed pattern for parsing CLI sub-command. Usefull for reccursive call
  private_BUILD_SED_SUB_COMMAND () {
    local cmd="$1" token=
    while [ ${#cmd} -ne 0 ]; do
      token=$( private_GET_NEXT_TOKEN "${cmd}" )
      private_TOKEN_TO_SED "${token}"
      cmd=$( private_EAT_TOKEN "${cmd}" "${token}" )
    done
  }

  # usage: private_BUILD_SED_COMMAND <simple-cli-command>
  # desc: build a sed pattern for parsing CLI command
  # note: <simple-cli-command> is the first argument of CLI_REGISTER_COMMAND methods-like
  private_BUILD_SED_COMMAND () {
    printf '^'
    private_BUILD_SED_SUB_COMMAND " $1 "
    printf '$'
  }

  #   usage: CLI_REGISTER_COMMAND "<cli_command>" <function>
  #   desc: register a cli command <cli_command>, which may call the <function>
  #   note: commands, registered with this method, will take care of the CLI context
  CLI_REGISTER_COMMAND () {
    [ $# -ne 2 -a $# -ne 3 ] && ERROR "CLI_REGISTER_COMMAND: invalid arguments"
    [ "${__CLI_BUILD__}" = 'false' ] && return

    private_CLI_COMPIL "$1" "$2" >> "${__CLI_CODE_FILE__}"

    if [ "${__CLI_BUILD_HELP__:-}" = 'true' ]; then
      private_CLI_SAVE_HELP "$( eval "${__CLI_GET_HELP__} 'command' '$1' '$2' '${3:-}'" )"
    fi
  }

  # usage: CLI_REGISTER_KCOMMAND "<cli_command>" <function>
  # desc: register a cli command <cli_command>, which may call the <function>
  #       and don't take care of the CLI context
  CLI_REGISTER_KCOMMAND() {
    [ $# -ne 2 -a $# -ne 3 ] && ERROR "CLI_REGISTER_KCOMMAND: invalid arguments"
    [ "${__CLI_BUILD__}" = 'false' ] && return

    private_CLI_COMPIL "$1" "$2" >> "${__CLI_KCODE_FILE__}"

    if [ "${__CLI_BUILD_HELP__:-}" = 'true' ]; then
      private_CLI_SAVE_HELP "$( eval "${__CLI_GET_HELP__} 'command' '$1' '$2' '${3:-}'" )"
    fi
  }

  # usage: private_CLI_COMPIL <cli-command> <bash-func>
  # desc: compil a <cli-command> and <bash-func> into sed command for parsing.
  private_CLI_COMPIL() {
    local cli_cmd="$1" func="$2" sep=

    # delete trailing space
    cli_cmd="${cli_cmd%% }"; cli_cmd="${cli_cmd## }"
    func="${func%% }"; func="${func## }"

    [ "${cli_cmd:-}" = '' -o "${func:-}" = '' ] && ERROR "CLI_REGISTER_COMMAND: invalid arguments"

    sep=$( private_SED_SEPARATOR "${cli_cmd}" )
    cli_cmd=$( private_BUILD_SED_COMMAND "${cli_cmd}" )
    func=$( printf '%s' "${func}" | sed -e "s/\([\\][0-9]\)/'\1'/g" )

    printf '%s\n' "s${sep}${cli_cmd}${sep}${func}${sep}p; t"
  }

  # usage: CLI_REGISTER_MENU "<cli_menu>"
  # desc: register a cli menu, which will be added at the beginnig of new CLI command.
  CLI_REGISTER_MENU () {
    local cli_menu= sep=
    [ $# -ne 1 -a $# -ne 2 ] && ERROR "CLI_REGISTER_MENU: invalid arguments"
    [ "${__CLI_BUILD__}" = 'false' ] && return

    cli_menu="$1"
    sep=$( private_SED_SEPARATOR "${cli_menu}" )
    cli_menu=$( private_BUILD_SED_COMMAND "${cli_menu}" )

    printf '%s\n' "s${sep}\(${cli_menu}\)${sep}CLI_ENTER_MENU \1${sep}p; t" >> "${__CLI_CODE_FILE__}"
    if [ "${__CLI_BUILD_HELP__:-}" = 'true' ]; then
      private_CLI_SAVE_HELP "$( eval "${__CLI_GET_HELP__} 'menu' '$1' '${2:-}' ")"
    fi
  }

  # usage: CLI_RUN_COMMAND <command>
  # desc: Run a single command into the CLI
  # note: this function return 0 if a valid CLI command is passed in argument, otherwise 1
  CLI_RUN_COMMAND () {
    local cmd=
    [ $# -eq 0 ] && return;

    cmd=$( printf '%s' "$*" | sed -n -f "${__CLI_KCODE_FILE__}" )
    [ -z "${cmd}" ] && cmd=$( printf '%s' "$*" | sed -n -f "${__CLI_CODE_FILE__}" )

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
    CLI_UNKNOWN_COMMAND () { ERROR "Unknown CLI command: ${input}"; }
    CLI_ENTER_MENU () { __CLI_CONTEXT_MENU__="$*"; }
    CLI_QUIT='[ -z "${__CLI_CONTEXT_MENU__:-}" ] \&\& break || __CLI_CONTEXT_MENU__= '

    local kcode= code= input= cmd=

    # Add specials command to code and kcode, if we run the CLI and have just build the code cache files
    if [ "${__CLI_BUILD__}" = 'true' ]; then
      printf 'a \\\n CLI_UNKNOWN_COMMAND;\n' >> "${__CLI_CODE_FILE__}"

      # internal CLI special commands
      printf '%s\n' "s/^ *help *$/${__CLI_DISPLAY_HELP__}/p; t"              >> "${__CLI_KCODE_FILE__}"
      printf '%s\n' "s/^ *help *\(.*\)$/${__CLI_DISPLAY_HELP_FOR__} \1/p; t" >> "${__CLI_KCODE_FILE__}"
      printf '%s\n' "s/^ *quit *$/${CLI_QUIT}/p; t"                          >> "${__CLI_KCODE_FILE__}"
      printf '%s\n' "s/^ *exit *$/break/p; t"                                >> "${__CLI_KCODE_FILE__}"
    fi

    while [ true ]; do
      ASK --allow-empty input "${__CLI_PROMPT__} ${__CLI_CONTEXT_MENU__:+[${__CLI_CONTEXT_MENU__}]}>"
      [ -z "${input}" ] && continue

      cmd=$( printf '%s' "${input}" | sed -n -f "${__CLI_KCODE_FILE__}" )
      [ -z "${cmd}" ] && \
        cmd=$( printf '%s' "${__CLI_CONTEXT_MENU__} ${input}" | sed -n -f "${__CLI_CODE_FILE__}" )
      eval "${cmd}"
    done

    return 0;
  }

fi # end of: if [ "${__LIB_CLI__:-}" != 'Loaded' ]; then
