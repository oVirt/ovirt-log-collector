#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# Makefile for oVirt Engine Log Collector
#

NAME=ovirt-log-collector
# ex. export APP_VERSION=1.0.0
RPM_VERSION:=$(shell echo $(APP_VERSION) | sed "s/-/_/")
# ex. export APP_RELEASE=1
RPM_RELEASE:=$(shell echo $(APP_RELEASE) | sed "s/-/_/")
SPEC_FILE_IN=ovirt-log-collector.spec.in
SPEC_FILE=ovirt-log-collector.spec
RPMTOP=$(shell bash -c "pwd -P")/rpmtop
NAME_VER=$(NAME)-$(RPM_VERSION)
TARBALL=$(NAME)-$(RPM_VERSION).tar.gz
SRPM=$(RPMTOP)/SRPMS/$(NAME)-$(RPM_VERSION)*.src.rpm
ARCH=noarch
PYTHON_SITELIB=$(shell python -c "from distutils.sysconfig import get_python_lib as f;print f()")


CURR_DIR=$(shell bash -c "pwd -P")
all: rpm

clean:
	@for i in `find . -iname *.pyc`; do \
		rm $$i; \
	done; \
	for i in `find . -iname *.pyo`; do \
		rm $$i; \
	done; \
	rm -rf $(SPEC_FILE) $(RPMTOP) $(TARBALL) $(NAME)

install: create_dirs install_log_collector

tarball: $(TARBALL)
$(TARBALL):
	rsync -avz --exclude=.git . $(NAME)
	tar --transform 's,^ovirt-log-collector,$(NAME_VER),S' -cvf $(TARBALL) $(NAME)
	rm -rf $(NAME)/

srpm: $(SRPM)

$(SRPM): tarball $(SPEC_FILE_IN)
	sed 's/^Version:.*/Version: $(RPM_VERSION)/' $(SPEC_FILE_IN) > $(SPEC_FILE)
	sed -i -e's/^Release:.*/Release: $(RPM_RELEASE)%{?dist}/' $(SPEC_FILE)
	mkdir -p $(RPMTOP)/{SPECS,RPMS,SRPMS,SOURCES,BUILD,BUILDROOT}
	cp -f $(SPEC_FILE) $(RPMTOP)/SPECS/
	cp -f  $(TARBALL) $(RPMTOP)/SOURCES/
	rpmbuild -bs --define="_topdir $(RPMTOP)" --define="_sourcedir $(RPMTOP)/SOURCES" $(SPEC_FILE)

rpm: $(SRPM)
	rpmbuild  --define="_topdir $(RPMTOP)" --rebuild  $<

create_dirs:
	@echo "*** Creating Directories"
	@mkdir -p $(PREFIX)/usr/share/man/man8/
	@mkdir -p $(PREFIX)/usr/bin/

install_log_collector:
	@echo "*** Deploying log collector"
	install -D -m 0755 ./src/rhev/logcollector.py $(PREFIX)/usr/share/ovirt-engine/log-collector/engine-log-collector.py
	install -D -m 0755 ./src/rhev/helper/hypervisors.py $(PREFIX)/usr/share/ovirt-engine/log-collector/helper/hypervisors.py
	install -D -m 0755 ./src/rhev/helper/__init__.py $(PREFIX)/usr/share/ovirt-engine/log-collector/helper/__init__.py
	install -D -m 0755 ./src/sos/plugins/engine.py $(PREFIX)/$(PYTHON_SITELIB)/sos/plugins/engine.py
	install -D -m 0755 ./src/sos/plugins/postgresql.py $(PREFIX)/$(PYTHON_SITELIB)/sos/plugins/postgresql.py
	/usr/bin/gzip -c ./src/rhev/engine-log-collector.8 > $(PREFIX)/usr/share/man/man8/engine-log-collector.8.gz
	chmod 644 $(PREFIX)/usr/share/man/man8/engine-log-collector.8.gz
	install -D -m 0600 ./src/rhev/logcollector.conf $(PREFIX)/etc/ovirt-engine/logcollector.conf
	ln -s /usr/share/ovirt-engine/log-collector/engine-log-collector.py $(PREFIX)/usr/bin/engine-log-collector
