import fnmatch
import os
import sos.plugintools
import tempfile


def find(file_pattern, top_dir, max_depth=None, path_pattern=None):
    """generate function to find files recursively. Usage:

    for filename in find("*.properties", /var/log/foobar):
        print filename
    """
    if max_depth:
        base_depth = os.path.dirname(top_dir).count(os.path.sep)
        max_depth += base_depth

    for path, dirlist, filelist in os.walk(top_dir):
        if max_depth and path.count(os.path.sep) >= max_depth:
            del dirlist[:]

        if path_pattern and not fnmatch.fnmatch(path, path_pattern):
            continue

        for name in fnmatch.filter(filelist, file_pattern):
            yield os.path.join(path, name)


# Class name must be the same as file name and method names must not change
class postgresql(sos.plugintools.PluginBase):
    """PostgreSQL related information"""
    __pghome = '/var/lib/pgsql'
    __username = 'postgres'
    __dbport = 5432

    optionList = [
        (
            'pghome',
            'PostgreSQL server home directory (default=/var/lib/pgsql)',
            '',
            False
        ),
        ('username', 'username for pg_dump (default=postgres)', '', False),
        ('password', 'password for pg_dump (default=None)', '', False),
        (
            'dbname',
            'database name to dump for pg_dump (default=None)',
            '',
            False
        ),
        (
            'dbhost',
            'hostname/IP of the server upon which the DB is running \
(default=localhost)',
            '',
            False
        ),
        ('dbport', 'database server port number (default=5432)', '', False)
    ]

    def __init__(self, pluginname, commons):
        sos.plugintools.PluginBase.__init__(self, pluginname, commons)
        self.tmp_dir = None

    def pg_dump(self):
        dest_file = os.path.join(self.tmp_dir, "sos_pgdump.tar")
        old_env_pgpassword = os.environ.get("PGPASSWORD")
        os.environ["PGPASSWORD"] = "%s" % (self.getOption("password"))
        if (
            self.getOption("dbhost") and
            self.getOption("dbhost") is not True
        ):
            cmd = "pg_dump -U %s -h %s -p %s -w -f %s -F t %s" % (
                self.__username,
                self.getOption("dbhost"),
                self.__dbport,
                dest_file,
                self.getOption("dbname")
            )
        else:
            cmd = "pg_dump -C -U %s -w -f %s -F t %s " % (
                self.__username,
                dest_file,
                self.getOption("dbname")
            )
        self.soslog.debug("calling %s" % cmd)
        (status, output, rtime) = self.callExtProg(cmd)
        if old_env_pgpassword is not None:
            os.environ["PGPASSWORD"] = str(old_env_pgpassword)
        if (status == 0):
            self.addCopySpec(dest_file)
        else:
            self.soslog.error(
                "Unable to execute pg_dump. Error(%s)" % (output)
            )
            self.addAlert(
                "ERROR: Unable to execute pg_dump.  Error(%s)" % (output)
            )

    def setup(self):
        if (
            self.getOption("pghome") and
            self.getOption("pghome") is not True
        ):
            self.__pghome = self.getOption("pghome")
        self.soslog.debug("using pghome=%s" % self.__pghome)

        if (
            self.getOption("dbname") and
            self.getOption("dbname") is not True
        ):
            if (
                self.getOption("password") and
                self.getOption("password") is not True
            ):
                if (
                    self.getOption("username") and
                    self.getOption("username") is not True
                ):
                    self.__username = self.getOption("username")
                if (
                    self.getOption("dbport") and
                    self.getOption("dbport") is not True
                ):
                    self.__dbport = self.getOption("dbport")
                self.tmp_dir = tempfile.mkdtemp()
                self.pg_dump()
            else:
                self.soslog.warning(
                    "password must be supplied to dump a database."
                )
                self.addAlert(
                    "WARN: password must be supplied to dump a database."
                )
        else:
            self.soslog.warning(
                "dbname must be supplied to dump a database."
            )
            self.addAlert(
                "WARN: dbname must be supplied to dump a database."
            )

        # Copy PostgreSQL log files.
        for filename in find("*.log", self.__pghome):
            self.addCopySpec(filename)
        # Copy PostgreSQL config files.
        for filename in find("*.conf", self.__pghome):
            self.addCopySpec(filename)

        self.addCopySpec(os.path.join(self.__pghome, "data", "PG_VERSION"))
        self.addCopySpec(
            os.path.join(self.__pghome, "data", "postmaster.opts")
        )

    def postproc(self):
        import shutil
        try:
            shutil.rmtree(self.tmp_dir)
        except shutil.Error:
            self.soslog.exception(
                "Unable to remove %s." % (self.tmp_dir)
            )
            self.addAlert("ERROR: Unable to remove %s." % (self.tmp_dir))
