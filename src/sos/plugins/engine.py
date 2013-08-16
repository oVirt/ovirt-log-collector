import sos.plugintools


# Class name must be the same as file name and method names must not change
class engine(sos.plugintools.PluginBase):
    """oVirt related information"""

    def setup(self):
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
