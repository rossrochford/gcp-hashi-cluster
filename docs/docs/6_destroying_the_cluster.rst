**************************************************
Removing the cluster and GCP resources
**************************************************


Destroying cluster instances
-----------------------------------

To delete your instances run:

.. code-block:: console

    $ cd gcp-hashi-cluster/infrastructure/cluster-nodes/
    $ ./tf_destroy.sh

This won't destroy everything but it will stop you being billed for live instances. The networking resources (firewall rules, NAT router) will still remain.


Provisioning a fresh cluster
-----------------------------------

Given that the GCP projects still exist, along with networking resources and the base VM image, starting a fresh cluster is easy:

.. code-block:: console

    $ cd gcp-hashi-cluster/infrastructure/cluster-nodes/
    $ ./tf_apply.sh

    $ cd gcp-hashi-cluster/build/
    $ ./5-initialize-hashi-cluster.sh


Destroying all resources
-----------------------------------

To destroy your networking resources run:

.. code-block:: console

    $ cd gcp-hashi-cluster/infrastructure/cluster-networking/
    $ ./tf_destroy.sh


This destroys the firewalls rules and NAT router. Some networking resources were created outside Terraform and are not destroyed here (a shared VPC, subnetwork, and a public IP).

To destroy all remaining resources simply delete the two GCP projects. Get your uuid from `build/conf/project-info.json` and run:

.. code-block:: console

    $ cd gcp-hashi-cluster/build/
    $ ./delete-projects.sh 63c22312-5d51


This will remove all resources linked to these projects.

The only resources remaining are two custom IAM roles at the organization level: `computeAddressUser` and `goDiscoverClient`:

.. code-block:: console

    $ gcloud iam roles delete computeAddressUser --organization=<organization_id>
    $ gcloud iam roles delete goDiscoverClient --organization=<organization_id>
