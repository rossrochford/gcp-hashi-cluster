
provider "google" {
  credentials = file(var.cluster_tf_service_account_credentials_filepath)
  project = var.cluster_service_project_id
  region = var.region
}

provider "google-beta" {
  credentials = file(var.cluster_tf_service_account_credentials_filepath)
  project = var.cluster_service_project_id
  region  = var.region
}


terraform {
  experiments = [variable_validation]
}
