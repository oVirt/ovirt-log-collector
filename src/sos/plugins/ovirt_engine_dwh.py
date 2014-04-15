# Copyright (C) 2014 Red Hat, Inc., Sandro Bonazzola <sbonazzo@redhat.com>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.


"""oVirt Engine DWH related information"""


import re


from sos.plugintools import PluginBase


class ovirt_engine_dwh(PluginBase):
    """oVirt Engine DWH related information"""

    DB_PASS_FILES = re.compile(
        flags=re.VERBOSE,
        pattern=r"""
        ^
        /etc/
        ovirt-engine-dwh/
        .*
        """
    )

    DEFAULT_SENSITIVE_KEYS = (
        'DWH_DB_PASSWORD:ENGINE_DB_PASSWORD'
    )

    optionList = [
        (
            'sensitive_keys',
            'Sensitive keys to be masked',
            '',
            DEFAULT_SENSITIVE_KEYS
        ),
    ]

    def setup(self):
        self.addCopySpec('/etc/ovirt-engine-dwh')
        self.addCopySpec('/var/log/ovirt-engine-dwh')

    def postproc(self):
        """
        Obfuscate sensitive keys.
        """
        if self.getOption('sensitive_keys'):
            sensitive_keys = self.getOption('sensitive_keys')
            if self.getOption('sensitive_keys') is True:
                # Handle --alloptions case which set this to True.
                sensitive_keys = self.DEFAULT_SENSITIVE_KEYS
            key_list = [x for x in sensitive_keys.split(':') if x]
            for filename in self.copiedFiles:
                if self.DB_PASS_FILES.match(filename['srcpath']):
                    for key in key_list:
                        self.doRegexSub(
                            filename['srcpath'],
                            r'{key}=(.*)'.format(
                                key=key,
                            ),
                            r'{key}=********'.format(
                                key=key,
                            )
                        )


# vim: expandtab tabstop=4 shiftwidth=4
