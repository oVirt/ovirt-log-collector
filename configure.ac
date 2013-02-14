dnl
dnl Licensed to the Apache Software Foundation (ASF) under one or more
dnl contributor license agreements.  See the NOTICE file distributed with
dnl this work for additional information regarding copyright ownership.
dnl The ASF licenses this file to You under the Apache License, Version 2.0
dnl (the "License"); you may not use this file except in compliance with
dnl the License.  You may obtain a copy of the License at
dnl
dnl     http://www.apache.org/licenses/LICENSE-2.0
dnl
dnl Unless required by applicable law or agreed to in writing, software
dnl distributed under the License is distributed on an "AS IS" BASIS,
dnl WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
dnl See the License for the specific language governing permissions and
dnl limitations under the License.
dnl

AC_PREREQ(2.60)

define([VERSION_MAJOR], [3])
define([VERSION_MINOR], [2])
define([VERSION_FIX], [0])
define([VERSION_NUMBER], VERSION_MAJOR[.]VERSION_MINOR[.]VERSION_FIX)
define([VERSION_SUFFIX], [])

AC_INIT([ovirt-log-collector], VERSION_NUMBER[]VERSION_SUFFIX)
PACKAGE_RPM_VERSION="VERSION_NUMBER"
PACKAGE_RPM_RELEASE="1"
AC_SUBST([PACKAGE_RPM_VERSION])
AC_SUBST([PACKAGE_RPM_RELEASE])

AC_CONFIG_AUX_DIR([.])
AC_CONFIG_SRCDIR([src/engine-log-collector.8])
AC_CONFIG_MACRO_DIR([m4])
AC_USE_SYSTEM_EXTENSIONS
AM_INIT_AUTOMAKE
AM_GNU_GETTEXT_VERSION([0.17])
AM_GNU_GETTEXT([external])

AC_ARG_ENABLE(
	[python-syntax-check],
	[AS_HELP_STRING([--disable-python-syntax-check], [disable python syntax check @<:@default=enabled@:>@])],
	,
	[enable_python_syntax_check="yes"]
)

AC_PROG_INSTALL
AC_PROG_SED
AC_PROG_MAKE_SET
AC_PROG_MKDIR_P
AC_PROG_LN_S

AC_ARG_VAR([PYFLAKES], [path to pyflakes utility])
AC_CHECK_PROGS([PYFLAKES], [pyflakes])
AC_ARG_VAR([PEP8], [path to pep8 utility])
AC_CHECK_PROGS([PEP8], [pep8])
AC_ARG_VAR([RPMBUILD], [path to rpmbuild utility])
AC_CHECK_PROGS([RPMBUILD], [rpmbuild])

AM_PATH_PYTHON([2.6],,[AC_MSG_ERROR([Cannot find python])])
case "${PYTHON_VERSION}" in
	2.*);;
	*) AC_MSG_ERROR([python 2.6 is required])
esac

AX_PYTHON_MODULE([ovirtsdk])

engineconfigdir="\$(sysconfdir)/ovirt-engine"
ovirtlogcollectorlibdir="\$(pythondir)/ovirt_log_collector"
sospluginsdir="\$(pythondir)/sos/plugins"
AC_SUBST([engineconfigdir])
AC_SUBST([ovirtlogcollectorlibdir])
AC_SUBST([sospluginsdir])
AM_CONDITIONAL([PYTHON_SYNTAX_CHECK], [test "${enable_python_syntax_check}" = "yes"])

AC_CONFIG_FILES([
	Makefile
	ovirt-log-collector.spec
	src/Makefile
	src/sos/Makefile
	src/sos/plugins/Makefile
	src/helper/Makefile
	po/Makefile.in
])
AC_OUTPUT

# warn about uninstalled python modules
set | grep HAVE_PYMOD | grep "=no" | while read v; do
	module=`echo "${v}" | sed 's/HAVE_PYMOD_\(.*\)=no/\1/'`
	AC_MSG_WARN([Cannot find python ${module} module])
done
