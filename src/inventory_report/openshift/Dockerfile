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
# Sending file via curl
# curl -H 'Expect:' -i -X POST -F "file=@sosreport.tar.xz" IP:8080 > report
#
FROM centos/python-35-centos7

# Use root to install the packages
USER root

RUN yum install -y http://resources.ovirt.org/pub/yum-repo/ovirt-release-master.rpm
RUN yum install -y git \
	rpm-build \
	autoconf \
	gettext-devel \
	automake \
	python-flask \
	python2-devel \
	python-gunicorn

RUN git clone http://gerrit.ovirt.org/p/ovirt-log-collector && \
	cd ovirt-log-collector && \
	./autogen.sh && \
	./configure && \
	make rpm && \
	yum install -y ./tmp.repos/RPMS/noarch/ovirt-log-collector-analyzer*

# Return to pre-defined ordinary user
USER 1001
