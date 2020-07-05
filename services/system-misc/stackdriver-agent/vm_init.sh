#!/bin/bash

cd /scripts


cp services/system-misc/stackdriver-agent/stackdriver-restart-if-down.service /etc/systemd/system/stackdriver-restart-if-down.service
cp services/system-misc/stackdriver-agent/stackdriver-restart-if-down.timer /etc/systemd/system/stackdriver-restart-if-down.timer
cp services/system-misc/stackdriver-agent/statsd.conf /opt/stackdriver/collectd/etc/collectd.d/statsd.conf

service stackdriver-agent start
systemctl enable stackdriver-restart-if-down.service  # presumably no need to start the service?
systemctl enable stackdriver-restart-if-down.timer
systemctl start stackdriver-restart-if-down.timer
