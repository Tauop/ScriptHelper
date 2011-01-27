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
SCRIPT_HELPER_DIRECTORY='..'
[ -r /etc/ScriptHelper.conf ] && . /etc/ScriptHelper.conf

LOAD() {
  if [ -r "${SCRIPT_HELPER_DIRECTORY}/$1" ]; then
    . "${SCRIPT_HELPER_DIRECTORY}/$1"
  else
    echo "[ERROR] Unable to load $1"
    exit 1
  fi
}

LOAD message.lib.sh
LOAD ask.lib.sh
LOAD cli.lib.sh
LOAD random.lib.sh

help_file="/tmp/cli_test.help.$(RANDOM)"
CLI_REGISTER_HELP "${help_file}"

CLI_SET_PROMPT "cli"
CLI_REGISTER_MENU    "msg" 'help message'
CLI_REGISTER_COMMAND "msg hello"   "echo 'hello'"
CLI_REGISTER_COMMAND "msg reply <what>" "echo '\1'"
CLI_REGISTER_COMMAND "ping ? pong <target>[:<optional>]" "PING_PONG \2 \1" "Like to play ping-pong"

PING_PONG() { echo "$1 - $2"; }

input_file="/tmp/cli_test.in.$(RANDOM)"
output_file="/tmp/cli_test.out.$(RANDOM)"
expected_output_file="/tmp/cli_test.result_out.$(RANDOM)"

cat >"${input_file}" <<EOF
msg hello
msg
reply toto
prout
ping cat pong lol
quit
ping cat pong lol
msg reply lol
help ping
quit
EOF

cat >"${expected_output_file}" <<EOF
cli >  msg hello
hello
cli >  msg
cli [msg]>  reply toto
toto
cli [msg]>  prout
ERROR: Unknown CLI command
cli [msg]>  ping cat pong lol
ERROR: Unknown CLI command
cli [msg]>  quit
cli >  ping cat pong lol
lol - cat
cli >  msg reply lol
lol
cli >  help ping
ping ? pong <target>[:<optional>]	Like to play ping-pong
cli >  quit
EOF

ASK_SET_AUTOANSWER_FILE "${input_file}"

( CLI_RUN > "${output_file}" )
diff -au "${expected_output_file}" "${output_file}"
[ $? -eq 0 ] && ( echo ; echo "*** All Tests OK ***" )

find /tmp -maxdepth 1 -name "cli_test.*" -exec rm -f {} \;
