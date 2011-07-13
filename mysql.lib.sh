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
# This library helps to write scripts which have to work with mysql
#
# All mysql functions supports following options :
#   --user : MySQL username to use
#   --pass : MySQL password
#   --db : database to use
#   --host : MySQL host to connect to
#   --port : MySQL target host port to use
#   --human : draw ascii table
#   --bash : opposite of --human
#   --with-log : call EXEC with --with-log
#   --with-check : call EXEC with --with-check
#
# Global variables ===========================================================
# IMPORTANT: Please don't write to those variables
# __LIB_MYSQL__ : 'Loaded' when this lib is 'source'd
# __MYSQL_USERNAME__ : mysql username to use when not given by options
# __MYSQL_PASSWORD__ : mysql password to use when not given by options
# __MYSQL_DATABASE__ : mysql database to use when not given by options
# __MYSQL_HOST__ : mysql host to connect to when not given by options
# __MYSQL_PORT__ : mysql port to connect to when not given by options
# __MYSQL_HUMAN__ : display result in human readable display
# __MYSQL_OPTIONS__ : compute mysql options from previous variables
# __MYSQL_OPTIONS_CHANGED__ : do we have to compute __MYSQL_OPTIONS__ again
# __MYSQL_NB_CONSUMMED_ARG__ : needed for argument parsing
# __MYSQL_DUMP_FILE__ : file which dump is stored in or read from
# __EXEC_OPTIONS__ : options to pass to EXEC (see exec.lib.sh)
# __MYSQL_BACKUP_* : variables used to backup previous variables
# __MYSQL_DUMP_FILE__ : Path to the dump file, deals by MYSQL_DUMP and
#                       MYSQL_RESTORE
# ----------------------------------------------------------------------------

