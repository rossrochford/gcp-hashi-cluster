import os
import syslog
import logging

from flask import Flask, request
from waitress import serve
import redis


logger = logging.getLogger('spam_application')
logger.setLevel(logging.DEBUG)
# create file handler which logs even debug messages
fh = logging.FileHandler('/tmp/spam.log')
fh.setLevel(logging.DEBUG)
logger.addHandler(fh)


PORT = int(os.environ.get('PORT', 8080))

REDIS_PORT = 16379
REDIS_KEY = 'count-service-int'


app = Flask(__name__)
redis_cli = redis.Redis(host='localhost', port=REDIS_PORT, db=0)


@app.route("/counter/hello")
def hello():
    logger.debug('yo')
    print('yo')
    return "Hello!"


@app.route('/counter/hello-post', methods=['POST'])
def hello_post():
    logger.debug('yo-post')
    data = request.data
    logger.debug(str(data))
    return "Hello!"


@app.route("/counter/increment")
def increment():
    logger.debug('incrementing')
    value = redis_cli.get(REDIS_KEY) or 0

    value = str(int(value) + 1)

    redis_cli.set(REDIS_KEY, value)
    return value


if __name__ == "__main__":
    serve(app, host='0.0.0.0', port=PORT)
