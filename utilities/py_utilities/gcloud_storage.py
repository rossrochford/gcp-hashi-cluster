import sys

from google.cloud import storage

from py_utilities.util import get_project_info


def create_bucket(bucket_name):
    storage_client = storage.Client()

    bucket = storage_client.bucket(bucket_name)
    if bucket.exists():
        print('success')
        return

    project_info = get_project_info()
    region = project_info['region'].upper()

    try:
        bucket = storage_client.create_bucket(
            bucket_name, location=region
        )
    except:
        print('failed')
        return
    if bucket.exists():
        print('success')
    else:
        print('failed')


def upload_file(bucket_name, source_file_name, bucket_path):
    """Uploads a file to the bucket."""
    # bucket_name = "your-bucket-name"
    # source_file_name = "local/path/to/file"
    # destination_blob_name = "storage-object-name"

    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(bucket_path)

    try:
        blob.upload_from_filename(source_file_name)
    except:
        print('failed')
        return
    print('success')


def download_file(bucket_name, bucket_path, destination_file_name):
    """Downloads a blob from the bucket."""
    # bucket_name = "your-bucket-name"
    # source_blob_name = "storage-object-name"
    # destination_file_name = "local/path/to/file"

    storage_client = storage.Client()

    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(bucket_path)
    blob.download_to_filename(destination_file_name)


def check_file_exists(bucket_name, bucket_path):
    storage_client = storage.Client()
    bucket = storage_client.get_bucket(bucket_name)
    blob = bucket.blob(bucket_path)
    if blob.exists():
        print('yes')
    else:
        print('no')


def delete_file(bucket_name, bucket_path):
    """Deletes a blob from the bucket."""

    storage_client = storage.Client()

    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(bucket_path)
    try:
        blob.delete()
    except:
        print('failed')
        return
    print('success')


if __name__ == '__main__':
    action = sys.argv[1]
    arguments = sys.argv[2:]

    if action == 'create-bucket':
        create_bucket(arguments[0])
    elif action == 'upload-file':
        upload_file(*arguments)
    elif action == 'download-file':
        download_file(*arguments)
    elif action == 'check-file-exists':
        check_file_exists(*arguments)
    elif action == 'delete-file':
        delete_file(*arguments)