# Don't source this file several times
if [ "${__LIB_MYSQL__:-}" != 'Loaded' ]; then
  __LIB_MYSQL__='Loaded'

  # FIXME: TOO much global variables :-(
  __MYSQL_USERNAME__=''
  __MYSQL_PASSWORD__=''
  __MYSQL_DATABASE__=''
  __MYSQL_HOST__='localhost'
  __MYSQL_PORT__='3306'
  __MYSQL_HUMAN__='false'
  __MYSQL_OPTIONS__=''

  __MYSQL_OPTIONS_CHANGED__='false'
  __MYSQL_NB_CONSUMMED_ARG__=0
  __MYSQL_DUMP_FILE__="/tmp/mysqldump_$(RANDOM).sql"
  __EXEC_OPTIONS__=''

  __MYSQL_BACKUP_USERNAME__=''
  __MYSQL_BACKUP_PASSWORD__=''
  __MYSQL_BACKUP_DATABASE__=''
  __MYSQL_BACKUP_HOST__=''
  __MYSQL_BACKUP_PORT__=''
  __MYSQL_BACKUP_HUMAN__=''
  __MYSQL_BACKUP_OPTIONS__=''

  # load dependencies
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

  load __LIB_MESSAGE__ "${SCRIPT_HELPER_DIRECTORY}/message.lib.sh"
  load __LIB_EXEC__    "${SCRIPT_HELPER_DIRECTORY}/exec.lib.sh"
  load __LIB_RANDOM__  "${SCRIPT_HELPER_DIRECTORY}/random.lib.sh"

  # PRIVATE METHODS ------------------------------------------------------------

  # usage: private_PARSE_MYSQL_OPTIONS <options>
  # desc: parse arguments passed in argument
  # notes:
  #   1/ __MYSQL_*__ variables can be changes
  #   2/ __MYSQL_OPTIONS_CHANGED__ = 'true' is options changed the mysql configuration
  #   3/ this method doesn't call private_BUILD_MYSQL_OPTIONS()
  #   4/ __MYSQL_NB_CONSUMMED_ARG__ contains number of arguments consummed
  # recommanded usage:
  #   | private_PARSE_MYSQL_OPTIONS $@
  #   | shift ${__MYSQL_NB_CONSUMMED_ARG__}
  private_PARSE_MYSQL_OPTIONS () {
    local inc=0 exec_with_log='false' exec_with_check='false'

    __MYSQL_OPTIONS_CHANGED__='false'
    __MYSQL_NB_CONSUMMED_ARG__=0

    while [ true ]; do
      [ $# -eq 0 ] && break;
      case "$1" in
        # common connexion options
        --user  ) shift; __MYSQL_USERNAME__=$1; shift; inc=2 ;;
        --pass  ) shift; __MYSQL_PASSWORD__=$1; shift; inc=2 ;;
        --db    ) shift; __MYSQL_DATABASE__=$1; shift; inc=2 ;;
        --host  ) shift; __MYSQL_HOST__=$1;     shift; inc=2 ;;
        --port  ) shift; __MYSQL_PORT__=$1;     shift; inc=2 ;;

        # misc options
        --human ) shift; __MYSQL_HUMAN__="true" ; inc=1 ;;
        --bash  ) shift; __MYSQL_HUMAN__="false"; inc=1 ;;

        # EXEC options
        --with-log   ) shift; exec_with_log='true';   inc=1 ;;
        --with-check ) shift; exec_with_check='true'; inc=1 ;;

        # ignore but increment number of argument consummed
        --*       ) shift; inc=1 ;;
        *         ) break ;;
      esac
      if [ "${inc}" != '0' ]; then
        __MYSQL_OPTIONS_CHANGED__='true';
        # TODO: is it cross-shell ? use `expr` if needed
        __MYSQL_NB_CONSUMMED_ARG__=$(( __MYSQL_NB_CONSUMMED_ARG__ + inc ))
      fi
      inc=0
    done

    __EXEC_OPTIONS__=''
    [ "${exec_with_log}"   = 'true' ] && __EXEC_OPTIONS__="${__EXEC_OPTIONS__} --with-log "
    [ "${exec_with_check}" = 'true' ] && __EXEC_OPTIONS__="${__EXEC_OPTIONS__} --with-check "
  }

  # usage: private_BUILD_MYSQL_OPTIONS
  # desc: build the __MYSQL_OPTIONS__ variable which contain mysql commands
  #       common options and will be passed to mysql commands
  # notes:
  #   1/ this method can changes __MYSQL_OPTIONS__
  #   2/ this method doesn't changes __MYSQL_OPTIONS_CHANGED__ value
  private_BUILD_MYSQL_OPTIONS () {
    __MYSQL_OPTIONS__=''
    [ -n "${__MYSQL_USERNAME__}" ] && __MYSQL_OPTIONS__="${__MYSQL_OPTIONS__} -u'${__MYSQL_USERNAME__}'"
    [ -n "${__MYSQL_PASSWORD__}" ] && __MYSQL_OPTIONS__="${__MYSQL_OPTIONS__} -p'${__MYSQL_PASSWORD__}'"
    [ -n "${__MYSQL_DATABASE__}" ] && __MYSQL_OPTIONS__="${__MYSQL_OPTIONS__} -D '${__MYSQL_DATABASE__}'"
    [ -n "${__MYSQL_HOST__}"     ] && __MYSQL_OPTIONS__="${__MYSQL_OPTIONS__} -h '${__MYSQL_HOST__}'"
    [ -n "${__MYSQL_PORT__}"     ] && __MYSQL_OPTIONS__="${__MYSQL_OPTIONS__} -P '${__MYSQL_PORT__}'"
  }

  # usage: private_BACKUP_MYSQL_CONF
  # desc: backup global mysql configuration
  private_BACKUP_MYSQL_CONF () {
    __MYSQL_BACKUP_USERNAME__="${__MYSQL_USERNAME__}"
    __MYSQL_BACKUP_PASSWORD__="${__MYSQL_PASSWORD__}"
    __MYSQL_BACKUP_DATABASE__="${__MYSQL_DATABASE__}"
    __MYSQL_BACKUP_HOST__="${__MYSQL_HOST__}"
    __MYSQL_BACKUP_PORT__="${__MYSQL_PORT__}"
    __MYSQL_BACKUP_HUMAN__="${__MYSQL_HOST__}"
    __MYSQL_BACKUP_OPTIONS__="${__MYSQL_OPTIONS__}"
  }

  # private_RESTORE_MYSQL_CONF
  # desc: restaure global mysql configuration
  private_RESTORE_MYSQL_CONF () {
    __MYSQL_USERNAME__="${__MYSQL_BACKUP_USERNAME__}"
    __MYSQL_PASSWORD__="${__MYSQL_BACKUP_PASSWORD__}"
    __MYSQL_DATABASE__="${__MYSQL_BACKUP_DATABASE__}"
    __MYSQL_HOST__="${__MYSQL_BACKUP_HOST__}"
    __MYSQL_PORT__="${__MYSQL_BACKUP_PORT__}"
    __MYSQL_HUMAN__="${__MYSQL_BACKUP_HUMAN__}"
    __MYSQL_OPTIONS__="${__MYSQL_BACKUP_OPTIONS__}"
  }

  # PUBLIC METHODS -------------------------------------------------------------

  # usage: MYSQL_SET_CONF [ <options> ]
  #        MYSQL_SET_CONF <username> [ <password> [ <database> [ <host> [ <port> ] ] ] ]
  # desc: Save global MySQL configuration, which allow to not repeat mysql command
  #       options every time we call a MySQL function.
  # note : username is mandatory, through options or arguments
  MYSQL_SET_CONF () {
    # reset all config variables
    __MYSQL_USERNAME__=''
    __MYSQL_PASSWORD__=''
    __MYSQL_DATABASE__=''
    __MYSQL_HOST__='localhost'
    __MYSQL_PORT__='3306'
    __MYSQL_HUMAN__='false'

    private_PARSE_MYSQL_OPTIONS $@
    shift ${__MYSQL_NB_CONSUMMED_ARG__}

    # parse trailing arguments
    # note: the while is just a workaround, as bash has no GOTO statement
    while [ true ]; do
      [ $# -gt 0 ] && __MYSQL_USERNAME__="$1" || break
      [ $# -gt 1 ] && __MYSQL_PASSWORD__="$2" || break
      [ $# -gt 2 ] && __MYSQL_DATABASE__="$3" || break
      [ $# -gt 3 ] && __MYSQL_HOST__="$4"     || break
      [ $# -gt 4 ] && __MYSQL_PORT__="$5"     || break
      break
    done

    # build __MYSQL_OPTIONS__, which will be used in other functions
    private_BUILD_MYSQL_OPTIONS
    __MYSQL_OPTIONS_CHANGED__='false'

    LOG "MySQL options change to : ${__MYSQL_OPTIONS__}"
  }


  # usage: MYSQL_QUERY [ <options> ] "<query>"
  # desc: execute a query on the MySQL instance/host.
  # arguments: <options> = common MySQL functions options
  #            "<query>" = a quoted MySQL query
  MYSQL_QUERY () {
    local return_value= query= mysql_exec_opt='-e'

    private_BACKUP_MYSQL_CONF

    private_PARSE_MYSQL_OPTIONS $@
    shift ${__MYSQL_NB_CONSUMMED_ARG__}

    # if there is options, build the new mysql options
    [ "${__MYSQL_OPTIONS_CHANGED__}" = 'true' ] && private_BUILD_MYSQL_OPTIONS

    [ $# -gt 0 ] && query="$*" || FATAL "MYSQL_QUERY: error in arguments ($@)"
    [ -z "${query}" ] && FATAL "MYSQL_QUERY: query is empty"

    [ "${__MYSQL_HUMAN__}" = 'false' ] && mysql_exec_opt='-Bse'
    EXEC ${__EXEC_OPTIONS__} mysql ${__MYSQL_OPTIONS__} ${mysql_exec_opt} "'${query}'"
    return_value=$?

    # restaure global configuration is it was changed
    [ "${__MYSQL_OPTIONS_CHANGED__}" = 'true' ] && private_RESTORE_MYSQL_CONF
    __MYSQL_OPTIONS_CHANGED__='false'
    return ${return_value}
  }

  # usage: MYSQL_DUMP [ <options> ] [ <dumpfile> [ <database> ] ]
  # desc: call mysqldump on a MySQL instance/host.
  # arguments: <options> = common MySQL functions options
  #            <dumpfile> = path to the file in which database will be saved
  #            <database> = database to backup/dump.
  # notes:
  #   1/ when <dumpfile> is egual to "-", a generated dumpfile path is used
  #   2/ when <databae> is not specified, all database of the MySQL instance/host
  #      are backup'ed/dumped
  MYSQL_DUMP () {
    local mysqldump_options= error_redir=

    mysqldump_options="--no-create-db --quote-names --opt --max_allowed_packet=67108864 --routines"
    [ -n "${__ERROR_LOG_FILE__}" ] && error_redir=">>'${__ERROR_LOG_FILE__}'"

    private_BACKUP_MYSQL_CONF
    private_PARSE_MYSQL_OPTIONS $@
    shift ${__MYSQL_NB_CONSUMMED_ARG__}
    __MYSQL_DATABASE__='' # reset database
    private_BUILD_MYSQL_OPTIONS

    if [ $# -eq 1 ]; then
      [ "$1" != '-' ] && __MYSQL_DUMP_FILE__="$1"
      mysqldump_options="${mysqldump_options} --all-databases"
    elif [ $# -eq 2 ]; then
      [ "$1" != '-' ] && __MYSQL_DUMP_FILE__="$1"
      mysqldump_options="${mysqldump_options} '${2}'"
    fi

    [ -z "${__MYSQL_DUMP_FILE__}" ] && FATAL "MYSQL_DUMP called with empty 'dumpfile' path"

    rm -f "${__MYSQL_DUMP_FILE__}" >/dev/null && touch "${__MYSQL_DUMP_FILE__}" 2>/dev/null
    [ $? -ne 0 ] && FATAL "Can't write into ${__MYSQL_DUMP_FILE__}."

    EXEC_WITH_CHECK mysqldump ${__MYSQL_OPTIONS__} ${mysqldump_options} ">${__MYSQL_DUMP_FILE__}" "${error_redir}"

    private_RESTORE_MYSQL_CONF
    __MYSQL_OPTIONS_CHANGED__='false'
  }

  # usage: MYSQL_RESTORE [ <options> ] [ <dumpfile> [ <database> ] ]
  # desc: call mysql with a dumpfile, to restaure one or severals databases
  # arguments: <options> = common MySQL functions options
  #            <dumpfile> = path to the file to load for database restaure
  #            <database> = database to backup/dump.
  # notes :
  #   1/ When MYSQL_RESTORE is called without argument, the last dumpfile
  #      created with MYSQL_DUMP is used to restaure all databases.
  #   2/ When <dumpfile> is equal to "-", the last dumpfile created with
  #      MYSQL_DUMP is used.
  #   3/ when <database> is not specified, we don't use -D options
  MYSQL_RESTORE () {
    local dumpfile=

    private_BACKUP_MYSQL_CONF
    private_PARSE_MYSQL_OPTIONS $@
    shift ${__MYSQL_NB_CONSUMMED_ARG__}

    [ $# -eq 0 -o "$1"  = '-' ] && dumpfile="${__MYSQL_DUMP_FILE__}"
    [ $# -gt 0 -a "$1" != '-' ] && dumpfile="$1"
    if [ $# -gt 1 ]; then
      __MYSQL_DATABASE__="$2"
      __MYSQL_OPTIONS_CHANGED__='true'
    fi

    [ "${__MYSQL_OPTIONS_CHANGED__}" = 'true' ] && private_BUILD_MYSQL_OPTIONS

    EXEC mysql ${__MYSQL_OPTIONS__} "<'${dumpfile}'"

    [ "${__MYSQL_OPTIONS_CHANGED__}" = 'true' ] && private_RESTORE_MYSQL_CONF
    __MYSQL_OPTIONS_CHANGED__='false'
  }

  # usage: MYSQL_GET_BASES() [ <options> ]
  # desc: get databases list of the mysql instance
  # arguments: <options> = common MySQL functions options
  MYSQL_GET_BASES ()  { MYSQL_QUERY $@ --bash 'SHOW DATABASES'; }
 
  # usage: MYSQL_GET_TABLES [ <options> ]
  # desc: get the table list of the current (or selected) database
  # arguments: <options> = common MySQL functions options
  MYSQL_GET_TABLES () { MYSQL_QUERY $@ --bash 'SHOW TABLES';    }

  # usage: MYSQL_GET_FIELDS [ <options> ] <table_name>
  # desc: get the field list of a table
  # arguments: <options> = common MySQL functions options
  #            <table_name> = name of a table
  MYSQL_GET_FIELDS () {
    local table_name=

    [ $# -eq 0 ] && FATAL "MYSQL_GET_FIELDS: wrong number of argument"

    # get the last argument
    if [ $# -gt 1 ]; then
      arguments=$( IFS=' ' printf '%s' "$*" )
      table_name="${arguments##* }"
      arguments=${arguments% $table_name}
    else
      table_name="$1"
      arguments=
    fi

    [ -z "${table_name}" ] && FATAL "MYSQL_GET_FIELDS: missing or incorrect table name"

    eval "MYSQL_QUERY --bash ${arguments} 'DESCRIBE \`${table_name}\`'" \
        | tr $'\t'  ' ' | tr -s ' ' | cut -d' ' -f1
  }

  # usage: MYSQL_GET_FIELD_TYPE [ <options> ] <table_name> <field_name>
  # desc: Get the SQL type of a table field
  # arguments: <options> = common MySQL functions options
  #            <table_name> = name of a table
  #            <field_name> = name of a field
  MYSQL_GET_FIELD_TYPE () {
    local table_name= field_name= do_simple='false'

    [ $# -eq 0 ] && FATAL "MYSQL_GET_FIELDS: wrong number of argument"

    # get the last argument
    arguments=$( IFS=' ' printf '%s' "$*" )

    if [ $# -gt 2 ]; then
      field_name="${arguments##* }"
      arguments=${arguments% ${field_name}}

      table_name="${arguments##* }"
      arguments=${arguments% ${table_name}}
   else
      table_name="$1"
      field_name="$2"
      arguments=
    fi

    arguments=" ${arguments} "
    # --simple option ?
    if [ "${arguments/ --simple /}" != "${arguments}" ]; then
      arguments=${arguments/ --simple /}
      do_simple='true'
    fi

    [ -z "${table_name}" ] && FATAL "MYSQL_GET_FIELD_TYPE: missing or incorrect table name"
    [ -z "${field_name}" ] && FATAL "MYSQL_GET_FIELD_TYPE: missing or incorrect field name"

    eval "MYSQL_QUERY --bash ${arguments} 'DESCRIBE \`${table_name}\`'"      \
        | tr $'\t' ' ' | grep "^${field_name} " | tr -s ' ' | cut  -d' ' -f2 \
        | ( [ "${do_simple}" = "true" ] && sed -e 's/[(].*[)]$//' || cat )
  }

fi # end of: if [ "${__LIB_MYSQL__}" != 'Loaded' ]; then
