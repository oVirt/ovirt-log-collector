#!/usr/bin/python3
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

from __future__ import absolute_import, print_function

import sys
import os
from optparse import OptionParser, OptionGroup, SUPPRESS_HELP
import subprocess
import shlex
import shutil
import pprint
import fnmatch
import traceback
import logging
import gettext
import getpass
import datetime
import dateutil.parser
import dateutil.tz as tz
import errno
import tempfile
import textwrap
import atexit
import time
import socket
import sos
import stat
import distro
import configparser
import glob

from copy import copy
from functools import partial


from ovirt_engine import configfile


from .helper import hypervisors
from ovirt_log_collector import config


DEFAULT_SSH_USER = 'root'
DEFAULT_TIME_SHIFT_FILE = 'time_diff.txt'
PGPASS_FILE_ADMIN_LINE = "DB ADMIN credentials"
DEFAULT_SCRATCH_DIR = None  # Will be initialized by __main__
SSH_SERVER_ALIVE_INTERVAL = 600
MAX_WARN_HOSTS_COUNT = 10

# {Logging system
STREAM_LOG_FORMAT = '%(levelname)s: %(message)s'
FILE_LOG_FORMAT = (
    '%(asctime)s::'
    '%(levelname)s::'
    '%(module)s::'
    '%(lineno)d::'
    '%(name)s::'
    ' %(message)s'
)
FILE_LOG_DSTMP = '%Y-%m-%d %H:%M:%S'
DEFAULT_LOG_FILE = os.path.join(
    config.DEFAULT_LOG_DIR,
    '{prefix}-{timestamp}.log'.format(
        prefix=config.LOG_PREFIX,
        timestamp=time.strftime('%Y%m%d%H%M%S'),
    )
)


class NotAnError(logging.Filter):

    def filter(self, entry):
        return entry.levelno < logging.ERROR
# }


class NoSosReportError(Exception):
    pass


# Default DB connection params
pg_user = 'postgres'
pg_pass = None
pg_dbname = 'engine'
pg_dbhost = 'localhost'
pg_dbport = '5432'

t = gettext.translation('logcollector', fallback=True)
try:
    _ = t.ugettext
except AttributeError:
    _ = t.gettext


def parse_config_file(config_file):
    """
    Parse config files without section like /etc/os-release
    and return a dict. If file not found None is returned.
    """
    parsed = {}

    try:
        with open(config_file, "r") as data:
            for line in data.readlines():
                if "=" not in line:
                    continue
                key, val = line.split("=", 1)
                parsed[key] = val.strip()[1:-1]
    except IOError:
        logging.error("%s doesn't exist" % config_file)
        raise

    return parsed


def get_pg_var(dbconf_param, user=None):
    '''
    Provides a mechanism to extract information from .pgpass.
    '''
    field = {'pass': 4, 'admin': 3, 'host': 0, 'port': 1}
    if dbconf_param not in list(field.keys()):
        raise ValueError(
            "Error: unknown value type '%s' was requested" % dbconf_param
        )
    inDbAdminSection = False
    try:
        with open(config.FILE_PG_PASS) as pgPassFile:
            logging.debug(
                "Found existing pgpass file, fetching DB"
                "%s value" % dbconf_param
            )
            for line in pgPassFile:

                # find the line with "DB ADMIN"
                if PGPASS_FILE_ADMIN_LINE in line:
                    inDbAdminSection = True
                    continue

                if inDbAdminSection and not line.startswith("#"):
                    # Means we're on DB ADMIN line, as it's for all DBs
                    dbcreds = line.split(":", 4)
                    return str(dbcreds[field[dbconf_param]]).strip()

                # Fetch the password if needed
                if (
                    dbconf_param == "pass" and
                    user and
                    not line.startswith("#")
                ):
                    dbcreds = line.split(":", 4)
                    if (
                        dbcreds and
                        len(dbcreds) >= 4 and
                        dbcreds[3] == user
                    ):
                        return dbcreds[field[dbconf_param]]
    except IOError as ioe:
        if ioe.errno != errno.ENOENT:
            raise ioe
    return None


def setup_pg_defaults():
    """
    Set defaults value to those read from config.ENGINE_CONF
    falling back to legacy .pgpass if needed.
    """
    global pg_user
    global pg_pass
    global pg_dbhost
    global pg_dbport
    global pg_dbname
    engine_config = configfile.ConfigFile([
        config.ENGINE_DEFAULTS,
        config.ENGINE_CONF,
    ])
    if engine_config.get('ENGINE_DB_PASSWORD'):
        pg_pass = engine_config.get('ENGINE_DB_PASSWORD')
        pg_user = engine_config.get('ENGINE_DB_USER')
        pg_dbname = engine_config.get('ENGINE_DB_DATABASE')
        pg_dbhost = engine_config.get('ENGINE_DB_HOST')
        pg_dbport = engine_config.get('ENGINE_DB_PORT')
    else:
        try:
            pg_user = get_pg_var('admin') or pg_user
            pg_pass = get_pg_var('pass', pg_user) or pg_pass
            pg_dbhost = get_pg_var('host') or pg_dbhost
            pg_dbport = get_pg_var('port') or pg_dbport
        except ValueError as ve:
            sys.stderr.write(
                _(
                    'Programming error in get_pg_var invocation: {error}\n'
                ).format(error=ve)
            )
            sys.exit(ExitCodes.CRITICAL)
        except EnvironmentError as e:
            sys.stderr.write(
                _(
                    'Warning: error while reading .pgpass configuration: '
                    '{error}\n'
                ).format(error=e)
            )
            ExitCodes.exit_code = ExitCodes.WARN


def multilog(logger, msg):
    for line in str(msg).splitlines():
        logger(line)


def get_from_prompt(msg, default=None, prompter=input):
    try:
        value = prompter(msg)
        if value.strip():
            return value.strip()
        else:
            return default
    except EOFError:
        print()
        return default


class ExitCodes():
    """
    A simple psudo-enumeration class to hold the current and future exit codes
    """
    NOERR = 0
    CRITICAL = 1
    WARN = 2
    exit_code = NOERR


