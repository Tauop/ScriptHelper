#!/bin/bash
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

# -f Disable pathname expansion.
# -u Unset variables
set -fu

# Load library ---------------------------------------------------------------
LOAD() {
  if [ -r ../$1 ]; then
    . ../$1
  else
    echo "[ERROR] Unable to load $1"
    exit 1
  fi
}

LOAD random.lib.sh
LOAD message.lib.sh
LOAD ask.lib.sh
LOAD exec.lib.sh
LOAD mysql.lib.sh

# Make tests -----------------------------------------------------------------

TEST_FILE="/tmp/test.$(RANDOM)"
TEST_FILE2="${TEST_FILE}2"

check_TEST_FILE() {
  content=`cat ${TEST_FILE}`
  [ "${content}" != "$1" ] && FATAL "Test failed"
}

compare_TEST_FILES() {
  diff "${TEST_FILE}" "${TEST_FILE2}"
  [ $? -ne 0 ] && FATAL "Test failed"
}

mysql_username=
mysql_password=

ASK mysql_username 'local MySQL username:'
ASK --pass --allow-empty mysql_password 'local MySQL password:'

# MYSQL_SET_CONF -------------------------------------------------------------
DOTHIS "MYSQL_SET_CONF"
  MYSQL_SET_CONF --user "'${mysql_username}'" --pass "'${mysql_password}'"
OK

# MYSQL_QUERY ----------------------------------------------------------------
DOTHIS "MYSQL_QUERY"
  ( MYSQL_QUERY 'SELECT 1' ) >"${TEST_FILE}"
  check_TEST_FILE "1"
OK

DOTHIS "MYSQL_QUERY --human"
  ( MYSQL_QUERY --human 'SELECT 1' ) >"${TEST_FILE}"
  mysql -u"${mysql_username}" -p"${mysql_password}" -e 'SELECT 1' >"${TEST_FILE2}"
  compare_TEST_FILES
OK

DOTHIS "MYSQL_QUERY --db"
  ( MYSQL_QUERY --db mysql 'SELECT User FROM user LIMIT 0,5' ) >"${TEST_FILE}"
  mysql -u"${mysql_username}" -p"${mysql_password}" -D mysql -Bse 'SELECT User FROM user LIMIT 0,5' >"${TEST_FILE2}"
  compare_TEST_FILES
OK

test_db="TEST$(RANDOM)"
test_db2="${test_db}2"

ROLLBACK() {
  MYSQL_QUERY "DROP DATABASE \`${test_db}\`"
  MYSQL_QUERY "DROP DATABASE \`${test_db2}\`"
  rm -f "${TEST_FILE}" "${TEST_FILE2}"
}

create_database="CREATE DATABASE ${test_db}"
create_database2="CREATE DATABASE ${test_db2}"
create_table='CREATE TABLE IF NOT EXISTS `pma_history` (
    `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
    `id2` bigint(20) unsigned NOT NULL,
    `id3` bigint(20) unsigned NOT NULL,
    PRIMARY KEY (`id`)
  ) ENGINE=MyISAM'
insert='INSERT INTO `pma_history` (`id`, `id2`, `id3`) VALUES
   ( 1  , 2  , 3  ), ( 4  , 5  , 6  ), ( 7  , 8  , 9  ), ( 10 , 11 , 12 ),
   ( 13 , 14 , 15 ), ( 16 , 17 , 18 ), ( 19 , 20 , 21 );'

MYSQL_QUERY "${create_database}"
MYSQL_QUERY "${create_database2}"
MYSQL_QUERY --db "${test_db}" "${create_table}"
MYSQL_QUERY --db "${test_db}" "${insert}"


# MYSQL_GET_BASES ------------------------------------------------------------
DOTHIS "MYSQL_GET_BASES"
  has_test=$( MYSQL_GET_BASES | grep "^${test_db}$" | wc -l)
  [ "${has_test}" != "1" ] && FATAL "Test failed"
OK

# MYSQL_GET_TABLES -----------------------------------------------------------
DOTHIS "MYSQL_GET_TABLES"
  has_test=$( MYSQL_GET_TABLES --db "${test_db}" | grep "pma_history" | wc -l)
  [ "${has_test}" != "1" ] && FATAL "Test failed"
OK

# MYSQL_GET_FIELDS -----------------------------------------------------------
DOTHIS "MYSQL_GET_FIELDS"
  has_test=$( MYSQL_GET_FIELDS --db "${test_db}" "pma_history" | grep "id2" | wc -l)
  [ "${has_test}" != "1" ] && FATAL "Test failed"
OK

# MYSQL_GET_FIELDS -----------------------------------------------------------
DOTHIS "MYSQL_GET_FIELD_TYPE"
  field_type=$( MYSQL_GET_FIELD_TYPE --db "${test_db}" "pma_history" "id")
  [ "${field_type}" != "bigint(20)" ] && FATAL "Test failed"
OK

# MYSQL_DUMP & MYSQL_RESTORE ------------------------------------------------
DOTHIS "MYSQL_DUMP"
  MYSQL_DUMP "${TEST_FILE}" "${test_db}"
  mysqldump -u${mysql_username} -p${mysql_password} --no-create-db --opt --max_allowed_packet=67108864 --routines "${test_db}" >"${TEST_FILE2}"
  compare_TEST_FILES
  echo -n '' > "${TEST_FILE2}"
OK

DOTHIS "MYSQL_RESTORE"
  MYSQL_RESTORE "${TEST_FILE}" "${test_db2}"
  MYSQL_DUMP "${TEST_FILE2}" "${test_db2}"
  # delete database name in the dump file, so that we can compare them
  sed -i -e "s/${test_db2}//g" "${TEST_FILE2}" >/dev/null 2>/dev/null
  sed -i -e "s/${test_db}//g"  "${TEST_FILE}"  >/dev/null 2>/dev/null
  # delete dates
  sed -i -e "s/\(.*Dump completed on \).*$/\1/g" "${TEST_FILE2}" >/dev/null 2>/dev/null
  sed -i -e "s/\(.*Dump completed on \).*$/\1/g"  "${TEST_FILE}"  >/dev/null 2>/dev/null
  compare_TEST_FILES
OK

MYSQL_QUERY "DROP DATABASE ${test_db}"
MYSQL_QUERY "DROP DATABASE ${test_db2}"

find /tmp -maxdepth 1 -name "test.*" -exec rm -f {} \;

echo
echo "*** All Tests OK ***"
