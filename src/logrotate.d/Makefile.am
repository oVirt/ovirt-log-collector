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

MAINTAINERCLEANFILES = \
	$(srcdir)/Makefile.in \
	$(NULL)

EXTRA_DIST = \
	ovirt-log-collector.in \
	$(NULL)

CLEANFILES = \
	ovirt-log-collector \
	$(NULL)

nodist_logrotate_DATA= \
	ovirt-log-collector \
	$(NULL)

logrotatedir=$(sysconfdir)/logrotate.d

ovirt-log-collector: ovirt-log-collector.in
	$(SED) \
	-e 's|@localstatedir[@]|$(localstatedir)|g' \
	-e 's|@PACKAGE_NAME[@]|$(PACKAGE_NAME)|g' < $< > $@