class Caller(object):
    """
    Utility class for forking programs.
    """
    def __init__(self, configuration):
        self.configuration = configuration

    def prep(self, cmd):
        _cmd = cmd % self.configuration
        return shlex.split(_cmd)

    def call(self, cmds, raise_on_error=True):
        """Uses the configuration to fork a subprocess and run cmds."""
        _cmds = self.prep(cmds)
        logging.debug("calling(%s)" % _cmds)
        proc = subprocess.Popen(
            _cmds,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        stdout, stderr = proc.communicate()
        returncode = proc.returncode
        logging.debug("returncode(%s)" % returncode)
        logging.debug("STDOUT(%s)" % stdout)
        logging.debug("STDERR(%s)" % stderr)

        if returncode == 0:
            return stdout.decode("utf-8")
        else:
            if raise_on_error:
                raise Exception(stderr.decode("utf-8"))
            else:
                # Do nothing. We already logged above the errors, should be
                # enough for debugging issues.
                pass


class Configuration(dict):
    """This class is a dictionary subclass that knows how to read and """
    """handle our configuration. Resolution order is defaults -> """
    """configuration file -> command line options."""

    class SkipException(Exception):
        "This exception is raised when the user aborts a prompt"
        pass

    def __init__(self, parser=None):
        self.command = "collect"
        self.parser = parser
        self.options = None
        self.args = None

        # Immediately, initialize the logger to the INFO log level and our
        # logging format which is <LEVEL>: <MSG> and not the default of
        # <LEVEL>:<UID: <MSG>
        self.__initLogger(logging.INFO)

        if not parser:
            raise Exception("Configuration requires a parser")

        self.options, self.args = self.parser.parse_args()
        # At this point we know enough about the command line options
        # to test for verbose and if it is set we should re-initialize
        # the logger to DEBUG.  This will have the effect of printing
        # stack traces if there are any exceptions in this class.
        if getattr(self.options, "verbose"):
            self.__initLogger(logging.DEBUG)

        self.load_config_file()

        if self.options:
            # Need to parse again to override conf file options
            self.options, self.args = self.parser.parse_args(
                values=self.options
            )
            self.from_options(self.options, self.parser)
            # Need to parse out options from the option groups.
            self.from_option_groups(self.options, self.parser)

        if self.args:
            self.from_args(self.args)

        # Finally, all options from the command line and possibly a
        # configuration file have been processed.
        # We need to re-initialize the logger if the user has supplied
        # either --quiet processing or supplied a --log-file.
        # This will ensure that any further log messages throughout the
        # lifecycle of this program go to the log handlers that the user
        # has specified.
        if self.options.quiet and self.options.verbose:
            parser.error(
                _('Options --quiet and --verbose are mutually exclusive')
            )

        if self.options.log_file or self.options.quiet:
            level = logging.INFO
            if self.options.verbose:
                level = logging.DEBUG
            self.__initLogger(level, self.options.quiet, self.options.log_file)

    def __missing__(self, key):
        return None

    def load_config_file(self):
        """Loads the user-supplied config file or the system default.
           If the user supplies a bad filename we will stop."""

        conf_file = config.DEFAULT_CONFIGURATION_FILE

        if self.options and getattr(self.options, "conf_file"):
            conf_file = self.options.conf_file
            if (
                not os.path.exists(conf_file) and
                not os.path.exists("%s.d" % conf_file)
            ):
                raise Exception(
                    (
                        "The specified configuration file "
                        "does not exist.  File=(%s)"
                    ) % self.options.conf_file
                )

        self.from_file(conf_file)

    def from_option_groups(self, options, parser):
        for optGrp in parser.option_groups:
            for optGrpOpts in optGrp.option_list:
                opt_value = getattr(options, optGrpOpts.dest)
                if opt_value is not None:
                    self[optGrpOpts.dest] = opt_value

    def from_options(self, options, parser):
        for option in parser.option_list:
            if option.dest:
                opt_value = getattr(options, option.dest)
                if opt_value is not None:
                    self[option.dest] = opt_value

    def from_file(self, configFile):
        configs = []
        configDir = '%s.d' % configFile
        if os.path.exists(configFile):
            configs.append(configFile)
        configs += sorted(
            glob.glob(
                os.path.join(configDir, "*.conf")
            )
        )

        cp = configparser.ConfigParser()
        cp.read(configs)

        # backward compatibility with existing setup
        if cp.has_option('LogCollector', 'rhevm'):
            if not cp.has_option('LogCollector', 'engine'):
                cp.set(
                    'LogCollector',
                    'engine',
                    cp.get('LogCollector', 'rhevm')
                )
            cp.remove_option('LogCollector', 'rhevm')
        if cp.has_option('LogCollector', 'engine-ca'):
            if not cp.has_option('LogCollector', 'cert-file'):
                cp.set(
                    'LogCollector',
                    'cert-file',
                    cp.get('LogCollector', 'engine-ca')
                )
            cp.remove_option('LogCollector', 'engine-ca')

        # we want the items from the LogCollector section only
        try:
            opts = [
                "--%s=%s" % (k, v) for k, v in cp.items("LogCollector")
            ]
            (new_options, args) = self.parser.parse_args(
                args=opts, values=self.options
            )
            self.from_option_groups(new_options, self.parser)
            self.from_options(new_options, self.parser)
        except configparser.NoSectionError:
            pass

    def from_args(self, args):
        self.command = args[0]
        if self.command not in ('list', 'collect'):
            raise Exception("%s is not a valid command." % self.command)

    def prompt(self, key, msg):
        if key not in self:
            self._prompt(input, key, msg)

    def getpass(self, key, msg):
        if key not in self:
            self._prompt(getpass.getpass, key, msg)

    # This doesn't ask for CTRL+C to abort because KeyboardInterrupts don't
    # seem to behave the same way every time. Take a look at the link:
    # "http://stackoverflow.com/questions/4606942/\
    # why-cant-i-handle-a-keyboardinterrupt-in-python"
    def _prompt(self, prompt_function, key, msg=None):
        value = get_from_prompt(
            msg="Please provide the %s (CTRL+D to skip): " % msg,
            prompter=prompt_function
        )
        if value:
            self[key] = value
        else:
            raise self.SkipException

    def ensure(self, key, default=""):
        if key not in self:
            self[key] = default

    def has_all(self, *keys):
        return all(self.get(key) for key in keys)

    def has_any(self, *keys):
        return any(self.get(key) for key in keys)

    def __ensure_path_to_file(self, file_):
        dir_ = os.path.dirname(file_)
        if not os.path.exists(dir_):
            logging.info("%s does not exists. It will be created." % dir_)
            os.makedirs(dir_, 0o755)

    def __log_to_file(self, file_, level):
        try:
            self.__ensure_path_to_file(file_)
            hdlr = logging.FileHandler(filename=file_, mode='w')
            fmt = logging.Formatter(FILE_LOG_FORMAT, FILE_LOG_DSTMP)
            hdlr.setFormatter(fmt)
            logging.root.addHandler(hdlr)
            logging.root.setLevel(level)
        except Exception as e:
            logging.error("Could not configure file logging: %s" % e)

    def __log_to_stream(self, level):
        fmt = logging.Formatter(STREAM_LOG_FORMAT)
        # Errors should always be there, on stderr
        h_err = logging.StreamHandler(sys.stderr)
        h_err.setLevel(logging.ERROR)
        h_err.setFormatter(fmt)
        logging.root.addHandler(h_err)
        # Other logs should go to stdout
        sh = logging.StreamHandler(sys.stdout)
        sh.setLevel(level)
        sh.setFormatter(fmt)
        sh.addFilter(NotAnError())
        logging.root.addHandler(sh)

    def __initLogger(self, logLevel=logging.INFO, quiet=None, logFile=None):
        """
        Initialize the logger based on information supplied from the
        command line or configuration file.
        """
        # If you call basicConfig more than once without removing handlers
        # it is effectively a noop. In this program it is possible to call
        # __initLogger more than once as we learn information about what
        # options the user has supplied in either the config file or
        # command line; hence, we will need to load and unload the handlers
        # to ensure consistently fomatted output.
        log = logging.getLogger()
        for h in list(log.handlers):
            log.removeHandler(h)

        if quiet:
            if logFile:
                # Case: Batch and log file supplied.  Log to only file
                self.__log_to_file(logFile, logLevel)
            else:
                # If the user elected quiet mode *and* did not supply
                # a file.  We will be *mostly* quiet but not completely.
                # If there is an exception/error/critical we will print
                # to stdout/stderr.
                logging.basicConfig(
                    level=logging.ERROR,
                    format=STREAM_LOG_FORMAT
                )
        else:
            if logFile:
                # Case: Not quiet and log file supplied.
                # Log to both file and stdout/stderr
                self.__log_to_file(logFile, logLevel)
                self.__log_to_stream(logLevel)
            else:
                # Case: Not quiet and no log file supplied.
                # Log to only stdout/stderr
                self.__log_to_stream(logLevel)


class CollectorBase(object):
    def __init__(self,
                 hostname,
                 configuration=None,
                 **kwargs):
        self.hostname = hostname
        if configuration:
            self.configuration = configuration.copy()
        else:
            self.configuration = {}
        self.prep()
        self.caller = Caller(self.configuration)

    def prep(self):
        self.configuration['ssh_cmd'] = self.format_ssh_command()
        self.configuration['scp_cmd'] = self.format_ssh_command(cmd="scp")

    def get_key_file(self):
        return self.configuration.get("key_file")

    def get_ssh_user(self):
        return "%s@" % DEFAULT_SSH_USER

    def parse_sosreport_stdout(self, stdout):
        def reportFinder(line):
            if fnmatch.fnmatch(line, '*sosreport-*tar*'):
                return line
            else:
                return None

        def sha256Finder(line):
            if fnmatch.fnmatch(line, 'The sha256sum is*'):
                return line
            else:
                return None

        try:
            lines = stdout.splitlines()
            fileAry = list(filter(reportFinder, lines))
            self.configuration["filename"] = None
            self.configuration["path"] = None
            if fileAry is not None:
                if len(fileAry) > 0 and fileAry[0] is not None:
                    path = fileAry[0].strip()
                    filename = os.path.basename(path)
                    self.configuration["filename"] = filename
                    if os.path.isabs(path):
                        self.configuration["path"] = path
                    else:
                        self.configuration["path"] = os.path.join(
                            self.configuration["local_tmp_dir"], filename
                        )
            if self.configuration["filename"] is None:
                raise NoSosReportError("Could not parse sosreport output")
            fileAry = list(filter(sha256Finder, lines))
            self.configuration["checksum"] = None
            if fileAry is not None and len(fileAry) > 0:
                if fileAry[0] is not None:
                    sha256sum = fileAry[0].partition(": ")[-1]
                    self.configuration["checksum"] = sha256sum

            logging.debug("filename(%s)" % self.configuration["filename"])
            logging.debug("path(%s)" % self.configuration["path"])
            logging.debug("checksum(%s)" % self.configuration["checksum"])
        except IndexError as e:
            logging.debug("message(%s)" % e)
            logging.debug(
                "parse_sosreport_stdout: " + traceback.format_exc()
            )
            raise Exception(
                "Could not parse sosreport output to determine filename"
            )

    def format_ssh_command(self, cmd="ssh"):
        cmd = "/usr/bin/%s " % cmd

        # disable reading from stdin
        if cmd.startswith("/usr/bin/ssh"):
            cmd += "-n "

        if "ssh_port" in self.configuration:
            port_flag = "-p" if cmd.startswith("/usr/bin/ssh") else "-P"
            cmd += port_flag + " %(ssh_port)s " % self.configuration

        if self.get_key_file():
            cmd += "-i %s " % self.get_key_file()

        # ignore host key checking
        cmd += "-oStrictHostKeyChecking=no "
        # keep alive the connection
        cmd += '-oServerAliveInterval=%d ' % SSH_SERVER_ALIVE_INTERVAL

        cmd += self.get_ssh_user()

        return cmd + "%s" % self.hostname


class HyperVisorData(CollectorBase):
    TIME_DRIFT_FORMAT = "%-17s : %-33s : %-33s : %-35s"
    TIME_DRIFT_HEADER = TIME_DRIFT_FORMAT % (
        'Node',
        'Node Time',
        'Engine Time',
        'Clock Drift Between Engine and Node'
    )

    def __init__(self,
                 hostname,
                 configuration=None,
                 semaphore=None,
                 queue=None,
                 gluster_enabled=False,
                 time_diff_only=False,
                 dump_volume_chains=False,
                 **kwargs):
        super(HyperVisorData, self).__init__(hostname, configuration)
        self.semaphore = semaphore
        self.queue = queue
        self.gluster_enabled = gluster_enabled
        self.time_diff_only = time_diff_only
        self.dump_volume_chains = dump_volume_chains

    def prep(self):
        self.configuration["hostname"] = self.hostname
        self.configuration['ssh_cmd'] = self.format_ssh_command()
        self.configuration['scp_cmd'] = self.format_ssh_command(cmd="scp")
        self.configuration['reports'] = ",".join((
            "libvirt",
            "vdsm",
            "networking",
            "hardware",
            "process",
            "yum",
            "filesys",
            "devicemapper",
            "selinux",
            "kernel",
            "memory",
            "rpm",
        ))

        reports3 = [
            "processor",
            "pci",
            "md",
            "block",
            "general",
            "scsi",
            "multipath",
            "systemd",
            "sanlock",
            "lvm2",
            "chrony",
            "systemd",
            "ipmitool",
        ]

        reports32 = copy(reports3) + [
            "firewalld",
            "openvswitch",
            "ovirt_hosted_engine",
        ]

        reports33 = copy(reports32) + [
            "virsh",
        ]

        reports34 = copy(reports33) + [
            "collectd",
        ]

        reports35 = copy(reports34) + [
            "ovirt_imageio",
        ]

        # In 3.6 general plugin was split by date and host
        reports36 = copy(reports35) + [
            "date",
            "host",
            "ovirt_node",
            "ovn_host"
        ]
        reports36.remove("general")

        self.configuration['reports3'] = ",".join(reports3)
        self.configuration['reports32'] = ",".join(reports32)
        self.configuration['reports33'] = ",".join(reports33)
        self.configuration['reports34'] = ",".join(reports34)
        self.configuration['reports35'] = ",".join(reports35)
        self.configuration['reports36'] = ",".join(reports36)

        # these are the reports that will work with rhev2.2 hosts
        self.configuration['bc_reports'] = \
            "vdsm,general,networking,hardware,process,yum,filesys"

    def get_time_diff(self, stdout):
        h_time = dateutil.parser.parse(stdout.strip())
        l_time = datetime.datetime.now(tz=tz.tzlocal())

        logging.debug(
            "host <%s> time: %s" % (
                self.configuration["hostname"],
                h_time.isoformat()
            )
        )
        logging.debug(
            "local <%s> time: %s" % ("localhost", l_time.isoformat(),)
        )

        if h_time > l_time:
            tmp = self.TIME_DRIFT_FORMAT % (
                "%(hostname)s " % self.configuration,
                h_time,
                l_time,
                "+%s" % (h_time - l_time)
            )

            self.queue.append(tmp)
        else:
            tmp = self.TIME_DRIFT_FORMAT % (
                "%(hostname)s " % self.configuration,
                h_time,
                l_time,
                "-%s" % (l_time - h_time)
            )
            self.queue.append(tmp)

    def sosreport(self):
        # Add gluster to the list of sosreports required if gluster is enabled
        if self.gluster_enabled:
            logging.info(
                "Gluster logs will be collected from %s" % self.hostname
            )
            self.configuration['reports'] += ",gluster"

        cmd = """%(ssh_cmd)s "
VERSION=`/bin/rpm -q --qf '[%%{{VERSION}}]' \
    sos | /bin/sed 's/\\.//' | /bin/sed 's/\\..//'`;
if [ "$VERSION" -ge "36" ]; then
    /usr/sbin/sosreport {option} {log_size} {dump_volume_chains} --batch \
        --all-logs -o logs,%(reports)s,%(reports36)s
elif [ "$VERSION" -ge "35" ]; then
    /usr/sbin/sosreport {option} {log_size} {dump_volume_chains} --batch \
        --all-logs -o logs,%(reports)s,%(reports35)s
elif [ "$VERSION" -ge "34" ]; then
    /usr/sbin/sosreport {option} {log_size} --batch --all-logs \
        -o logs,%(reports)s,%(reports34)s
elif [ "$VERSION" -ge "33" ]; then
    /usr/sbin/sosreport {option} {log_size} --batch --all-logs \
        -o logs,%(reports)s,%(reports33)s
elif [ "$VERSION" -ge "32" ]; then
    /usr/sbin/sosreport {option} {log_size} --batch --all-logs \
        -o logs,%(reports)s,%(reports32)s
elif [ "$VERSION" -ge "30" ]; then
    /usr/sbin/sosreport {option} {log_size} --batch -k logs.all_logs=True \
        -o logs,%(reports)s,%(reports3)s
elif [ "$VERSION" -ge "22" ]; then
    /usr/sbin/sosreport {option} {log_size} --batch -k general.all_logs=True \
        -o general,%(reports)s
elif [ "$VERSION" -ge "17" ]; then
    /usr/sbin/sosreport {option} {log_size} --no-progressbar -k
        general.all_logs=True -o %(bc_reports)s
else
    /bin/echo "No valid version of sosreport found." 1>&2
    exit 1
fi
"
        """

        if self.configuration.get("ticket_number"):
            cmd = partial(cmd.format, option='--ticket-number={number}'.format(
                number=self.configuration.get("ticket_number")
            ))
        else:
            cmd = partial(cmd.format, option='')

        dump_chains_option = ""
        if self.dump_volume_chains:
            plugins = self.caller.call("%(ssh_cmd)s sosreport --list-plugins")
            if 'vdsm.dump-volume-chains' in plugins:
                dump_chains_option = '-k vdsm.dump-volume-chains'
            else:
                logging.warning("Host %r sosreport does not support option "
                                "vdsm.dump-volume-chains", self.hostname)
        cmd = partial(cmd, dump_volume_chains=dump_chains_option)

        if self.configuration.get('log_size'):
            cmd = cmd(log_size='--log-size={size}'.format(
                size=self.configuration.get('log_size')
            ))
        else:
            cmd = cmd(log_size="")

        return self.caller.call(cmd)

    def run(self):

        try:
            logging.info(
                "collecting information from %(hostname)s" % self.configuration
            )
            if not self.time_diff_only:
                stdout = self.sosreport()
                self.parse_sosreport_stdout(stdout)
                self.configuration["hypervisor_dir"] = os.path.join(
                    self.configuration.get("local_scratch_dir"),
                    self.configuration.get("hostname")
                )
                os.mkdir(self.configuration["hypervisor_dir"])
                self.configuration['archive_name'] = "%s-%s" % (
                    self.configuration.get("hostname"),
                    os.path.basename(self.configuration.get("path"))
                )
                self.caller.call(
                    '%(scp_cmd)s:%(path)s %(hypervisor_dir)s/%(archive_name)s'
                )
                self.caller.call('%(ssh_cmd)s "/bin/rm %(path)s*"')
                stdout = self.caller.call(
                    '%(ssh_cmd)s "/bin/ls -lRZ /etc /var /rhev"',
                    raise_on_error=False
                )
                self.configuration['selinux_dir'] = os.path.join(
                    self.configuration.get('hypervisor_dir'),
                    'selinux',
                )
                os.mkdir(self.configuration['selinux_dir'])
                with open(
                    os.path.join(
                        self.configuration['selinux_dir'],
                        'ls_-lRZ_etc_var_rhev',
                    ),
                    'w',
                ) as f:
                    f.write(stdout)

            stdout = self.caller.call('%(ssh_cmd)s "date --iso-8601=seconds"')
            try:
                self.get_time_diff(stdout)
            except ValueError as e:
                logging.debug("get_time_diff: " + str(e))
        except NoSosReportError as s:
            ExitCodes.exit_code = ExitCodes.CRITICAL
            logging.error(
                "Failed to get a sosreport from: %s; %s" % (
                    self.configuration.get("hostname"),
                    s
                )
            )
        except Exception as e:
            ExitCodes.exit_code = ExitCodes.WARN
            logging.error(
                "Failed to collect logs from: %s; %s" % (
                    self.configuration.get("hostname"),
                    e
                )
            )
            multilog(logging.debug, traceback.format_exc())
            logging.debug(
                "Configuration for %(hostname)s:" % self.configuration
            )
            multilog(logging.debug, pprint.pformat(self.configuration))
        finally:
            if self.semaphore:
                self.semaphore.release()

        logging.info(
            "finished collecting information from %(hostname)s" % (
                self.configuration
            )
        )


class ENGINEData(CollectorBase):
    def __init__(self, hostname, configuration=None, **kwargs):
        super(ENGINEData, self).__init__(hostname, configuration)
        self.sos_version = sos.__version__.replace('.', '')
        self._plugins = self.caller.call('sosreport --list-plugins')
        if 'ovirt.sensitive_keys' in self._plugins:
            self._engine_plugin = 'ovirt'
        elif 'ovirt-engine.sensitive_keys' in self._plugins:
            self._engine_plugin = 'ovirt-engine'
        elif 'engine.sensitive_keys' in self._plugins:
            self._engine_plugin = 'engine'
        else:
            logging.error('ovirt plugin not found, falling back on default')
            self._engine_plugin = 'ovirt'
        self.dwh_prep()

    def prep(self):
        super(ENGINEData, self).prep()
        engine_service_config = configfile.ConfigFile([
            config.ENGINE_SERVICE_DEFAULTS,
        ])
        if engine_service_config.get('SENSITIVE_KEYS'):
            self.configuration['sensitive_keys'] = engine_service_config.get(
                'SENSITIVE_KEYS'
            ).replace(',', ':')

    def dwh_prep(self):
        dwh_service_config = configfile.ConfigFile([
            config.ENGINE_DWH_SERVICE_DEFAULTS,
        ])
        if dwh_service_config.get('SENSITIVE_KEYS'):
            dwh_sensitive_keys = dwh_service_config.get(
                'SENSITIVE_KEYS'
            ).replace(',', ':')
            if 'ovirt_engine_dwh.sensitive_keys' in self._plugins:
                self.configuration['dwh_sensitive_keys'] = dwh_sensitive_keys
            else:
                if self.configuration['sensitive_keys']:
                    self.configuration['sensitive_keys'] += dwh_sensitive_keys
                else:
                    self.configuration['sensitive_keys'] = dwh_sensitive_keys

    def build_options(self):
        """
        returns the parameters for sosreport execution on the local host
        running ovirt-engine service.
        """
        opts = [
            "-k rpm.rpmva=off",
            "-k apache.log=True",
        ]

        if (
            'yum.yum-history-info' in self._plugins or
            'dnf.history-info' in self._plugins
        ):
            this_distro = distro.linux_distribution(
                full_distribution_name=0
            )[0].lower()
            version_id = parse_config_file("/etc/os-release")["VERSION_ID"]
            if this_distro in ('redhat', 'centos') \
               and float(version_id) <= 7.99:
                opts.append('-k yum.yum-history-info=on')
            else:
                opts.append('-k dnf.history-info=on -k dnf.history=on')

        sensitive_keys = {
            self._engine_plugin: 'sensitive_keys',
            'ovirt_engine_dwh': 'dwh_sensitive_keys',
        }
        if self.configuration['include_sensitive_data']:
            for plugin in sensitive_keys:
                self.configuration[sensitive_keys[plugin]] = ':'

        for plugin in sensitive_keys:
            if self.configuration.get(sensitive_keys[plugin]):
                opts.append(
                    '-k {plugin}.sensitive_keys={keys}'.format(
                        plugin=plugin,
                        keys=self.configuration.get(sensitive_keys[plugin]),
                    )
                )

        if self.configuration.get("ticket_number"):
            opts.append(
                "--ticket-number=%s" % self.configuration.get("ticket_number")
            )

        if self.configuration.get("log_size"):
            opts.append(
                "--log-size=%s" %
                self.configuration.get('log_size')
            )

        if self.configuration.get("upload"):
            opts.append("--upload=%s" % self.configuration.get("upload"))
        if self.sos_version < '30':
            opts.append('--report')
            opts.append("-k general.all_logs=True")
        elif self.sos_version < '32':
            opts.append("-k logs.all_logs=True")
        else:
            opts.append("--all-logs")
        return " ".join(opts)

    def sosreport(self):
        sos_plugins = [
            self._engine_plugin,
            "rpm",
            "libvirt",
            "networking",
            "hardware",
            "process",
            "yum",
            "filesys",
            "devicemapper",
            "selinux",
            "kernel",
            "apache",
            "memory",
        ]
        if self.sos_version >= '30':
            sos_plugins.extend([
                "block",
                "java",
                "lvm2",
                "md",
                "pci",
                "processor",
                "scsi",
                "chrony",
                "systemd",
            ])
        if self.sos_version >= '32':
            sos_plugins.extend([
                "firewalld",
                "openvswitch",
            ])
        if self.sos_version >= '34':
            sos_plugins.extend([
                "collectd",
            ])
        if self.sos_version >= '35':
            sos_plugins.extend([
                "ovirt_imageio",
            ])

        # general plugin was removed and split (date and host) in sos 3.6.x
        # sos commit: 971b9581779da20384f0a4d8de5177c0b87d6892
        if self.sos_version < '36':
            sos_plugins.extend([
                "general",
            ])

        if self.sos_version >= '36':
            sos_plugins.extend([
                "date",
                "host",
                "ovn_central",
                "grafana",
            ])
            # rhv_analyzer plugin included in sos 3.6.5
            if 'rhv_analyzer' in self._plugins:
                sos_plugins.extend([
                    "rhv_analyzer",
                ])

        if 'ovirt_provider_ovn' in self._plugins:
            sos_plugins.append('ovirt_provider_ovn')
        self.configuration["sos_options"] = self.build_options()
        self.configuration["reports"] = ",".join(sos_plugins)
        if (
            'logs.all_logs' in self.configuration['sos_options'] or
            '--all-logs' in self.configuration['sos_options']
        ):
            self.configuration['reports'] += ',logs'
        if 'ovirt_engine_dwh.sensitive_keys' in self._plugins:
            self.configuration['reports'] += ',ovirt_engine_dwh'
        if 'ovirt_engine_reports' in self._plugins:
            self.configuration['reports'] += ',ovirt_engine_reports'

        self.caller.call(
            "sosreport --batch --build \
            --tmp-dir='%(local_working_dir)s' -o %(reports)s %(sos_options)s"
        )


class PostgresData(CollectorBase):

    def __init__(self, hostname, configuration=None, **kwargs):
        super(PostgresData, self).__init__(hostname, configuration)
        self._postgres_plugin = 'postgresql'

    def get_key_file(self):
        """
        Override the base get_key_file method to return the SSH key for the
        PostgreSQL system if there is one.  Returns None if there isn't one.
        """
        return self.configuration.get("pg_host_key")

    def get_ssh_user(self):
        """
        Override the base get_ssh_user method to return the SSH user for the
        PostgreSQL system if there is one.
        """
        if self.configuration.get("pg_ssh_user"):
            return "%s@" % self.configuration.get("pg_ssh_user")
        else:
            return "%s@" % DEFAULT_SSH_USER

    def sosreport(self):
        opt = ""
        if self.configuration.get("ticket_number"):
            opt += '--ticket-number=%(ticket_number)s '

        if self.configuration.get("log_size"):
            opt += '--log-size=%(log_size)s '

        if sos.__version__.replace('.', '') < '30':
            opt += '--report '

        if self.configuration.get('pg_pass'):
            opt += (
                '-k {plugin}.dbname=%(pg_dbname)s '
                '-k {plugin}.dbhost=%(pg_dbhost)s '
                '-k {plugin}.dbport=%(pg_dbport)s '
                '-k {plugin}.username=%(pg_user)s '
            ).format(
                plugin=self._postgres_plugin,
            )
            os.putenv('PGPASSWORD', str(self.configuration.get('pg_pass')))
            cmdline = (
                '/usr/sbin/sosreport --batch -o {plugin} '
                '--tmp-dir=%(local_scratch_dir)s ' + opt
            ).format(
                plugin=self._postgres_plugin,
            )
            stdout = self.caller.call(cmdline)
            self.parse_sosreport_stdout(stdout)

            # Prepend postgresql- to the extension file that is produced by SOS
            # so that it is easy to distinguish from the other N reports
            # that are all related to hypervisors.

            # Files extension output for FIPS mode
            md5_file = "%s.md5" % self.configuration["path"]
            sha256_file = "%s.sha256" % self.configuration["path"]

            # FIPS mode disabled
            if os.path.exists(md5_file):
                sumfile_path = md5_file
            # FIPS mode enabled
            elif os.path.exists(sha256_file):
                sumfile_path = sha256_file

            os.rename(
                sumfile_path,
                os.path.join(
                    self.configuration["local_scratch_dir"],
                    "postgresql-%s" % os.path.basename(sumfile_path)
                )
            )
        # Prepend postgresql- to the PostgreSQL SOS report
        # so that it is easy to distinguish from the other N reports
        # that are all related to hypervisors.
        os.rename(
            os.path.join(
                self.configuration["local_scratch_dir"],
                self.configuration["filename"]
            ),
            os.path.join(
                self.configuration["local_scratch_dir"],
                "postgresql-%s" % self.configuration["filename"]
            )
        )


class LogCollector(object):

    def __init__(self, configuration):
        self.conf = configuration
        if self.conf.command is None:
            raise Exception("No command specified.")

    def archive(self):
        """
        Create a single tarball with collected data from engine, postgresql
        and all hypervisors.
        """
        logging.info(_('Creating compressed archive...'))

        report_file_ext = 'bz2'
        compressor = 'bzip2'
        caller = Caller({})
        try:
            caller.call('xz --version')
            report_file_ext = 'xz'
            compressor = 'xz'
        except Exception:
            logging.debug('xz compression not available')

        if not os.path.exists(self.conf["output"]):
            os.makedirs(self.conf["output"])

        self.conf["path"] = os.path.join(
            self.conf["output"],
            "sosreport-%s-%s.tar.%s" % (
                'LogCollector',
                time.strftime("%Y%m%d%H%M%S"),
                report_file_ext
            )
        )

        if self.conf["ticket_number"]:
            self.conf["path"] = os.path.join(
                self.conf["output"],
                "sosreport-%s-%s-%s.tar.%s" % (
                    'LogCollector',
                    self.conf["ticket_number"],
                    time.strftime("%Y%m%d%H%M%S"),
                    report_file_ext
                )
            )

        config = {
            'report': os.path.splitext(self.conf['path'])[0],
            'compressed_report': self.conf['path'],
            'compressor': compressor,
            'directory': self.conf["local_tmp_dir"],
            'rname': os.path.basename(self.conf['path']).split('.')[0],
        }
        caller.configuration = config
        shutil.move(
            os.path.join(
                self.conf["local_tmp_dir"],
                'working'
            ),
            os.path.join(
                self.conf["local_tmp_dir"],
                config["rname"]
            ),
        )
        caller.call("tar -cf '%(report)s' -C '%(directory)s' '%(rname)s'")
        shutil.rmtree(self.conf["local_tmp_dir"])
        caller.call("%(compressor)s -1 '%(report)s'")
        os.chmod(self.conf["path"], stat.S_IRUSR | stat.S_IWUSR)
        sha256_out = caller.call("sha256sum '%(compressed_report)s'")
        checksum = sha256_out.split()[0]
        with open("%s.sha256" % self.conf["path"], 'w') as checksum_file:
            checksum_file.write(sha256_out)

        msg = ''
        if os.path.exists(self.conf["path"]):
            archiveSize = float(os.path.getsize(self.conf["path"])) / (1 << 20)

            size = '%.1fM' % archiveSize

            msg = _(
                'Log files have been collected and placed in {path}\n'
                'The sha256 for this file is {checksum} and its size is {size}'
            ).format(
                path=self.conf["path"],
                size=size,
                checksum=checksum,
            )

            if archiveSize >= 1000:
                msg += _(
                    '\nYou can use the following filters -c, -d, -H in the '
                    'next execution to limit the number of Datacenters,\n'
                    'Clusters or Hosts that are collected in order to '
                    'reduce the archive size.'
                )
        return msg

    def write_time_diff(self, queue):
        local_scratch_dir = self.conf.get("local_scratch_dir")
        filepath = os.path.join(local_scratch_dir, DEFAULT_TIME_SHIFT_FILE)
        with open(filepath, "w") as fd:
            fd.write(HyperVisorData.TIME_DRIFT_HEADER + "\n")
            for record in queue:
                fd.write(record + "\n")

    def _get_hypervisors_from_api(self):
        if not self.conf:
            raise Exception("No configuration.")

        with_kerberos = bool(self.conf.get("kerberos"))

        if not self.conf.get("quiet") and not self.conf.get("batch"):
            try:
                self.conf.prompt("engine", msg="hostname of oVirt Engine")
                if not with_kerberos:
                    self.conf.prompt(
                        "user",
                        msg="REST API username for oVirt Engine"
                    )
                    self.conf.getpass(
                        "passwd",
                        msg=(
                            "REST API password for the %{user} "
                            "oVirt Engine user"
                        ).format(user=self.conf.get("user"))
                    )
            except Configuration.SkipException:
                logging.info(
                    "Will not collect hypervisor list from oVirt Engine API."
                )
                raise

        try:
            return hypervisors.get_all(self.conf.get("engine"),
                                       self.conf.get("user"),
                                       self.conf.get("passwd"),
                                       self.conf.get("cert_file"),
                                       self.conf.get("insecure"),
                                       with_kerberos)
        except Exception as e:
            ExitCodes.exit_code = ExitCodes.WARN
            logging.error("_get_hypervisors_from_api: %s" % e)
            return set()

    @staticmethod
    def _sift_patterns(list_):
        """Returns two sets: patterns and others. A pattern is any string
           that contains the any of the following: * [ ] ?"""
        patterns = set()
        others = set()

        try:
            for candidate in list_:
                if any(c in candidate for c in ('*', '[', ']', '?')):
                    patterns.add(candidate)
                else:
                    others.add(candidate)
        except TypeError:
            pass

        return patterns, others

    def _filter_hosts(self, which, pattern):
        logging.debug(
            "filtering host list with %s against %s name" % (pattern, which)
        )

        if which == "host":
            return set([
                (dc, cl, h, is_spm, is_up) for
                dc, cl, h, is_spm, is_up in self.conf.get("hosts")
                if fnmatch.fnmatch(h, pattern)
            ])
        elif which == "cluster":
            return set([
                (dc, cl, h, is_spm, is_up) for
                dc, cl, h, is_spm, is_up in self.conf.get("hosts")
                if fnmatch.fnmatch(cl.name, pattern)
            ])
        elif which == "datacenter":
            return set([
                (dc, cl, h, is_spm, is_up) for
                dc, cl, h, is_spm, is_up in self.conf.get("hosts")
                if fnmatch.fnmatch(dc, pattern)
            ])

    def set_hosts(self, hypervisor_per_cluster=False):
        """
        Fetches the hostnames for the supplied cluster or datacenter.
        Filtering is applied if patterns are found in the --hosts, --cluster
        or --datacenters options. There can be multiple patterns in each
        option. Patterns found within the same option are inclusive and
        each option set together is treated as an intersection.
        """

        self.conf['hosts'] = set()

        host_patterns, host_others = self._sift_patterns(
            self.conf.get('hosts_list')
        )
        datacenter_patterns = self.conf.get('datacenter', [])
        cluster_patterns = self.conf.get('cluster', [])

        if host_patterns:
            self.conf['host_pattern'] = host_patterns

        self.conf['hosts'] = self._get_hypervisors_from_api()
        # Filter all host specified with -H
        host_filtered = set()
        if host_others:
            host_filtered = set([
                (dc, cl, h, is_spm, is_up)
                for dc, cl, h, is_spm, is_up in self.conf['hosts']
                if h in host_others
            ])
            not_found = host_others - set(host[2] for host in host_filtered)
            if not_found != set():
                # try to resolve to ip specified hosts
                for fqdn in set(not_found):
                    try:
                        ipaddr = socket.gethostbyname(fqdn)
                        logging.debug('%s --> %s' % (fqdn, ipaddr))
                        for (dc, cl, h, is_spm, is_up) in self.conf['hosts']:
                            if h == ipaddr:
                                host_filtered.add((dc, cl, h, is_spm, is_up))
                                not_found.remove(fqdn)
                    except socket.error:
                        logging.warning(
                            _('Cannot resolve {host}').format(
                                host=fqdn,
                            )
                        )
            if not_found != set():
                # try to resolve to ip known hypervisors
                for (dc, cl, h, is_spm, is_up) in self.conf['hosts']:
                    try:
                        ipaddr = socket.gethostbyname(h)
                        logging.debug('%s --> %s' % (h, ipaddr))
                        if ipaddr in host_others:
                            host_filtered.add((dc, cl, h, is_spm, is_up))
                            not_found.remove(ipaddr)
                    except socket.error:
                        logging.warning(
                            _('Cannot resolve {host}').format(
                                host=h,
                            )
                        )
            if not_found != set():
                logging.error(
                    _(
                        'The following host are not listed as hypervisors: '
                        '{not_listed}. Known hypervisors can be listed using '
                        'the list command'
                    ).format(
                        not_listed=','.join(not_found)
                    )
                )
                sys.exit(ExitCodes.CRITICAL)

        orig_hosts = self.conf['hosts'].copy()

        if host_patterns:
            for pattern in host_patterns:
                host_filtered |= self._filter_hosts('host', pattern)
        if host_patterns or host_others:
            self.conf['hosts'] &= host_filtered

        # Intersect with hosts belonging to the data centers specified with -d
        if datacenter_patterns:
            datacenter_filtered = set()
            for pattern in datacenter_patterns:
                datacenter_filtered |= self._filter_hosts(
                    'datacenter', pattern
                )
            self.conf['hosts'] &= datacenter_filtered

        # Intersect with hosts belonging to the clusters specified with -c
        if cluster_patterns:
            # remove all hosts that don't match the patterns
            cluster_filtered = set()
            for pattern in cluster_patterns:
                cluster_filtered |= self._filter_hosts('cluster', pattern)
            self.conf['hosts'] &= cluster_filtered

        # If hypervisor_per_cluster is set, collect data only from a single
        # hypervisor per cluster; if the Spm found, collect data from it.
        if hypervisor_per_cluster:
            selected_hosts = dict()
            for dc, cluster, host, is_spm, is_up in self.conf['hosts']:
                # Always add the SPM
                if is_spm:
                    selected_hosts[cluster.name] = (dc, cluster, host, is_spm,
                                                    is_up)
                # For the given cluster, if no host added yet, add it
                elif cluster.name not in selected_hosts:
                    selected_hosts[cluster.name] = (dc, cluster, host, is_spm,
                                                    is_up)
                # If a host is up and the SPM isn't added yet, add this host
                elif is_up and not selected_hosts[cluster.name][3]:
                    selected_hosts[cluster.name] = (dc, cluster, host, is_spm,
                                                    is_up)
            self.conf['hosts'] &= set(selected_hosts.values())

        # warn users if they are going to collect logs from all hosts.
        if orig_hosts and self.conf['hosts'] == orig_hosts:
            logging.warning(
                _(
                    'This ovirt-log-collector call will collect logs from '
                    'all available hosts. This may take long time, '
                    'depending on the size of your deployment'
                )
            )

        return bool(self.conf.get('hosts'))

    def list_hosts(self):

        def get_host(tuple_):
            return tuple_[2]

        host_list = list(self.conf.get("hosts"))
        host_list.sort(key=get_host)

        fmt = "%-20s | %-20s | %-20s | %-7s | %s"
        print("Host list (datacenter=%(datacenter)s, cluster=%(cluster)s, \
host=%(host_pattern)s):" % self.conf)
        print(fmt % ("Data Center", "Cluster", "Hostname/IP Address",
              "SPM", "Up"))
        print("\n".join(
            fmt % (dc, cluster, host, is_spm, is_up) for
            dc, cluster, host, is_spm, is_up in host_list
        ))

    def get_hypervisor_data(self):
        hosts = self.conf.get("hosts")

        if hosts:
            if not self.conf.get("quiet") and not self.conf.get("batch"):
                # Check if there are more than MAX_WARN_HOSTS_COUNT hosts
                # to collect from
                if len(hosts) >= MAX_WARN_HOSTS_COUNT:
                    logging.warning(
                        _("{number} hypervisors detected. It might take some "
                          "time to collect logs from {number} hypervisors. "
                          "You can use the following filters -c, -d, -H. "
                          "For more information use -h".format(
                              number=len(hosts),
                          ))
                    )
                    _continue = \
                        get_from_prompt(msg="Do you want to proceed(Y/n)",
                                        default='y')
                    if _continue not in ('Y', 'y'):
                        logging.info(
                            _("Aborting hypervisor collection...")
                        )
                        return
                else:
                    continue_ = get_from_prompt(
                        msg="About to collect information from "
                            "{len} hypervisors. Continue? (Y/n): ".format(
                                len=len(hosts),
                            ),
                        default='y'
                    )

                    if continue_ not in ('y', 'Y'):
                        logging.info("Aborting hypervisor collection...")
                        return

            dump_chains = self._get_dump_chains_hosts()

            logging.info("Gathering information from selected hypervisors...")

            max_connections = self.conf.get("max_connections", 10)

            import threading
            from collections import deque

            # max_connections may be defined as a string via a .rc file
            sem = threading.Semaphore(int(max_connections))
            time_diff_queue = deque()

            threads = []

            for datacenter, cluster, host, is_spm, is_up in hosts:
                sem.acquire(True)
                collector = HyperVisorData(
                    host.strip(),
                    configuration=self.conf,
                    semaphore=sem,
                    queue=time_diff_queue,
                    gluster_enabled=cluster.gluster_enabled,
                    dump_volume_chains=(dump_chains[datacenter] == host),
                    time_diff_only=self.conf.get("time_only")
                )
                thread = threading.Thread(target=collector.run)
                thread.start()
                threads.append(thread)

            for thread in threads:
                thread.join()

            self.write_time_diff(time_diff_queue)

    def _get_dump_chains_hosts(self):
        """
        Find hosts to run dump-volume-chains. Only hosts in UP state are
        considered as we want all storage domains of the DC. SPM is preferred.
        """
        hosts = self.conf.get("hosts")
        dump_chains = {}
        for datacenter, cluster, host, is_spm, is_up in hosts:
            if datacenter not in dump_chains:
                dump_chains[datacenter] = None
            if not is_up:
                continue
            if datacenter not in dump_chains:
                dump_chains[datacenter] = host
            elif is_spm:
                dump_chains[datacenter] = host

        for datacenter in dump_chains:
            logging.info("Data center %r volume chains to be collected by %r",
                         datacenter, dump_chains[datacenter])

        return dump_chains

    def get_postgres_data(self):
        if self.conf.get("no_postgresql") is False:
            try:
                try:
                    if not self.conf.get("pg_pass"):
                        self.conf.getpass(
                            "pg_pass",
                            msg="password for the PostgreSQL user, %s, \
to dump the %s PostgreSQL database instance" %
                                (
                                    self.conf.get('pg_user'),
                                    self.conf.get('pg_dbname')
                                )
                        )
                    logging.info(
                        "Gathering PostgreSQL the oVirt Engine database and \
log files from %s..." % (self.conf.get("pg_dbhost"))
                    )
                except Configuration.SkipException:
                    logging.info(
                        "PostgreSQL oVirt Engine database \
will not be collected."
                    )
                    logging.info(
                        "Gathering PostgreSQL log files from %s..." % (
                            self.conf.get("pg_dbhost")
                        )
                    )

                collector = PostgresData(self.conf.get("pg_dbhost"),
                                         configuration=self.conf)
                collector.sosreport()
            except Exception as e:
                ExitCodes.exit_code = ExitCodes.WARN
                logging.error(
                    "Could not collect PostgreSQL information: %s" % e
                )
        else:
            ExitCodes.exit_code = ExitCodes.NOERR
            logging.info("Skipping postgresql collection...")

    def get_engine_data(self):
        logging.info("Gathering oVirt Engine information...")
        collector = ENGINEData(
            "localhost",
            configuration=self.conf
        )
        collector.sosreport()


def parse_password(option, opt_str, value, parser):
    value = getpass.getpass("Please enter %s: " % (option.help))
    setattr(parser.values, option.dest, value)


if __name__ == '__main__':

    DEFAULT_SCRATCH_DIR = tempfile.mkdtemp(prefix='logcollector-')

    commandline = set(sys.argv)
    cleanup_set = set(["--help", "-h", "--version"])

    def cleanup():
        os.rmdir(DEFAULT_SCRATCH_DIR)

    if len(commandline.intersection(cleanup_set)) != 0:
        atexit.register(cleanup)
    elif os.geteuid() != 0:
        print('This tool requires root permissions to run.')
        sys.exit(ExitCodes.CRITICAL)
    else:
        if '--quiet' not in sys.argv:
            for line in (
                _(
                    'This command will collect system configuration and '
                    'diagnostic information from this system.'
                ),
                _(
                    'The generated archive may contain data considered sensi'
                    'tive and its content should be reviewed by the origina'
                    'ting organization before being passed to any third party.'
                ),
                _(
                    'No changes will be made to system configuration.\n'
                ),
            ):
                print('\n'.join(textwrap.wrap(line)))

        setup_pg_defaults()

    def comma_separated_list(option, opt_str, value, parser):
        setattr(
            parser.values, option.dest, [v.strip() for v in value.split(",")]
        )

    usage_string = "\n".join((
        "Usage: %prog [options] list",
        "       %prog [options] collect"
    ))

    epilog_string = """\nReturn values:
    0: The program ran to completion with no errors.
    1: The program encountered a critical failure and stopped.
    2: The program encountered a problem gathering data but was able \
to continue.
"""
    OptionParser.format_epilog = lambda self, formatter: self.epilog
    parser = OptionParser(
        usage_string,
        version="{pkg_name}-{pkg_version}".format(
            pkg_name=config.PACKAGE_NAME,
            pkg_version=config.PACKAGE_VERSION
        ),
        epilog=epilog_string
    )

    parser.add_option(
        "", "--conf-file", dest="conf_file",
        help="path to configuration file (default=%s)" % (
            config.DEFAULT_CONFIGURATION_FILE
        ),
        metavar="PATH"
    )

    parser.add_option(
        "", "--local-tmp", dest="local_tmp_dir",
        help="directory to copy reports to locally. "
             "Please note that the directory must be empty (if already "
             "exists) and will be removed upon completion. "
             "(default is randomly generated like: %s)" % DEFAULT_SCRATCH_DIR,
        metavar="PATH",
        default=DEFAULT_SCRATCH_DIR
    )

    parser.add_option(
        "", "--ticket-number", dest="ticket_number",
        help="ticket number to pass with the sosreport",
        metavar="TICKET"
    )

    parser.add_option(
        "", "--log-size", dest="log_size",
        help="maximum log size to collect on each host in MiB",
        metavar="SIZE"
    )

    parser.add_option(
        "", "--upload", dest="upload",
        help="Upload the report to Red Hat \
(use exclusively if advised from a Red Hat support representative).",
        metavar="FTP_SERVER"
    )

    parser.add_option(
        "", "--quiet", dest="quiet",
        action="store_true", default=False,
        help="reduce console output (default=False)"
    )

    parser.add_option(
        "", "--batch", dest="batch",
        action="store_true", default=False,
        help="batch mode - do not prompt interactively (default=False)"
    )

    parser.add_option(
        "", "--log-file",
        dest="log_file",
        help="path to log file (default=%s)" %
            os.path.join(
                config.DEFAULT_LOG_DIR,
                '{prefix}-<TIMESTAMP>.log'.format(
                    prefix=config.LOG_PREFIX,
                )
            ),
        metavar="PATH",
        default=DEFAULT_LOG_FILE
    )

    parser.add_option(
        "", "--cert-file", dest="cert_file",
        help="The CA certificate used to validate the engine. \
(default=%s)" % config.DEFAULT_CA_PEM,
        metavar=config.DEFAULT_CA_PEM,
        default=config.DEFAULT_CA_PEM
    )

    parser.add_option(
        "", "--insecure", dest="insecure",
        help="Do not make an attempt to verify the engine.",
        action="store_true",
        default=False
    )

    parser.add_option(
        "-v", "--verbose", dest="verbose",
        action="store_true", default=False
    )

    parser.add_option(
        "", "--output", dest="output",
        help="Destination directory where the report will be stored",
        default=tempfile.gettempdir()
    )

    parser.add_option(
        "", "--include-sensitive-data", dest="include_sensitive_data",
        action="store_true", default=False,
        help=(
            "Avoid to obfuscate sensitive data like passwords, etc."
            "The generated archive will contain data considered sensitive "
            "and its content should be reviewed by the originating "
            "organization before being passed to any third party."
        )
    )

    engine_group = OptionGroup(
        parser,
        "oVirt Engine Configuration",
        """The options in the oVirt Engine configuration group can be used to
filter log collection from one or more hypervisors. If the --no-hypervisors
option is specified, data is not collected from any hypervisor."""
    )

    engine_group.add_option(
        "", "--no-hypervisors",
        help="skip collection from hypervisors (default=False)",
        dest="no_hypervisor",
        action="store_true",
        default=False
    )

    engine_group.add_option(
        "", "--hypervisor-per-cluster",
        help=(
            "Collect data only from a hypervisor per cluster; choose the SPM "
            "if found in a cluster."
        ),
        dest="hypervisor_per_cluster",
        action="store_true",
        default=False
    )

    engine_group.add_option(
        "", "--time-only",
        help="Just gather time diff from specified hypervisors",
        dest="time_only",
        action="store_true",
        default=False
    )
    engine_group.add_option(
        "-u", "--user", dest="user",
        help="username to use with the REST API. \
This should be in UPN format.",
        metavar="user@engine.example.com"
    )

    engine_group.add_option(
        "-p",
        "--passwd",
        dest="passwd",
        help=SUPPRESS_HELP
    )

    engine_group.add_option(
        "",
        "--with-kerberos",
        dest="kerberos",
        help=_(
            "Enable Kerberos authentication instead of the default "
            "basic authentication."
        ),
        action="store_true",
        default=False
    )

    engine_group.add_option(
        "-r", "--engine", dest="engine", metavar="engine.example.com",
        help="hostname or IP address of the oVirt Engine \
(default=localhost:443)",
        default="localhost:443"
    )

    engine_group.add_option(
        "-c", "--cluster", dest="cluster",
        help="pattern, or comma separated list of patterns to filter the host \
list by cluster name (default=None)",
        action="callback",
        callback=comma_separated_list,
        type="string",
        default=None, metavar="CLUSTER"
    )

    engine_group.add_option(
        "-d", "--data-center", dest="datacenter",
        help="pattern, or comma separated list of patterns to filter the host \
list by data center name (default=None)",
        action="callback",
        callback=comma_separated_list,
        type="string",
        default=None, metavar="DATACENTER"
    )

    engine_group.add_option(
        "-H", "--hosts", dest="hosts_list", action="callback",
        callback=comma_separated_list,
        type="string",
        help="""comma separated list of hostnames, hostname patterns, FQDNs,
FQDN patterns, IP addresses, or IP address patterns from which the log
collector should collect hypervisor logs (default=None)"""
    )

    ssh_group = OptionGroup(
        parser, "SSH Configuration",
        """The options in the SSH configuration group can be used to specify
the maximum number of concurrent SSH connections to hypervisor(s) for log
collection, the SSH port, and a identity file to be used."""
    )

    ssh_group.add_option(
        "", "--ssh-port", dest="ssh_port",
        help="the port to ssh and scp on", metavar="PORT",
        default=22
    )

    ssh_group.add_option(
        "-k", "--key-file", dest="key_file",
        help="""the identity file (private key) to be used for accessing the
hypervisors (default=%s).
If a identity file is not supplied the program will prompt for a password.
It is strongly recommended to use key based authentication with SSH because
the program may make multiple SSH connections resulting in multiple requests
for the SSH password.""" % config.DEFAULT_SSH_KEY,
        metavar="KEYFILE",
        default=config.DEFAULT_SSH_KEY
    )

    ssh_group.add_option(
        "", "--max-connections", dest="max_connections",
        help="max concurrent connections for fetching hypervisor logs \
(default = 10)",
        default=10
    )

    db_group = OptionGroup(
        parser,
        "PostgreSQL Database Configuration",
        """The log collector will connect to the oVirt Engine PostgreSQL
database and dump the data for inclusion in the log report unless
--no-postgresql is specified.
The PostgreSQL user ID and database name can be specified if they
are different from the defaults. If the PostgreSQL database is not on the
localhost set pg-dbhost, provide a pg-ssh-user, and optionally supply
pg-host-key and the log collector will gather remote PostgreSQL logs.
The PostgreSQL SOS plug-in must be installed on pg-dbhost for
successful remote log collection."""
    )

    db_group.add_option(
        "", "--no-postgresql", dest="no_postgresql",
        help="This option causes the tool to skip the postgresql collection \
(default=false)",
        action="store_true",
        default=False
    )

    db_group.add_option(
        "", "--pg-user", dest="pg_user",
        help="PostgreSQL database user name (default=%s)" % pg_user,
        metavar=pg_user,
        default=pg_user
    )

    db_group.add_option(
        "",
        "--pg-pass",
        dest="pg_pass",
        help=SUPPRESS_HELP
    )

    db_group.add_option(
        "", "--pg-dbname", dest="pg_dbname",
        help="PostgreSQL database name (default=%s)" % pg_dbname,
        metavar=pg_dbname,
        default=pg_dbname
    )

    db_group.add_option(
        "", "--pg-dbhost", dest="pg_dbhost",
        help="PostgreSQL database hostname or IP address (default=%s)" % (
            pg_dbhost
        ),
        metavar=pg_dbhost,
        default=pg_dbhost
    )

    db_group.add_option(
        "", "--pg-dbport", dest="pg_dbport",
        help="PostgreSQL server port number (default=%s)" % pg_dbport,
        metavar=pg_dbport,
        default=pg_dbport
    )

    db_group.add_option(
        "", "--pg-ssh-user", dest="pg_ssh_user",
        help="""the SSH user that will be used to connect to the
server upon which the remote PostgreSQL database lives. (default=root)""",
        metavar="root",
        default='root'
    )

    db_group.add_option(
        "", "--pg-host-key", dest="pg_host_key",
        help="""the identity file (private key) to be used for accessing the
host upon which the PostgreSQL database lives
(default=not needed if using localhost)""",
        metavar="none"
    )

    parser.add_option_group(engine_group)
    parser.add_option_group(ssh_group)
    parser.add_option_group(db_group)
    parser.parse_args()

    try:
        conf = Configuration(parser)
        if not conf.get('pg_pass') and pg_pass:
            conf['pg_pass'] = pg_pass
        collector = LogCollector(conf)

        # We must ensure that the directory exists before
        # we start doing anything.
        if os.path.exists(conf["local_tmp_dir"]):
            if not os.path.isdir(conf["local_tmp_dir"]):
                raise Exception(
                    '%s is not a directory.' % (conf["local_tmp_dir"])
                )

            # We must also ensure that existing directory is empty
            if os.listdir(conf["local_tmp_dir"]):
                raise Exception(
                    '%s directory is not empty.' % (conf["local_tmp_dir"])
                )
        else:
            logging.info(
                "%s does not exist.  It will be created." % (
                    conf["local_tmp_dir"]
                )
            )
            os.makedirs(conf["local_tmp_dir"])

        # We need to make a temporary working directory
        conf["local_working_dir"] = os.path.join(
            conf["local_tmp_dir"],
            'working'
        )
        try:
            os.makedirs(conf["local_working_dir"])
        except OSError:
            if len(os.listdir(conf["local_working_dir"])) != 0:
                raise Exception(
                    "The working directory is not empty.\n"
                    "It should be empty so that reports from a prior "
                    "invocation of the log collector\n"
                    "are not collected again.\n"
                    "The directory is: %s" % (
                        conf["local_working_dir"]
                    )
                )

        # We need to make a temporary scratch directory wherein
        # all of the output from VDSM and PostgreSQL SOS plug-ins
        # will be dumped.  The contents of this directory will be included in
        # a single .xz or .bz2 file report.
        conf["local_scratch_dir"] = os.path.join(
            conf["local_working_dir"],
            'log-collector-data'
        )
        if not os.path.exists(conf["local_scratch_dir"]):
            os.makedirs(conf["local_scratch_dir"])
        else:
            if len(os.listdir(conf["local_scratch_dir"])) != 0:
                raise Exception("""the scratch directory for temporary storage
of hypervisor reports is not empty.
It should be empty so that reports from a prior invocation of the log collector
are not collected again.
The directory is: %s'""" % (conf["local_scratch_dir"]))

        if conf.command == "collect":
            hosts_present = None
            e = None
            try:
                if conf.get("hypervisor_per_cluster"):
                    hosts_present = collector.set_hosts(True)
                elif not conf.get("no_hypervisor"):
                    hosts_present = collector.set_hosts()
            except Exception:
                pass
            collector.get_engine_data()
            collector.get_postgres_data()
            if hosts_present:
                collector.get_hypervisor_data()
            else:
                if conf.get("no_hypervisor"):
                    logging.info("Skipping hypervisor collection...")
                elif e:
                    logging.info("Hypervisor data will not be collected, Error"
                                 " while selecting hypervisors\nReason:"
                                 " %s" % str(e))
                else:
                    logging.info(
                        "No hypervisors were selected, therefore no "
                        "hypervisor data will be collected.")
            stdout = collector.archive()
            logging.info(stdout)
        elif conf.command == "list":
            if collector.set_hosts():
                collector.list_hosts()
            else:
                logging.info(
                    "No hypervisors were found, therefore no hypervisor \
data will be listed.")

    except KeyboardInterrupt:
        print("Exiting on user cancel.")
    except Exception as e:
        multilog(logging.error, e)
        print("Use the -h option to see usage.")
        logging.debug("Configuration:")
        try:
            logging.debug("command: %s" % conf.command)
            # multilog(logging.debug, pprint.pformat(conf))
        except Exception:
            pass
        multilog(logging.debug, traceback.format_exc())
        sys.exit(ExitCodes.CRITICAL)

    sys.exit(ExitCodes.exit_code)
