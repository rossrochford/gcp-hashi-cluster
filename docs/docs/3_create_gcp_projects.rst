*********************************
Create GCP Projects
*********************************

If you're using a fresh installation of Google Cloud SDK, run  ``gcloud init``. Otherwise run ``gcloud components update`` to ensure it is up to date.

To authenticate the SDK with your account, run: ``gcloud auth login``. This will open web browser window, select your Google Cloud Identity (or GSuite) account to grant access to the SDK. Feel free to create a new project if it asks you to, we won't be using it, the build script below creates the necessary GCP projects.

Google should have created a new GCP organization for your domain name. Get the organization ID:

.. code-block:: console

    $ gcloud organizations list

    DISPLAY_NAME              ID                          DIRECTORY_CUSTOMER_ID
    yourdomain.com            512851330921                DK07gy8mvj


You should also have a billing account, get its ID:

.. code-block:: console

    $ gcloud beta billing accounts list

    ACCOUNT_ID                 NAME                       OPEN        MASTER_ACCOUNT_ID
    04G191-25080H-12J8C3       My Billing Account         True


.. Hint:: There are default quota limits on the number of projects that can be linked to a billing account (5 I think?). The script below needs sufficient quota to link two new projects to your billing account. You can view the existing projects linked to a billing account at: `https://console.cloud.google.com/billing/<billing_account_id>/manage`


Next open the project-defaults file: `build/conf/project-defaults.json` and fill in the following fields:

- organization_id
- organization_admin_user_email
- billing_account_id
- domain_name   (e.g. ``example.com``)
- region  (see ``gcloud compute regions list`` for valid regions)
- dashboards_password (don't forget this!)

You may also want to adjust the number of `hashi_clients` or `vault_servers`, or increase the size of the instances. The value of `num_hashi_servers` must be 3, 5 or 7, if you set it to 5 or 7, you may also want to update ``bootstrap_expect`` in Consul.


Run the first build script:

.. code-block:: console

    $ cd gcp-hashi-cluster/build/     # build scripts must be run from this directory

    $ ./1-initialize-gcp-projects.sh


This will take about 10 minutes to complete. The following items will be created:

- Two projects named: *vpc-host-project-<uuid>* and *hashi-cluster-<uuid>*. These prefixes can be set in *project-defaults.json*.
- Three service accounts, two highly privileged accounts for Terraform, and a third more restricted account that will be assigned to instances.
- Credentials keys (json) for the service accounts and an SSH key used by Packer, these are stored in the *keys/* directory.
- A shared VPC network and a subnetwork for the cluster service project.
- A public IP address for the load-balancer.
- A KMS keyring and key.
- A json file **build/conf/project-info.json** with configuration parameters for Packer, Terraform and the remaining build scripts. Be careful when updating this file, some values can be altered, such as `num_hashi_clients` or `sub_domains`, but some others should not be.
