#!/bin/bash

# note: no need to render traefik.toml here, it doesn't have any template variables

consul-template -template "/scripts/services/traefik/dynamic-conf.toml.tmpl:/etc/traefik/dynamic-conf.toml" -once

