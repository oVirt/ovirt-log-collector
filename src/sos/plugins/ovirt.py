# Copyright (C) 2014-2015 Red Hat, Inc., Sandro Bonazzola <sbonazzo@redhat.com>
# Copyright (C) 2014 Red Hat, Inc., Bryn M. Reeves <bmr@redhat.com>
# Copyright (C) 2010 Red Hat, Inc.

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

import os
import re
import signal


import sos.plugintools


# Class name must be the same as file name and method names must not change
class ovirt(sos.plugintools.PluginBase):
    """oVirt related information"""

    DB_PASS_FILES = re.compile(
        flags=re.VERBOSE,
        pattern=r"""
        ^
        /etc/
        (rhevm|ovirt-engine|ovirt-engine-dwh)/
        (engine.conf|ovirt-engine-dwhd.conf)
        (\.d/.+.conf)?
        $
        """
    )

    DEFAULT_SENSITIVE_KEYS = (
        'ENGINE_DB_PASSWORD:ENGINE_PKI_TRUST_STORE_PASSWORD:'
        'ENGINE_PKI_ENGINE_STORE_PASSWORD:DWH_DB_PASSWORD'
    )

    optionList = [
        (
            'jbosstrace', 'Enable oVirt Engine JBoss stack trace collection',
            '', True
        ),
        (
            'sensitive_keys', 'Sensitive keys to be masked', '',
            DEFAULT_SENSITIVE_KEYS
        )
    ]

    def __init__(self, pluginname, commons):
        sos.plugintools.PluginBase.__init__(self, pluginname, commons)
        self.packages = (
            'ovirt-engine',
            'ovirt-engine-dwh',
            'ovirt-engine-reports',
            'ovirt-scheduler-proxy',
            'rhevm',
            'rhevm-dwh',
            'rhevm-reports'
        )

    def setup(self):
        if self.getOption('jbosstrace'):
            engine_pattern = "^ovirt-engine\ -server.*jboss-modules.jar"
            pgrep = "pgrep -f '%s'" % engine_pattern
            lines = self.callExtProg(pgrep)[1].splitlines()
            engine_pids = [int(x) for x in lines]
            if not engine_pids:
                self.soslog.error('Unable to get ovirt-engine pid')
                self.addAlert('Unable to get ovirt-engine pid')
            for pid in engine_pids:
                try:
                    # backtrace written to '/var/log/ovirt-engine/console.log
                    os.kill(pid, signal.SIGQUIT)
                except OSError as e:
                    self.soslog.error('Unable to send signal to %d' % pid, e)

        self.addForbiddenPath('/etc/ovirt-engine/.pgpass')
        self.addForbiddenPath('/etc/rhevm/.pgpass')
        # Copy all engine tunables and domain information
        self.collectExtOutput("engine-config --all")
        self.collectExtOutput("engine-manage-domains list")
        # Copy engine config files.
        self.addCopySpecs([
            "/etc/ovirt-engine",
            "/etc/rhevm/",
            "/etc/ovirt-engine-dwh",
            "/etc/ovirt-engine-reports",
            "/var/log/ovirt-engine",
            "/var/log/ovirt-engine-dwh",
            "/var/log/ovirt-engine-reports",
            "/var/log/ovirt-scheduler-proxy",
            "/var/log/rhevm",
            "/etc/sysconfig/ovirt-engine",
            "/usr/share/ovirt-engine/conf",
            "/var/log/ovirt-guest-agent",
            "/var/lib/ovirt-engine/setup-history.txt",
            "/var/lib/ovirt-engine/setup/answers",
            "/var/lib/ovirt-engine/external_truststore",
            "/var/tmp/ovirt-engine/config",
            "/var/lib/ovirt-engine/jboss_runtime/config",
            "/var/lib/ovirt-engine-reports/jboss_runtime/config"
        ])

    def do_path_regex_sub(self, pathexp, regexp, subst):
        if not hasattr(pathexp, "match"):
            pathexp = re.compile(pathexp)
        match = pathexp.match
        file_list = [f for f in self.copiedFiles if match(f['srcpath'])]
        for fileobj in file_list:
            self.doRegexSub(fileobj['srcpath'], regexp, subst)

    def postproc(self):
        """
        Obfuscate sensitive keys.
        """
        self.doRegexSub(
            "/etc/ovirt-engine/engine-config/engine-config.properties",
            r"Password.type=(.*)",
            r"Password.type=********"
        )
        self.doRegexSub(
            "/etc/rhevm/rhevm-config/rhevm-config.properties",
            r"Password.type=(.*)",
            r"Password.type=********"
        )

        engine_files = (
            'ovirt-engine.xml',
            'ovirt-engine_history/current/ovirt-engine.v1.xml',
            'ovirt-engine_history/ovirt-engine.boot.xml',
            'ovirt-engine_history/ovirt-engine.initial.xml',
            'ovirt-engine_history/ovirt-engine.last.xml',
        )
        for filename in engine_files:
            self.doRegexSub(
                "/var/tmp/ovirt-engine/config/%s" % filename,
                r"<password>(.*)</password>",
                r"<password>********</password>"
            )

        self.doRegexSub(
            "/etc/ovirt-engine/redhatsupportplugin.conf",
            r"proxyPassword=(.*)",
            r"proxyPassword=********"
        )

        passwd_files = [
            "logcollector.conf",
            "imageuploader.conf",
            "isouploader.conf"
        ]
        for conf_file in passwd_files:
            conf_path = os.path.join("/etc/ovirt-engine", conf_file)
            self.doRegexSub(
                conf_path,
                r"passwd=(.*)",
                r"passwd=********"
            )
            self.doRegexSub(
                conf_path,
                r"pg-pass=(.*)",
                r"pg-pass=********"
            )

        sensitive_keys = self.DEFAULT_SENSITIVE_KEYS
        # Handle --alloptions case which set this to True.
        keys_opt = self.getOption('sensitive_keys')
        if keys_opt and keys_opt is not True:
            sensitive_keys = keys_opt
        key_list = [x for x in sensitive_keys.split(':') if x]
        for key in key_list:
            self.do_path_regex_sub(
                self.DB_PASS_FILES,
                r'{key}=(.*)'.format(key=key),
                r'{key}=********'.format(key=key)
            )

        # Answer files contain passwords
        for key in (
            'OVESETUP_CONFIG/adminPassword',
            'OVESETUP_CONFIG/remoteEngineHostRootPassword',
            'OVESETUP_DWH_DB/password',
            'OVESETUP_DB/password',
            'OVESETUP_REPORTS_CONFIG/adminPassword',
            'OVESETUP_REPORTS_DB/password',
        ):
            self.do_path_regex_sub(
                r'/var/lib/ovirt-engine/setup/answers/.*',
                r'{key}=(.*)'.format(key=key),
                r'{key}=********'.format(key=key)
            )


# vim: expandtab tabstop=4 shiftwidth=4
