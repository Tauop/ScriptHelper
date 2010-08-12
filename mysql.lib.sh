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
# This is a bash library for helping writing shell script for simples
# operations.
# Author: Patrick Guiran <pguiran@linagora.com>
# Creation: 04/05/2010
# Update: 09/06/2010
#
# Global variables ===========================================================
# IMPORTANT: Please don't write to those variables
# __LIB_MYSQL__ : 'Loaded' when this lib is 'source'd
# __MYSQL_DUMP_FILE__ : Path to the dump file, deals by MYSQL_DUMP and
#                       MYSQL_RESTORE
# Methods ====================================================================
#
# All mysql functions supports options which can be :
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
# MYSQL_SET_CONF()
#   desc: Save global MySQL configuration, which allow to not repeat mysql command
#         options every time we call a MySQL function.
#   usage: MYSQL_SET_CONF [ <options> ]
#          MYSQL_SET_CONF <username> [ <password> [ <database> [ <host> [ <port> ] ] ] ]
#   note : username is mandatory, through options or arguments
#
# MYSQL_QUERY()
#   desc: execute a query on the MySQL instance/host.
#   usage: MYSQL_QUERY [ <options> ] "<query>"
#   arguments: <options> = common MySQL functions options
#              "<query>" = a quoted MySQL query
#
# MYSQL_DUMP()
#   desc: call mysqldump on a MySQL instance/host.
#   usage: MYSQL_DUMP [ <options> ] [ <dumpfile> [ <database> ] ]
#   arguments: <options> = common MySQL functions options
#              <dumpfile> = path to the file in which database will be saved
#              <database> = database to backup/dump.
#   notes:
#     1/ when <dumpfile> is egual to "-", a generated dumpfile path is used
#     2/ when <databae> is not specified, all database of the MySQL instance/host
#        are backup'ed/dumped
#
# MYSQL_RESTORE()
#   desc: call mysql with a dumpfile, to restaure one or severals databases
#   usage: MYSQL_RESTORE [ <options> ] [ <dumpfile> [ <database> ] ]
#   arguments: <options> = common MySQL functions options
#              <dumpfile> = path to the file to load for database restaure
#              <database> = database to backup/dump.
#   notes :
#     1/ When MYSQL_RESTORE is called without argument, the last dumpfile
#        created with MYSQL_DUMP is used to restaure all databases.
#     2/ When <dumpfile> is equal to "-", the last dumpfile created with
#        MYSQL_DUMP is used.
#     3/ when <database> is not specified, we don't use -D options
#
# MYSQL_GET_BASES()
#   desc: get databases list of the mysql instance
#   usage: MYSQL_GET_BASES() [ <options> ]
#   arguments: <options> = common MySQL functions options
#
# MYSQL_GET_TABLES()
#   desc: get the table list of the current (or selected) database
#   usage: MYSQL_GET_TABLES [ <options> ]
#   arguments: <options> = common MySQL functions options
#
# MYSQL_GET_FIELDS()
#   desc: get the field list of a table
#   usage: MYSQL_GET_FIELDS [ <options> ] <table_name>
#   arguments: <options> = common MySQL functions options
#              <table_name> = name of a table
#
# MYSQL_GET_FIELD_TYPE
#   desc: Get the SQL type of a table field
#   usage: MYSQL_GET_FIELD_TYPE [ <options> ] <table_name> <field_name>
#   arguments: <options> = common MySQL functions options
#              <table_name> = name of a table
#              <field_name> = name of a field
# ----------------------------------------------------------------------------
# private functions
# =================
# private_PARSE_MYSQL_OPTIONS()
#   desc: parse arguments passed in argument
#   usage: private_PARSE_MYSQL_OPTIONS $@
#   notes:
#     1/ __MYSQL_*__ variables can be changes
#     2/ __MYSQL_OPTIONS_CHANGED__ = 'true' is options changed the mysql configuration
#     3/ this method doesn't call private_BUILD_MYSQL_OPTIONS()
#     4/ __MYSQL_NB_CONSUMMED_ARG__ contains number of arguments consummed
#   recommanded usage:
#     | private_PARSE_MYSQL_OPTIONS $@
#     | shift ${__MYSQL_NB_CONSUMMED_ARG__}
# 
# private_BUILD_MYSQL_OPTIONS()
#   desc: build the __MYSQL_OPTIONS__ variable which contain mysql commands
#         common options and will be passed to mysql commands
#   usage: private_PARSE_MYSQL_OPTIONS
#   notes:
#     1/ there is no argument/options
#     2/ this method can changes __MYSQL_OPTIONS__
#     3/ this method doesn't changes __MYSQL_OPTIONS_CHANGED__ value
#
# private_BACKUP_MYSQL_CONF()
#   desc: backup global mysql configuration
#
# private_RESTORE_MYSQL_CONF()
#   desc: restaure global mysql configuration
#
# ----------------------------------------------------------------------------

