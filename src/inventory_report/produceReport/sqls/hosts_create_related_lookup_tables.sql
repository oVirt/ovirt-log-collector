--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
--
CREATE TABLE host_status_temp (
    id NUMERIC, text varchar
);

INSERT INTO host_status_temp VALUES
    (0, 'Unassigned'),
    (1, 'Down'),
    (2, 'Maintenance'),
    (3, 'Up'),
    (4, 'NonResponsive'),
    (5, 'Error'),
    (6, 'Installing'),
    (7, 'InstallFailed'),
    (8, 'Reboot'),
    (9, 'PreparingForMaintenance'),
    (10, 'NonOperational'),
    (11, 'PendingApproval'),
    (12, 'Initializing'),
    (13, 'Connecting'),
    (14, 'InstallingOS'),
    (15, 'Kdumping');

CREATE TABLE host_type_temp (
    id NUMERIC, text varchar
);

INSERT INTO host_type_temp VALUES
    (0, 'rhel'),
    (1, 'ngn/rhvh'),
    (2, 'rhev-h');
