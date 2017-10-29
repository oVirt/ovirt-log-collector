"""
This module uses the REST API to get a collection of information about
hypervisors
"""

import logging
import gettext
import ovirtsdk4

t = gettext.translation('hypervisors', fallback=True)
try:
    _ = t.ugettext
except AttributeError:
    _ = t.gettext


class ENGINETree(object):

    class DataCenter(object):

        def __init__(self, id, name):
            self.id = id
            self.name = name
            self.clusters = set()

        def add_cluster(self, cluster):
            self.clusters.add(cluster)

        def __str__(self):
            return self.name

    class Cluster(object):

        def __init__(self, id, name, gluster_enabled=False):
            self.id = id
            self.name = name
            self.hosts = set()
            self.gluster_enabled = gluster_enabled

        def add_host(self, host):
            self.hosts.add(host)

        def __str__(self):
            return self.name

    class Host(object):

        def __init__(self, address, name=None, is_spm=False, is_up=False):
            self.address = address
            self.name = name
            self.is_spm = is_spm
            self.is_up = is_up

        def __str__(self):
            return self.address

    def __init__(self):
        self.datacenters = set()
        self.clusters = set()
        self.hosts = set()

    def add_datacenter(self, datacenter):
        dc_obj = self.DataCenter(datacenter.id, datacenter.name)
        self.datacenters.add(dc_obj)

    def add_cluster(self, cluster):
        c_obj = self.Cluster(
            cluster.id,
            cluster.name,
            cluster.gluster_service
        )
        self.clusters.add(c_obj)
        if cluster.data_center is not None:
            for dc in self.datacenters:
                if dc.id == cluster.data_center.id:
                    dc.add_cluster(c_obj)
        else:
            dummySeen = 0
            for dc in self.datacenters:
                if dc.id == "":
                    dc.add_cluster(c_obj)
                    dummySeen = 1
            if dummySeen == 0:
                dc = self.DataCenter("", "")
                dc.add_cluster(c_obj)
                self.datacenters.add(dc)

    def add_host(self, host):
        is_spm = host.spm.status == ovirtsdk4.types.SpmStatus.SPM
        is_up = host.status == ovirtsdk4.types.HostStatus.UP
        host_obj = self.Host(host.address, host.name, is_spm, is_up)
        self.hosts.add(host_obj)
        if host.cluster is not None:
            for cluster in self.clusters:
                if cluster.id == host.cluster.id:
                    cluster.add_host(host_obj)
        else:
            dummySeen = 0
            for cluster in self.clusters:
                if cluster.id == "":
                    cluster.add_host(host_obj)
                    dummySeen = 1
            if dummySeen == 0:
                c_obj = self.Cluster("", "")
                c_obj.add_host(host_obj)
                self.clusters.add(c_obj)
                dc = self.DataCenter("", "")
                dc.add_cluster(c_obj)
                self.datacenters.add(dc)

    def __str__(self):
        return "\n".join([
            "%-20s | %-20s | %s" % (dc, cluster, host)
            for dc in self.datacenters
            for cluster in dc.clusters
            for host in cluster.hosts
        ])

    def get_sortable(self):
        return [
            (dc.name, cluster, host.address, host.is_spm, host.is_up)
            for dc in self.datacenters
            for cluster in dc.clusters
            for host in cluster.hosts
        ]


def _initialize_api(hostname, username, password, ca, insecure, kerberos):
    """
    Initialize the oVirt RESTful API
    """
    url = 'https://{hostname}/ovirt-engine/api'.format(
        hostname=hostname,
    )
    # TODO: add debug support
    conn = ovirtsdk4.Connection(url=url,
                                username=username,
                                password=password,
                                ca_file=ca,
                                insecure=insecure,
                                kerberos=kerberos)
    svc = conn.system_service().get()
    pi = svc.product_info
    if pi is not None:
        vrm = '%s.%s.%s' % (
            pi.version.major,
            pi.version.minor,
            pi.version.revision
        )
        logging.debug("API Vendor(%s)\tAPI Version(%s)" % (
            pi.vendor, vrm)
        )
    else:
        conn.test(raise_exception=True)
    return conn


def paginate(entity, oquery=""):
    """Generator for listing all elements of object avoiding api query limit
    @param entity: object to paginate using list and query
    @param oquery: optional query to limit results
    """
    page = 0
    page_size = 100
    length = page_size
    while length > 0:
        page += 1
        query = "%s page %s" % (oquery, page)
        # after BZ1025320 default is provide all results
        # this limits results on each iteration to page_size
        tanda = entity.list(search=query, max=page_size)
        length = len(tanda)
        for elem in tanda:
            yield elem


def get_all(hostname, username, password, ca, insecure=False, kerberos=False):

    tree = ENGINETree()
    result = set()
    conn = None
    try:
        conn = _initialize_api(hostname, username, password, ca, insecure,
                               kerberos)
        api = conn.system_service()
        if api is not None:
            for dc in paginate(api.data_centers_service()):
                tree.add_datacenter(dc)
            for cluster in paginate(api.clusters_service()):
                tree.add_cluster(cluster)
            for host in paginate(api.hosts_service()):
                tree.add_host(host)
            result = set(tree.get_sortable())
    except Exception as e:
        # ovirt-engine-sdk4 does not provides specialized exceptions
        # anymore. this bad exception is all we can have for now.
        logging.error(
            _(
                "Failure fetching information about hypervisors from API.\n"
                "Error (%s): %s"
            ) % (e.__class__.__name__, e)
        )
        raise e
    finally:
        if conn is not None:
            conn.close()
    return result