# -f Disable pathname expansion.
# -u Unset variables
set -fu

# Don't source this file several times
if [ "${__LIB_MYSQL__-}" != 'Loaded' ]; then
  __LIB_MYSQL__='Loaded'

  # Load common lib
  if [ "${__LIB_FUNCTIONS__-}" != "Loaded" ]; then
    if [ -r ./functions.lib.sh ]; then
      source ./functions.lib.sh
    else
      echo "ERROR: Unable to load ./functions.lib.sh library"
      exit 2
    fi
  fi

  # Internal variables
  # ---------------------------------------------------
  # Do not write to those variables.
  __MYSQL_USERNAME__=''
  __MYSQL_PASSWORD__=''
  __MYSQL_DATABASE__=''
  __MYSQL_HOST__='localhost'
  __MYSQL_PORT__='3306'
  __MYSQL_HUMAN__='false'
  __MYSQL_OPTIONS__=''

  __MYSQL_OPTIONS_CHANGED__='false'
  __MYSQL_NB_CONSUMMED_ARG__=0
  __MYSQL_DUMP_FILE__="/tmp/mysqldump_${RANDOM}.sql"
  __EXEC_OPTIONS__='' # options to pass to EXEC (see functions.lib.sh)

  # backup variables. si private_* functions
  __MYSQL_BACKUP_USERNAME__=''
  __MYSQL_BACKUP_PASSWORD__=''
  __MYSQL_BACKUP_DATABASE__=''
  __MYSQL_BACKUP_HOST__=''
  __MYSQL_BACKUP_PORT__=''
  __MYSQL_HUMAN__=''
  __MYSQL_BACKUP_OPTIONS__=''

  # PRIVATE METHODS ------------------------------------------------------------

  private_PARSE_MYSQL_OPTIONS() {
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

  private_BUILD_MYSQL_OPTIONS() {
    __MYSQL_OPTIONS__=''
    [ -n "${__MYSQL_USERNAME__}" ] && __MYSQL_OPTIONS__="${__MYSQL_OPTIONS__} -u'${__MYSQL_USERNAME__}'"
    [ -n "${__MYSQL_PASSWORD__}" ] && __MYSQL_OPTIONS__="${__MYSQL_OPTIONS__} -p'${__MYSQL_PASSWORD__}'"
    [ -n "${__MYSQL_DATABASE__}" ] && __MYSQL_OPTIONS__="${__MYSQL_OPTIONS__} -D '${__MYSQL_DATABASE__}'"
    [ -n "${__MYSQL_HOST__}"     ] && __MYSQL_OPTIONS__="${__MYSQL_OPTIONS__} -h '${__MYSQL_HOST__}'"
    [ -n "${__MYSQL_PORT__}"     ] && __MYSQL_OPTIONS__="${__MYSQL_OPTIONS__} -P '${__MYSQL_PORT__}'"
  }

  private_BACKUP_MYSQL_CONF() {
    __MYSQL_BACKUP_USERNAME__="${__MYSQL_USERNAME__}"
    __MYSQL_BACKUP_PASSWORD__="${__MYSQL_PASSWORD__}"
    __MYSQL_BACKUP_DATABASE__="${__MYSQL_DATABASE__}"
    __MYSQL_BACKUP_HOST__="${__MYSQL_HOST__}"
    __MYSQL_BACKUP_PORT__="${__MYSQL_PORT__}"
    __MYSQL_BACKUP_HUMAN__="${__MYSQL_HOST__}"
    __MYSQL_BACKUP_OPTIONS__="${__MYSQL_OPTIONS__}"
  }

  private_RESTORE_MYSQL_CONF() {
    __MYSQL_USERNAME__="${__MYSQL_BACKUP_USERNAME__}"
    __MYSQL_PASSWORD__="${__MYSQL_BACKUP_PASSWORD__}"
    __MYSQL_DATABASE__="${__MYSQL_BACKUP_DATABASE__}"
    __MYSQL_HOST__="${__MYSQL_BACKUP_HOST__}"
    __MYSQL_PORT__="${__MYSQL_BACKUP_PORT__}"
    __MYSQL_HUMAN__="${__MYSQL_BACKUP_HUMAN__}"
    __MYSQL_OPTIONS__="${__MYSQL_BACKUP_OPTIONS__}"
  }

  # PUBLIC METHODS -------------------------------------------------------------

  MYSQL_SET_CONF() {
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


  MYSQL_QUERY() {
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

  MYSQL_DUMP() {
    local mysqldump_options= error_redir=

    mysqldump_options="--no-create-db --opt --max_allowed_packet=67108864 --routines"
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
    EXEC_WITH_LOG echo -n '' ">'${__MYSQL_DUMP_FILE__}'"

    EXEC_WITH_CHECK mysqldump ${__MYSQL_OPTIONS__} ${mysqldump_options} ">${__MYSQL_DUMP_FILE__}" "${error_redir}"

    private_RESTORE_MYSQL_CONF
    __MYSQL_OPTIONS_CHANGED__='false'
  }

  MYSQL_RESTORE() {
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

  MYSQL_GET_BASES()  { MYSQL_QUERY $@ --bash 'SHOW DATABASES'; }
  MYSQL_GET_TABLES() { MYSQL_QUERY $@ --bash 'SHOW TABLES';    }


  MYSQL_GET_FIELDS() {
    local table_name=

    [ $# -eq 0 ] && FATAL "MYSQL_GET_FIELDS: wrong number of argument"

    # get the last argument
    if [ $# -gt 1 ]; then
      arguments=$( IFS=' ' echo "$*" )
      table_name="${arguments##* }"
      arguments=${arguments% $table_name}
    else
      table_name="$1"
      arguments=
    fi

    [ -z "${table_name}" ] && FATAL "MYSQL_GET_FIELDS: missing or incorrect table name"

    eval "MYSQL_QUERY --bash ${arguments} 'DESCRIBE \`${table_name}\`'" | tr $'\t'  ' ' | tr -s ' ' | cut -d' ' -f1
  }

  MYSQL_GET_FIELD_TYPE() {
    local table_name= field_name=

    [ $# -eq 0 ] && FATAL "MYSQL_GET_FIELDS: wrong number of argument"

    # get the last argument
    arguments=$( IFS=' ' echo "$*" )

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

    [ -z "${table_name}" ] && FATAL "MYSQL_GET_FIELD_TYPE: missing or incorrect table name"
    [ -z "${field_name}" ] && FATAL "MYSQL_GET_FIELD_TYPE: missing or incorrect field name"

    eval "MYSQL_QUERY --bash ${arguments} 'DESCRIBE \`${table_name}\`'" | tr $'\t' ' ' | grep "^${field_name} " | tr -s ' ' | cut  -d' ' -f2
  }

fi # end of: if [ "${__LIB_MYSQL__}" = 'Loaded' ]; then
