#
# ovirt-log-collector
# Copyright (C) 2013 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


import glob
import os
import re


class ConfigFile(object):
    _COMMENT_EXPR = re.compile(r'\s*#.*$')
    _BLANK_EXPR = re.compile(r'^\s*$')
    _VALUE_EXPR = re.compile(r'^\s*(?P<key>\w+)\s*=\s*(?P<value>.*?)\s*$')
    _REF_EXPR = re.compile(r'\$\{(?P<ref>\w+)\}')

    def _loadLine(self, line):
        # Remove comments:
        commentMatch = self._COMMENT_EXPR.search(line)
        if commentMatch is not None:
            line = line[:commentMatch.start()] + line[commentMatch.end():]

        # Skip empty lines:
        emptyMatch = self._BLANK_EXPR.search(line)
        if emptyMatch is None:
            # Separate name from value:
            keyValueMatch = self._VALUE_EXPR.search(line)
            if keyValueMatch is not None:
                key = keyValueMatch.group('key')
                value = keyValueMatch.group('value')

                # Strip quotes from value:
                if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
                    value = value[1:-1]

                # Expand references to other parameters:
                while True:
                    refMatch = self._REF_EXPR.search(value)
                    if refMatch is None:
                        break
                    refKey = refMatch.group('ref')
                    refValue = self._values.get(refKey)
                    if refValue is None:
                        break
                    value = '%s%s%s' % (
                        value[:refMatch.start()],
                        refValue,
                        value[refMatch.end():],
                    )

                self._values[key] = value

    def __init__(self, files=[]):
        super(ConfigFile, self).__init__()

        self._values = {}

        for filename in files:
            self.loadFile(filename)
            for filed in sorted(
                glob.glob(
                    os.path.join(
                        '%s.d' % filename,
                        '*.conf',
                    )
                )
            ):
                self.loadFile(filed)

    def loadFile(self, filename):
        if os.path.exists(filename):
            with open(filename, 'r') as f:
                for line in f:
                    self._loadLine(line)

    def get(self, name, default=None):
        return self._values.get(name, default)

    def getboolean(self, name, default=None):
        text = self.get(name)
        if text is None:
            return default
        else:
            return text.lower() in ('t', 'true', 'y', 'yes', '1')

    def getinteger(self, name, default=None):
        value = self.get(name)
        if value is None:
            return default
        else:
            return int(value)


# vim: expandtab tabstop=4 shiftwidth=4
