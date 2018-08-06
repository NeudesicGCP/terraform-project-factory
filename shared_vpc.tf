# Make the project a shared VPC host if flag is set
resource "google_compute_shared_vpc_host_project" "host" {
  count   = "${var.is_shared_vpc_host ? 1 : 0}"
  project = "${google_project.project.project_id}"
}

# If the project is to be used with a shared VPC host
resource "google_compute_shared_vpc_service_project" "service_project" {
  count           = "${var.shared_vpc_host_project_id != "" ? 1 : 0}"
  host_project    = "${var.shared_vpc_host_project_id}"
  service_project = "${google_project.project.project_id}"
}
