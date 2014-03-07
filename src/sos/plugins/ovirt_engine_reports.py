## Copyright (C) 2014 Red Hat, Inc., Sandro Bonazzola <sbonazzo@redhat.com>

### This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2 of the License, or
## (at your option) any later version.

## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.

## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.


"""oVirt Engine Reports related information"""


from sos.plugintools import PluginBase


class ovirt_engine_reports(PluginBase):
    """oVirt Engine Reports related information"""

    def setup(self):
        self.addCopySpec('/var/log/ovirt-engine-reports')


# vim: expandtab tabstop=4 shiftwidth=4
