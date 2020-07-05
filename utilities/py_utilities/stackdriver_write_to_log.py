import logging
import os
import sys

import google.cloud.logging
from google.cloud.logging.resource import Resource
import requests

client = google.cloud.logging.Client()
client.setup_logging()


LOG_LEVELS = [
    'debug',
    'info',
    'warning',
    'error',
    'critical'
]


def get_instance_resource():

    def _get_instance_id():
        resp = requests.get("http://metadata/computeMetadata/v1/instance/id", headers={"Metadata-Flavor": "Google"})
        return resp.content.decode()

    instance_id = os.environ.get('GCP_INSTANCE_ID') or _get_instance_id()
    return Resource(
        type="gce_instance", labels={"instance_id": instance_id}
    )


def write_log_text(log_level, text):
    # writes a log entry against the Resource for the current instance
    log_level = log_level.lower()
    assert log_level in LOG_LEVELS

    root_logger = logging.getLogger()
    root_logger.handlers = [
        client.get_default_handler(resource=get_instance_resource())
    ]

    func = getattr(root_logger, log_level)
    func(text)


if __name__ == '__main__':
    write_log_text(sys.argv[1], sys.argv[2])
