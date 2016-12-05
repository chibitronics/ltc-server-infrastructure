###############################################################################
#
# A simple K8s cluster in DO
#
###############################################################################


###############################################################################
#
# Get variables from command line or environment
#
###############################################################################


variable "do_token" {}
variable "do_region" {
    default = "sgp1"
}
variable "ssh_fingerprint" {}
variable "number_of_workers" {
    default = "1"
}
variable "domain" {
    default = "k8s.xobs.io"
}

###############################################################################
#
# Specify provider
#
###############################################################################


provider "digitalocean" {
  token = "${var.do_token}"
}


###############################################################################
#
# Compiler host
#
###############################################################################

resource "digitalocean_droplet" "ltc_worker" {
    image = "coreos-stable"
    count = "${var.number_of_workers}"
    name = "${format("ltc-worker-%02d", count.index + 1)}"
    region = "${var.do_region}"
    private_networking = false
    size = "512mb"
    user_data = "${file("00-coreos-config.yaml")}"
    ssh_keys = [
        "${var.ssh_fingerprint}"
    ]

#    provisioner "remote-exec" {
#        inline = [
#            "sudo systemctl daemon-reload",
#            "sudo systemctl restart systemd-resolved",
#
#            "sudo dd if=/dev/zero of=/swap bs=1M count=4096",
#            "sudo chmod 0600 /swap",
#            "sudo mkswap /swap",
#            "sudo swapon /swap",
#            "sudo systemctl enable extraswap",
#
#            "sudo systemctl start ltc-network ltc-compiler ltc-ux ltc-compiler-frontend ltc-frontend",
#            "sudo systemctl enable ltc-network ltc-compiler ltc-ux ltc-compiler-frontend ltc-frontend",
#            "true"
#        ]
#        connection {
#            user = "core"
#        }
#    }
}

resource "digitalocean_record" "worker_a" {
    count  = "${var.number_of_workers}"
    domain = "${var.domain}"
    type   = "A"
    name   = "${element(digitalocean_droplet.ltc_worker.*.name, count.index)}"
    value  = "${element(digitalocean_droplet.ltc_worker.*.ipv4_address, count.index)}"
}

resource "digitalocean_record" "worker_root_a" {
    count  = "${var.number_of_workers}"
    domain = "${var.domain}"
    type   = "A"
    name   = "@"
    value  = "${element(digitalocean_droplet.ltc_worker.*.ipv4_address, count.index)}"
}

