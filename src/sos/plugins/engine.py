import os
import signal
import subprocess


import sos.plugintools


# Class name must be the same as file name and method names must not change
class engine(sos.plugintools.PluginBase):
    """oVirt related information"""

    optionList = [
        (
            'jbosstrace',
            'Enable oVirt Engine JBoss stack trace generation',
            '',
            True
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

    def postproc(self):
        """
        Obfuscate passwords.
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
