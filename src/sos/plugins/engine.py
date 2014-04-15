import os
import re
import signal
import subprocess


import sos.plugintools


# Class name must be the same as file name and method names must not change
class engine(sos.plugintools.PluginBase):
    """oVirt related information"""

    DB_PASS_FILES = re.compile(
        flags=re.VERBOSE,
        pattern=r"""
        ^
        /etc/
        (rhevm|ovirt-engine)/
        engine.conf
        (\.d/.+.conf)?
        $
        """
    )

    DEFAULT_SENSITIVE_KEYS = (
        'ENGINE_DB_PASSWORD:ENGINE_PKI_TRUST_STORE_PASSWORD:'
        'ENGINE_PKI_ENGINE_STORE_PASSWORD'
    )

    optionList = [
        (
            'jbosstrace',
            'Enable oVirt Engine JBoss stack trace generation',
            '',
            True
        ),
        (
            'sensitive_keys',
            'Sensitive keys to be masked',
            '',
            DEFAULT_SENSITIVE_KEYS
        ),
    ]

    def __init__(self, pluginname, commons):
        sos.plugintools.PluginBase.__init__(self, pluginname, commons)

    def setup(self):
        if self.getOption('jbosstrace'):
            proc = subprocess.Popen(
                args=[
                    '/usr/bin/pgrep',
                    '-f',
                    'jboss',
                ],
                stdout=subprocess.PIPE,
            )
            output, err = proc.communicate()
            returncode = proc.returncode
            jboss_pids = set()
            if returncode == 0:
                jboss_pids = set([int(x) for x in output.splitlines()])
                proc = subprocess.Popen(
                    args=[
                        '/usr/bin/pgrep',
                        '-f',
                        'ovirt-engine',
                    ],
                    stdout=subprocess.PIPE,
                )
                engine_output, err = proc.communicate()
                if returncode == 0:
                    engine_pids = set(
                        [int(x) for x in engine_output.splitlines()]
                    )
                    jboss_pids.intersection_update(engine_pids)
                else:
                    self.soslog.error('Unable to get engine pids: %s' % err)
                    self.addAlert('Unable to get engine pids')
            else:
                self.soslog.error('Unable to get jboss pid: %s' % err)
                self.addAlert('Unable to get jboss pid')
            for pid in jboss_pids:
                try:
                    os.kill(pid, signal.SIGQUIT)
                except OSError as e:
                    self.soslog.error('Unable to send signal to %d' % pid, e)

        self.addForbiddenPath('/etc/ovirt-engine/.pgpass')
        self.addForbiddenPath('/etc/rhevm/.pgpass')
        # Copy engine config files.
        self.addCopySpec("/etc/ovirt-engine")
        self.addCopySpec("/etc/rhevm")
        self.addCopySpec("/var/log/ovirt-engine")
        self.addCopySpec("/var/log/rhevm")
        self.addCopySpec("/etc/sysconfig/ovirt-engine")
        self.addCopySpec("/usr/share/ovirt-engine/conf")
        self.addCopySpec("/var/log/ovirt-guest-agent")
        self.addCopySpec("/var/lib/ovirt-engine/setup-history.txt")
        self.addCopySpec("/var/lib/ovirt-engine/setup/answers")
        self.addCopySpec("/var/lib/ovirt-engine/external_truststore")
        self.addCopySpec("/var/tmp/ovirt-engine/config")

    def postproc(self):
        """
        Obfuscate sensitive keys.
        """
        self.doRegexSub(
            "/etc/ovirt-engine/engine-config/engine-config.properties",
            r"Password.type=(.*)",
            r'Password.type=********'
        )
        self.doRegexSub(
            "/etc/rhevm/rhevm-config/rhevm-config.properties",
            r"Password.type=(.*)",
            r'Password.type=********'
        )
        for filename in (
            'ovirt-engine.xml',
            'ovirt-engine_history/current/ovirt-engine.v1.xml',
            'ovirt-engine_history/ovirt-engine.boot.xml',
            'ovirt-engine_history/ovirt-engine.initial.xml',
            'ovirt-engine_history/ovirt-engine.last.xml',
        ):
            self.doRegexSub(
                "/var/tmp/ovirt-engine/config/%s" % filename,
                r"<password>(.*)</password>",
                r'<password>********</password>'
            )

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
