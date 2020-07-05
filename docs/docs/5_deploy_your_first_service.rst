*********************************
Deploy your first service
*********************************

To demonstrate how to use Consul/Nomad to host containerized services, we're going to deploy a simple Flask web-service with a Redis database, and add a route in Traefik so that it is accessible from the public internet.


Build the Docker image
----------------------------------------------------

.. code-block:: console

    $ cd gcp-hashi-cluster/docs/tutorials/flask-redis-counter/count-service/
    $ ./build_image.sh

    Step 6/8 : ENV PYTHONPATH /app
     ---> Using cache
     ---> bbe1559dc882
    Step 7/8 : ENV PORT 8080
     ---> Using cache
     ---> a5714a7f9d43
    Step 8/8 : CMD ["python", "/app/main.py"]
     ---> Using cache
     ---> 40fa80bc1e8c
    Successfully built 40fa80bc1e8c
    Successfully tagged eu.gcr.io/hashi-cluster-cbj98124-7cb8/count-webserver:v0.1

This tag is of a **local** Docker image, it has not yet been pushed to a GCP container registry.


.. _pushing_docker_images:

Push the Docker image
----------------------------------------------------

.. code-block:: console

    $ cd gcp-hashi-cluster/operations/  # operations scripts must be run from here

    $ ./nomad/push-docker-image.sh eu.gcr.io/hashi-cluster-cbj98124-7cb8/count-webserver:v0.1

    Success! Your image will be available to Nomad as:  'nomad/count-webserver:v0.1'


This pushes your image to a private GCP container registry and then launches an Ansible playbook to pull it on every Nomad client node.


.. important::

    Due to an unresolved configuration issue, Nomad isn't able to authenticate and pull images from private GCP container registries directly. As a workaround the script above gives your image a tag in the form: `nomad/your-service:v0.1`. You will need to use this in your Nomad jobs.


Submit the webserver Nomad Job
--------------------------------------

- Go to https://nomad.your-domain.com/ui
- Authenticate with your dashboard username and password (set in build/conf/project-defaults.json)
- Click **Run Job** in the top right.
- Copy/paste the contents of ``docs/tutorials/flask-redis-counter/count-webserver.nomad`` in here, ensure the Docker image tag is correct.
- Click **Plan** and the **Run**

.. image:: images/nomad_job_submit.png

Notice the ``sidecar_service { }`` stanza configures an `upstream` connection to a service ``redis-db`` and makes it available at a `local_bind_port`: ``16379``. This can be set to any valid port and doesn't have to match the port of the target service. The container within `count-service-task` can fetch this value from an environment variable ``NOMAD_UPSTREAM_PORT_redis-db``.


Submit the Redis Nomad Job
--------------------------------------
We'll use a public image for Redis so there is no need to build or push it, simply submit this job to Nomad: ``docs/tutorials/flask-redis-counter/count-webserver.nomad``


Add a Consul intention
-----------------------------

Nomad will have registered two Consul services ``count-webserver`` and ``redis-db``. To allow them communicate via the `Consul Connect`__ service mesh we must create an explicit `intention`__. The initialization script already added a ``Traefik -> *`` intention (which you may prefer to replace), we will now add a ``count-webserver -> redis-db`` intention:

__ https://www.consul.io/docs/connect
__ https://www.consul.io/docs/connect/intentions

- Go to https://consul.your-domain.com/ui
- Authenticate using your dashboard username and password, same as with the Nomad UI.
- You will also need to login using an ACL token. Click **login** on the top right, and paste your `Consul UI token (read/write)` from step 4.5.2.
- Navigate to **Intentions** and click **Create**
- Select `count-webserver` as the Source Service and `redis-db` as the Destination Service, choose *Allow* and click **Save**


Create a routing rule in Traefik
-----------------------------------

Your Traefik nodes have a config file ``/etc/traefik/dynamic-conf.toml`` with its routes. The process we use here for updating routes is convenient but a little obtuse in its underlying implementation, you may prefer to simply edit ``dynamic-conf.toml`` directly. You will find the template file in services/traefik/dynamic-conf.toml.tmpl.

- Edit ``gcp-hashi-cluster/operations/traefik/traefik-service-routes.json`` on your local machine, here we will associate a `Traefik router rule`__ with the ``count-webserver`` Consul service. You may also wish to update `dashboards_ip_allowlist` to limit public access to the Consul, Nomad and Traefik web dashboards.

__ https://docs.traefik.io/routing/routers/#rule

.. code-block:: json

    {
      "dashboards_ip_allowlist": ["0.0.0.0/0"],
      "routes": [
        {
          "service_name": "count-webserver",
          "routing_rule": "PathPrefix(`/counter`)"
        }
      ]
    }

.. tip::

    The PathPrefix should be a valid prefix in your service's HTTP API. To add a custom prefix in Traefik there are some options (`StripPrefix`, `HeadersRegexp`) but this can be tricky in practice.


Next run the following script to publish your service routes:

.. code-block:: console

    $ cd gcp-hashi-cluster/operations/
    $ ./traefik/refresh-service-routes.sh


This uploads the json file and re-renders configurations for Traefik and its local `Consul Connect sidecar proxy`__.

__ https://www.consul.io/docs/connect/proxies


Verify your services are working
-----------------------------------

- Go to https://traefik.your-domain.com/ and authenticate with your dashboard username/password. You should see that a new route and service has been created. A service in Traefik isn't equivalent to a Consul service but we link the two together using a common slug.
- Next visit https://your-domain.com/counter/hello and it should say "Hello" back!
- Finally test the counter, go to: https://your-domain.com/counter/increment . You should see the number 1 and this should increment on every refresh. If this fails it means `count-webserver` cannot connect to `redis-db`.

.. tip::

    If any of these steps fail, `submit an issue on github`__ with your error, or `schedule a call with me`__ for assistance.

__ https://github.com/rossrochford/gcp-hashi-cluster/issues/new
__ https://calendly.com/ross-rochford/gcp-hashi-cluster
