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
# build:
# docker build -t ovirt-log-collector-analyzer:latest .
#
# usage:
# docker run -d -p 8080:8080 ovirt-log-collector-analyzer:latest
#
# As soon the docker trigger the uploader can be accessed via
# browser 0.0.0.0:8080 or send the sosreport via curl
#
# curl -H 'Expect:' -i -X POST -F "file=@sosreport.tar.xz" IP:8080 > report
#
# For debug mode (grab image id from docker images cmd):
# docker run -it --entrypoint /bin/bash $IMAGE_ID
#
FROM fedora:25

ENV workdir /app

RUN dnf install -y http://resources.ovirt.org/pub/yum-repo/ovirt-release-master.rpm
RUN dnf install -y xz findutils ovirt-log-collector-analyzer python3-flask

COPY . /
WORKDIR $workdir
EXPOSE 8080
ENTRYPOINT ["python3"]
CMD ["app.py"]
