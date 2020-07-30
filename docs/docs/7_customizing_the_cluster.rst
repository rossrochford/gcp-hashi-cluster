*********************************
Customizing the cluster
*********************************

gcp-hashi-cluster is intended as a starting point to get up and running or as a reference to help you learn about Consul and Nomad. It isn't designed to be configured in every possible way. However here are some rough directions on customizations you may wish to make.


.. _changing_ubuntu_version:

Changing the Ubuntu version
-------------------------------------------------------

The Packer build script has been tested with Ubuntu 18.04 and 20.04, presumably it will work with Ubuntu 19.10 also.

- Find a Ubuntu image by runing: ``gcloud compute images list | grep ubuntu``
- In `build/vm_images/hashi_base.pkr.hcl` change ``source_image`` and ``source_image_family``.
- If you have previously built an image in your project, either remove the old image or update the ``base_image_name`` in `build/conf/project-info.json` so the names don't conflict.

Finally run:

.. code-block:: console

    $ cd gcp-hashi-cluster/build
    $ ./3-build-base-image.sh


.. _making_load_balancer_regional:

Changing the load-balancer from global to regional
-------------------------------------------------------

Currently the cluster is constructed to run in a single GCP region. However the load-balancer and its public IP address are global GCP resources and this may cause higher latency when serving incoming requests.

Update the load-balancer
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Here is a rough guide to changing the load-balancer and related resources to operate within the same region as the cluster. This hasn't been tested but it should get you 90% of the way there.

In `infrastructure/cluster-nodes/traefik_lb.tf`, replace the existing global resources with their regional equivalents:

=======================================     =======================================
Global resource                             Regional resource
=======================================     =======================================
google_compute_global_forwarding_rule       google_compute_forwarding_rule
google_compute_backend_service              google_compute_region_backend_service
google_compute_url_map                      google_compute_region_url_map
google_compute_target_https_proxy           google_compute_region_target_http_proxy
google_compute_health_check                 google_compute_region_health_check
=======================================     =======================================

These may have slightly different configuration fields, try running ``terraform plan`` for clues.


Make the public IP address regional
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

You will also need to change your public IP address from global to regional. This resource isn't managed by Terraform, it is created when you initialize
your GCP projects. If you're building new GCP projects from scratch you edit the following line in `build/scripts/2-create-projects.sh`:

.. code-block:: console

    gcloud compute addresses create $LB_PUBLIC_IP_NAME --network-tier=PREMIUM --project $CLUSTER_PROJECT_ID --global


Replace `--global` with `--region=$REGION`

If you're doing this on an existing project/cluster, simply create a new regional IP address with the above command, get the IP address value using ``gcloud describe`` and replace ``load_balancer_public_ip_address`` in `build/conf/project-info.json`
