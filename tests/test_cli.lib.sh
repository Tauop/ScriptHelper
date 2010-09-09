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

# Load library ---------------------------------------------------------------
LOAD() {
  if [ -r ../$1 ]; then
    . ../$1
  else
    echo "[ERROR] Unable to load $1"
    exit 1
  fi
}

LOAD message.lib.sh
LOAD ask.lib.sh
LOAD cli.lib.sh

CLI_SET_PROMPT "cli"
CLI_REGISTER_MENU    "msg"
CLI_REGISTER_COMMAND "msg hello"   "echo 'hello'"
CLI_REGISTER_COMMAND "msg reply ?" "echo '\1'"
CLI_REGISTER_COMMAND "ping ? pong ?" "PING_PONG \2 \1"

PING_PONG() { echo "$1 - $2"; }

input_file="/tmp/cli_test.in.${RANDOM}"
output_file="/tmp/cli_test.out.${RANDOM}"
expected_output_file="/tmp/cli_test.result_out.${RANDOM}"

cat >"${input_file}" <<EOF
msg hello
msg
reply toto
prout
ping cat pong lol
quit
ping cat pong lol
msg reply lol
quit
EOF

cat >"${expected_output_file}" <<EOF
cli > msg hello
hello
cli > msg
cli [msg]> reply toto
toto
cli [msg]> prout
ERROR: Unknown CLI command
cli [msg]> ping cat pong lol
ERROR: Unknown CLI command
cli [msg]> quit
cli > ping cat pong lol
lol - cat
cli > msg reply lol
lol
cli > quit
EOF

ASK_SET_AUTOANSWER_FILE "${input_file}"

( CLI_RUN > "${output_file}" )
diff -au "${expected_output_file}" "${output_file}"


rm -f "${input_file}"
rm -f "${output_file}"
rm -f "${expected_output_file}"
