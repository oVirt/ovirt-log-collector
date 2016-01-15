"""
This module uses the REST API to get a collection of information about
hypervisors
"""

import logging
import gettext
from ovirtsdk.api import API
from ovirtsdk.infrastructure.errors import RequestError, ConnectionError
from ovirtsdk.infrastructure.errors import NoCertificatesError

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

        def __init__(self, address, name=None):
            self.address = address
            self.name = name

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
            cluster.get_gluster_service()
        )
        self.clusters.add(c_obj)
        if cluster.get_data_center() is not None:
            for dc in self.datacenters:
                if dc.id == cluster.get_data_center().id:
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
        host_obj = self.Host(host.get_address(), host.name)
        self.hosts.add(host_obj)
        if host.get_cluster() is not None:
            for cluster in self.clusters:
                if cluster.id == host.get_cluster().id:
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
            (dc.name, cluster, host.address)
            for dc in self.datacenters
            for cluster in dc.clusters
            for host in cluster.hosts
        ]


def _initialize_api(hostname, username, password, ca, insecure):
    """
    Initialize the oVirt RESTful API
    """
    url = 'https://{hostname}/ovirt-engine/api'.format(
        hostname=hostname,
    )
    api = API(url=url,
              username=username,
              password=password,
              ca_file=ca,
              validate_cert_chain=not insecure)
    pi = api.get_product_info()
    if pi is not None:
        vrm = '%s.%s.%s' % (
            pi.get_version().get_major(),
            pi.get_version().get_minor(),
            pi.get_version().get_revision()
        )
        logging.debug("API Vendor(%s)\tAPI Version(%s)" % (
            pi.get_vendor(), vrm)
        )
    else:
        api.test(throw_exception=True)
    return api


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
        tanda = entity.list(query=query, max=page_size)
        length = len(tanda)
        for elem in tanda:
            yield elem


def get_all(hostname, username, password, ca, insecure=False):

    tree = ENGINETree()
    result = set()
    try:
        api = _initialize_api(hostname, username, password, ca, insecure)
        if api is not None:
            for dc in paginate(api.datacenters):
                tree.add_datacenter(dc)
            for cluster in paginate(api.clusters):
                tree.add_cluster(cluster)
            for host in paginate(api.hosts):
                tree.add_host(host)
            result = set(tree.get_sortable())
    except RequestError as re:
        logging.error(
            _("Unable to connect to REST API.  Reason: %s") % re.reason
        )
        raise re
    except ConnectionError as ce:
        logging.error(_(
            "Problem connecting to the REST API."
            "Is the service available and does the CA certificate exist?"
        ))
        raise ce
    except NoCertificatesError as nce:
        logging.error(_(
            "Problem connecting to the REST API."
            "The CA is invalid.  To override use the \'insecure\' option."
        ))
        raise nce
    except Exception as e:
        logging.error(
            _(
                "Failure fetching information about hypervisors from API."
                "Error: %s"
            ) % e
        )
        raise e
    return result
