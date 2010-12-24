#
# Copyright (c) 2006-2010 Linagora
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
# This is a shell library for helping writing shell script for simples
# operations.
#
# Global variables ===========================================================
# IMPORTANT: Please to write to those variables
# __LIB_RANDOM__ : Indicate that this lib is loaded
# Methods ====================================================================
#
# RANDOM()
#   usage: RANDOM
#   desc: Echo-return a random number
#   note: don't use ${RANDOM} bashism things. use $(RANDOM) :-)
#
# ----------------------------------------------------------------------------

# don't source several times this file
if [ "${__LIB_RANDOM__:-}" != 'Loaded' ]; then
  __LIB_RANDOM__='Loaded'

  RANDOM () { dd if=/dev/urandom count=1 2> /dev/null | cksum | cut -f1 -d" " ; }
fi # end of: if [ "${__LIB_RANDOM__:-} != 'Loaded' ]; then
