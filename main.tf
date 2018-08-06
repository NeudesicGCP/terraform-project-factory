# Project module creates a project and assigns a billing account to it.
#
# Dependencies:
#  Google provider - loaded by the root module

# Retrieve a refernce to the organization using the domain name of org
data "google_organization" "org" {
  domain = "${var.org_domain_name}"
}

# Retrieve the active billing account matching the supplied name
data "google_billing_account" "billing" {
  open         = true
  display_name = "${var.org_billing_name}"
}

# Add a random token to use with project_id to create a unique id. Default to 3
# bytes for a 6 char random suffix.
resource "random_id" "project" {
  byte_length = "3"
}

# Define a project resource; this will create the project
resource "google_project" "project" {
  name = "${var.display_name != "" ? var.display_name : var.project_id}"

  # Project id has to be 30 characters or less; set the format string to
  # truncate display name part by setting string precision as 29 - number of he
  # chars in random portion.
  project_id = "${format("%.[1]*s-%s", 29 - length(random_id.project.hex), var.project_id, random_id.project.hex)}"

  org_id          = "${var.folder_id != "" ? "" : data.google_organization.org.id}"
  folder_id       = "${var.folder_id}"
  billing_account = "${data.google_billing_account.billing.id}"

  # If false (the default), delete the default network after creation.
  # Note that a network must be created elsewhere for this project to be
  # useful.
  auto_create_network = "${var.auto_create_network}"

  # Initially, GAE support should be missing, with a life-cycle
  # stanza that prevents recreating project if app engine config changes.
  lifecycle {
    ignore_changes = ["app_engine"]
  }
}

# Enable any APIs that are provided
resource "google_project_service" "api" {
  count   = "${length(var.enable_apis)}"
  project = "${google_project.project.project_id}"
  service = "${element(var.enable_apis, count.index)}"

  # If this is enabled, removing an entry from the enabled_apis list will cause
  # it to be disabled on the next apply. This is the correct option in our
  # opinion.
  disable_on_destroy = true
}

# Create a bucket for usage export if one has not been explicitly provided
resource "google_storage_bucket" "usage" {
  count         = "${length(var.usage_export_bucket) > 0 ? 0 : 1}"
  project       = "${google_project.project.project_id}"
  name          = "${google_project.project.project_id}"
  storage_class = "MULTI_REGIONAL"
  location      = "${var.usage_export_bucket_location}"

  versioning = {
    enabled = "true"
  }

  force_destroy = "true"
}

locals {
  usage_export_bucket_name = "${join("", concat(google_storage_bucket.usage.*.name, list(var.usage_export_bucket)))}"
}

# Enable usage export
resource "google_project_usage_export_bucket" "usage" {
  project     = "${google_project.project.project_id}"
  bucket_name = "${local.usage_export_bucket_name}"
  prefix      = "${format("usage-%s", google_project.project.project_id)}"
  depends_on  = ["google_project_service.api", "google_storage_bucket.usage"]
}
