# Create networks for the project
resource "google_compute_network" "net" {
  count                   = "${var.shared_vpc_host_project_id != "" ? 0 : length(var.networks)}"
  name                    = "${element(var.networks, count.index)}"
  project                 = "${google_project.project.project_id}"
  auto_create_subnetworks = false
}

# Create the subnets for the project
resource "google_compute_subnetwork" "subnet" {
  count         = "${var.shared_vpc_host_project_id != "" ? 0 : length(var.subnets)}"
  project       = "${google_project.project.project_id}"
  name          = "${length(split(":", element(var.subnets, count.index))) > 3 ? element(split(":", element(var.subnets, count.index)), 3) : format("%s-%s", element(split(":", element(var.subnets, count.index)), 0), element(split(":", element(var.subnets, count.index)), 0))}"
  ip_cidr_range = "${element(split(":", element(var.subnets, count.index)), 2)}"
  region        = "${element(split(":", element(var.subnets, count.index)), 1)}"
  network       = "${element(split(":", element(var.subnets, count.index)), 0)}"

  depends_on = ["google_compute_network.net"]
}

# If this is a shared VPC host, add the networkAdmin accounts to networks
resource "google_project_iam_member" "network-admins" {
  count   = "${var.is_shared_vpc_host ? length(var.network_admins) : 0}"
  project = "${google_project.project.project_id}"
  role    = "roles/compute.networkAdmin"
  member  = "${element(var.network_admins, count.index)}"
}

# If this is a shared VPC service, add the networkUser accounts to network.
resource "google_project_iam_member" "network-users" {
  count   = "${var.shared_vpc_host_project_id != "" ? length(var.network_users) : 0}"
  project = "${var.shared_vpc_host_project_id}"
  role    = "roles/compute.networkUser"
  member  = "${element(var.network_admins, count.index)}"
}
