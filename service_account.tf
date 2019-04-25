# Retrieve the default compute service account
data "google_compute_default_service_account" "default" {
  project = "${google_project.project.project_id}"
}

# Delete the default service account
resource "null_resource" "delete_default_service_account" {
  count = "${var.delete_default_service_account ? 1 : 0}"

  provisioner "local-exec" {
    command = "${path.module}/scripts/delete_service_account.sh ${google_project.project.project_id} ${data.google_compute_default_service_account.default.id} ${var.terraform_credentials}"
  }

  triggers {
    default_service_account = "${data.google_compute_default_service_account.default.id}"
    activated_apis          = "${join(",", var.enable_apis)}"
  }

  depends_on = ["google_project_service.api", "data.google_compute_default_service_account.default"]
}

# Create service accounts for this project.
resource "google_service_account" "sa" {
  count        = "${length(var.service_account_ids)}"
  account_id   = "${element(var.service_account_ids, count.index)}"
  project      = "${google_project.project.project_id}"
  display_name = "${element(var.service_account_ids, count.index)}"
}

locals {
  # If a shared VPC project id has been given, service accounts should be
  # granted access in the host project, but fallback to the project created in
  # this module instance if a host project is unspecified.
  service_account_network_project = "${var.shared_vpc_host_project_id != "" ? var.shared_vpc_host_project_id : google_project.project.project_id}"

  # Be prepared for an empty service_account_subnets list
  service_account_subnets = ["${coalescelist(var.service_account_subnets, list("invalid:invalid:invalid"))}"]
}

# Add the service accounts to the networks defined in project, since the list
# of subnets is empty.
resource "google_project_iam_member" "network_all" {
  count   = "${length(var.service_account_subnets) == 0 && length(var.networks) > 0 ? length(var.service_account_ids) : 0}"
  project = "${local.service_account_network_project}"
  role    = "roles/compute.networkUser"
  member  = "serviceAccount:${element(google_service_account.sa.*.email, count.index)}"
}

# Verify that service_account_subnets_count matches the number of entries in
# service_account_subnets - workaround for Terraform limitation.
# See https://github.com/hashicorp/terraform/issues/10857#issuecomment-368059147
resource "null_resource" "verify_service_account_subnets_count" {
  provisioner "local-exec" {
    command = <<EOF
if [ ${var.service_account_subnets_count} -ne ${length(var.service_account_subnets)} ]; then
  echo "var.service_account_subnets_count must match the length of var.service_account_subnets list"
  exit 1
fi
EOF
  }

  triggers {
    service_account_subnets_computed = "${length(var.service_account_subnets)}"
    service_account_subnets_provided = "${var.service_account_subnets_count}"
  }
}

# Sanitise the service account:subnet list; all raw service account ids will
# become fully-qualified identifiers.
data "null_data_source" "service_account_subnets" {
  count = "${var.service_account_subnets_count}"

  inputs = {
    account = "${replace(element(local.service_account_subnets, count.index), "@", "!") != element(local.service_account_subnets, count.index) ? format("serviceAccount:%s", element(split(":", element(local.service_account_subnets, count.index)), 0)) : format("serviceAccount:%s",join("", matchkeys(google_service_account.sa.*.email, google_service_account.sa.*.account_id, list(element(split(":", element(local.service_account_subnets, count.index)), 0)))))}"
    region  = "${element(split(":", element(local.service_account_subnets, count.index)), 1)}"
    subnet  = "${element(split(":", element(local.service_account_subnets, count.index)), 2)}"
  }
}

# If there are a list of service accounts and subnets to which the service
# account should be granted access, add permissions so that the service account
# can bind to just those subnets.
resource "google_compute_subnetwork_iam_member" "subnets" {
  count      = "${var.service_account_subnets_count}"
  provider   = "google-beta"
  region     = "${lookup(data.null_data_source.service_account_subnets.*.outputs[count.index], "region")}"
  subnetwork = "${lookup(data.null_data_source.service_account_subnets.*.outputs[count.index], "subnet")}"
  project    = "${local.service_account_network_project}"
  role       = "roles/compute.networkUser"
  member     = "${lookup(data.null_data_source.service_account_subnets.*.outputs[count.index], "account")}"
  depends_on = ["google_compute_network.net", "google_compute_subnetwork.subnet"]
}

# This will create *DUPLICATE* resources even though the role will be applied
# once per subnet/region, but we can live with that to make sure that the
# Google APIs Service Agent is added to each subnet that may need it when the
# project is a shared VPC service project.
resource "google_compute_subnetwork_iam_member" "api" {
  count      = "${var.shared_vpc_host_project_id != "" ? var.service_account_subnets_count : 0}"
  provider   = "google-beta"
  region     = "${lookup(data.null_data_source.service_account_subnets.*.outputs[count.index], "region")}"
  subnetwork = "${lookup(data.null_data_source.service_account_subnets.*.outputs[count.index], "subnet")}"
  project    = "${local.service_account_network_project}"
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${google_project.project.number}@cloudservices.gserviceaccount.com"
  depends_on = ["google_compute_network.net", "google_compute_subnetwork.subnet"]
}
