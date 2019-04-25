# Even though the net, subnet, and IAM resources are gated by a shared VPC
# flags and counts, the interpolator will throw errors if element(list, index)
# is used and the list is empty. These local variables include a dummy list
# entry so that the interpolaror is satisfied. The values are deliberately
# invalid so that broken logic will result in a resource creation failure.
locals {
  networks       = ["${coalescelist(var.networks, list("invalid"))}"]
  subnets        = ["${coalescelist(var.subnets, list("invalid:invalid:1.1.1.1/32:invalid"))}"]
  network_admins = ["${coalescelist(var.network_admins, list("invalid"))}"]
  network_users  = ["${coalescelist(var.network_users, list("invalid"))}"]
}

# Create networks for the project
resource "google_compute_network" "net" {
  count                   = "${var.shared_vpc_host_project_id != "" ? 0 : length(var.networks)}"
  name                    = "${element(local.networks, count.index)}"
  project                 = "${google_project.project.project_id}"
  auto_create_subnetworks = false
}

# Create the subnets for the project
resource "google_compute_subnetwork" "subnet" {
  count                    = "${var.shared_vpc_host_project_id != "" ? 0 : length(var.subnets)}"
  project                  = "${google_project.project.project_id}"
  name                     = "${length(split(":", element(local.subnets, count.index))) > 3 ? element(split(":", element(local.subnets, count.index)), 3) : format("%s-%s", element(split(":", element(local.subnets, count.index)), 0), element(split(":", element(local.subnets, count.index)), 0))}"
  ip_cidr_range            = "${element(split(":", element(local.subnets, count.index)), 2)}"
  region                   = "${element(split(":", element(local.subnets, count.index)), 1)}"
  network                  = "${element(split(":", element(local.subnets, count.index)), 0)}"
  private_ip_google_access = "${length(split(":", element(local.subnets, count.index))) > 4 ? element(split(":", element(local.subnets, count.index)), 4) : "false"}"

  depends_on = ["google_compute_network.net"]
}

# If this is a shared VPC host, add the networkAdmin accounts to networks
resource "google_project_iam_member" "network-admins" {
  count   = "${var.is_shared_vpc_host ? length(var.network_admins) : 0}"
  project = "${google_project.project.project_id}"
  role    = "roles/compute.networkAdmin"
  member  = "${element(local.network_admins, count.index)}"
}

# If this is a shared VPC service, add the networkUser accounts to network.
resource "google_project_iam_member" "network-users" {
  count   = "${var.shared_vpc_host_project_id != "" ? length(var.network_users) : 0}"
  project = "${var.shared_vpc_host_project_id}"
  role    = "roles/compute.networkUser"
  member  = "${element(local.network_users, count.index)}"
}
