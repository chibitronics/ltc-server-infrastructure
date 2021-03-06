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
variable "do_hostname" {
    default = "ltc-ns.chibitronics.com"
}
variable "do_region" {
    default = "sgp1"
}
variable "ssh_fingerprint" {}
variable "number_of_masters" {}
variable "number_of_workers" {
    default = "1"
}
variable "hypercube_version" {
    default = "v1.3.6_coreos.0"
}

variable "etcd_cluster_size" {
    default = "3"
}

variable "etcd_discovery_url" {
    default = "etcd_discovery_url.txt"
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
# Etcd host
#
###############################################################################

resource "digitalocean_tag" "k8s" {
    name = "k8s"
}

resource "digitalocean_tag" "k8s_master" {
    name = "k8s_master"
}

resource "null_resource" "ssl_init" {
    # Generate the Certificate Authority
    provisioner "local-exec" {
        command = <<EOF
            rm -f "ca.crt" "client.crt" "client.key.insecure" "client.ca.crt" "apiserver.crt" "apiserver.key.insecure" "apiserver.ca.crt"
            rm -rf ".etcd-ca"
            etcd-ca init --passphrase ''

            etcd-ca chain > ca.crt

            etcd-ca new-cert  --passphrase '' --domain ltc-ns.chibitronics.com,ltc.chibitronics.com,ltc.xobs.io,ltc-cluster.xobs.io,k8s.xobs.io client
            etcd-ca sign  --passphrase '' client
            etcd-ca export --insecure  --passphrase '' client | tar xvf -
            etcd-ca chain client > client.ca.crt

            etcd-ca new-cert  --passphrase '' --domain ltc-ns.chibitronics.com,ltc.chibitronics.com,ltc.xobs.io,ltc-cluster.xobs.io,k8s.xobs.io apiserver
            etcd-ca sign  --passphrase '' apiserver
            etcd-ca export --insecure  --passphrase '' apiserver | tar xvf -
            etcd-ca chain apiserver > apiserver.ca.crt

            dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 > cluster_token
            tr -d '\n' cluster_token > known_tokens.csv
            echo ',default-user,1000,"default-group,other-group,other-other-group"' >> known_tokens.csv

            curl 'https://discovery.etcd.io/new?size=${var.etcd_cluster_size}' > ${var.etcd_discovery_url}
EOF
    }
}

resource "digitalocean_droplet" "k8s_master" {
    image = "coreos-stable"
    depends_on = [ "null_resource.ssl_init" ]
    count = "${var.number_of_masters}"
    name = "${format("k8s-master-%02d", count.index + 1)}"
#    tags   = ["${digitalocean_tag.k8s.id}", "${digitalocean_tag.k8s_master.id}"]
    region = "${var.do_region}"
    private_networking = false
    size = "512mb"
    user_data = "${file("00-coreos-config.yaml")}"
    ssh_keys = [
        "${var.ssh_fingerprint}"
    ]

    provisioner "local-exec" {
        command = <<EOF
            rm -f "${self.name}.ca.crt" "${self.name}.crt" "${self.name}.key.insecure"
            etcd-ca new-cert --passphrase '' --ip "${self.ipv4_address},192.168.3.1" --domain "${self.name}.chibitronics,ltc-ns.chibitronics.com,ltc.chibitronics.com,ltc.xobs.io,ltc-cluster.xobs.io,k8s.xobs.io" ${self.name}
            etcd-ca sign ${self.name}
            etcd-ca export --insecure --passphrase '' ${self.name} | tar xvf -
            etcd-ca chain ${self.name} > ${self.name}.ca.crt
EOF
    }

    # Provision k8s_etcd server certificate
    provisioner "file" {
        source = "./ca.crt"
        destination = "/home/core/ca.pem"
        connection {
            user = "core"
        }
    }
    provisioner "file" {
        source = "./${self.name}.crt"
        destination = "/home/core/etcd.pem"
        connection {
            user = "core"
        }
    }
    provisioner "file" {
        source = "./${self.name}.key.insecure"
        destination = "/home/core/etcd-key.pem"
        connection {
            user = "core"
        }
    }
    provisioner "file" {
        source = "./client.crt"
        destination = "/home/core/client.pem"
        connection {
            user = "core"
        }
    }
    provisioner "file" {
        source = "./client.key.insecure"
        destination = "/home/core/client-key.pem"
        connection {
            user = "core"
        }
    }
    provisioner "file" {
        source = "./apiserver.crt"
        destination = "/home/core/apiserver.pem"
        connection {
            user = "core"
        }
    }
    provisioner "file" {
        source = "./apiserver.key.insecure"
        destination = "/home/core/apiserver-key.pem"
        connection {
            user = "core"
        }
    }
    provisioner "file" {
        source = "${var.etcd_discovery_url}"
        destination = "/home/core/provider_url"
        connection {
            user = "core"
        }
    }
    provisioner "file" {
        source = "./known_tokens.csv"
        destination = "/home/core/known_tokens.csv"
        connection {
            user = "core"
        }
    }

    provisioner "remote-exec" {
        inline = [
            "echo -e '[Service]\nEnvironment=ETCD_NAME=${self.name}' | sudo tee /run/systemd/system/etcd2.service.d/35-name.conf",
            "echo -ne '[Service]\nEnvironment=ETCD_DISCOVERY=' > /tmp/34-discovery.conf",
            "cat /home/core/provider_url >> /tmp/34-discovery.conf",
            "echo '' >> /tmp/34-discovery.conf",
            "sudo mv /tmp/34-discovery.conf /run/systemd/system/etcd2.service.d/34-discovery.conf",

            "sudo mkdir -p /etc/kubernetes/ssl",
            "sudo mkdir -p /etc/ssl/etcd",
            "sudo cp /home/core/{ca,apiserver,apiserver-key,etcd,etcd-key,client,client-key}.pem /etc/ssl/etcd/.",
            "sudo cp /home/core/{ca,apiserver,apiserver-key,etcd,etcd-key,client,client-key}.pem /etc/kubernetes/ssl/.",
            "sudo cp /home/core/known_tokens.csv /etc/kubernetes/ssl/.",

            "echo '127.0.0.1       localhost' > /home/core/hosts",
            "echo '::1             localhost' >> /home/core/hosts",
            "echo '${self.ipv4_address} ${self.name}' >> /home/core/hosts",
            "sudo mv /home/core/hosts /etc/hosts",

            "sudo systemctl daemon-reload",
            "sudo systemctl restart systemd-resolved",

            "sudo systemctl start etcd2 &",
            "sudo systemctl enable etcd2",

            "sudo dd if=/dev/zero of=/swap bs=1M count=2048",
            "sudo chmod 0600 /swap",
            "sudo mkswap /swap",
            "sudo swapon /swap",
            "sudo systemctl enable extraswap",

            "sudo systemctl start flanneld &",
            "sudo systemctl enable flanneld",

            "sudo systemctl start kubelet &",
            "sudo systemctl enable kubelet",

            # Wait for the machine to start up
#            "until $(curl --output /dev/null --silent --head --fail http://127.0.0.1:8080); do printf '.'; sleep 5; done",
            "true"
        ]
        connection {
            user = "core"
        }
    }
}

resource "digitalocean_record" "master_a" {
    count  = "${var.number_of_masters}"
    domain = "${var.domain}"
    type   = "A"
    name   = "${element(digitalocean_droplet.k8s_master.*.name, count.index)}"
    value  = "${element(digitalocean_droplet.k8s_master.*.ipv4_address, count.index)}"
}

resource "digitalocean_record" "master_root_a" {
    count  = "${var.number_of_masters}"
    domain = "${var.domain}"
    type   = "A"
    name   = "@"
    value  = "${element(digitalocean_droplet.k8s_master.*.ipv4_address, count.index)}"
}

resource "null_resource" "setup_etcdctl" {
    depends_on = ["digitalocean_droplet.k8s_master"]
    provisioner "local-exec" {
        command = <<EOF
            echo export ETCDCTL_CERT_FILE=/home/core/client.pem > setup_etcdctl.sh
            echo export ETCDCTL_KEY_FILE=/home/core/client-key.pem >> setup_etcdctl.sh
            echo export ETCDCTL_CA_FILE=/home/core/ca.pem >> setup_etcdctl.sh
            echo export ETCDCTL_PEERS=${join(",", formatlist("https://%s:2379/", digitalocean_droplet.k8s_master.*.ipv4_address))} >> setup_etcdctl.sh
            echo -e 'Servers running:\n${join("\n", formatlist("    ssh core@%s", digitalocean_droplet.k8s_master.*.ipv4_address))}'
EOF
    }
}

resource "null_resource" "setup_kubectl" {
    depends_on = ["digitalocean_droplet.k8s_master"]
    provisioner "local-exec" {
        command = <<EOF
            echo export MASTER_HOST=k8s.xobs.io > $PWD/setup_kubectl.sh
            echo export CA_CERT=$PWD/ca.crt >> $PWD/setup_kubectl.sh
            echo export ADMIN_KEY=$PWD/client.key.insecure >> $PWD/setup_kubectl.sh
            echo export ADMIN_CERT=$PWD/client.crt >> $PWD/setup_kubectl.sh
            . $PWD/setup_kubectl.sh
            kubectl config set-cluster default-cluster \
                --server=https://$MASTER_HOST --certificate-authority=$CA_CERT
            kubectl config set-credentials default-admin \
                 --certificate-authority=$CA_CERT --client-key=$ADMIN_KEY --client-certificate=$ADMIN_CERT \
                 --token=$(cat cluster_token)
            kubectl config set-context default-system --cluster=default-cluster --user=default-admin
            kubectl config use-context default-system
EOF
    }
}


data "template_file" "worker_yaml" {
    template = "${file("01-worker.yaml")}"
    vars {
        DNS_SERVICE_IP = "192.168.3.10"
        ETCD_ENDPOINTS = "${join(",", formatlist("https://%s:2379/", digitalocean_droplet.k8s_master.*.ipv4_address))}"
        MASTER_HOSTS = "${join(",", formatlist("https://%s/", digitalocean_droplet.k8s_master.*.ipv4_address))}"
        HYPERCUBE_VERSION = "${var.hypercube_version}"
    }
}

resource "digitalocean_droplet" "k8s_worker" {
    count = "${var.number_of_workers}"
    image = "coreos-stable"
    name = "${format("k8s-worker-%02d", count.index + 1)}"
    region = "${var.do_region}"
    size = "512mb"
    private_networking = false
    user_data = "${data.template_file.worker_yaml.rendered}"
    ssh_keys = [
        "${var.ssh_fingerprint}"
    ]


    # Create client certificate
    provisioner "local-exec" {
        command = <<EOF
            rm -f "${self.name}.ca.crt" "${self.name}.crt" "${self.name}.key.insecure"
            etcd-ca new-cert --passphrase '' --ip "${self.ipv4_address}" --domain "${self.name}.chibitronics,ltc-ns.chibitronics.com,ltc.chibitronics.com,ltc.xobs.io,ltc-cluster.xobs.io,k8s.xobs.io" ${self.name}
            etcd-ca sign ${self.name}
            etcd-ca export --insecure --passphrase '' ${self.name} | tar xvf -
            etcd-ca chain ${self.name} > ${self.name}.ca.crt
EOF
    }

    provisioner "file" {
        source = "./ca.crt"
        destination = "/home/core/ca.pem"
        connection {
            user = "core"
        }
    }
    provisioner "file" {
        source = "./${self.name}.crt"
        destination = "/home/core/etcd.pem"
        connection {
            user = "core"
        }
    }
    provisioner "file" {
        source = "./${self.name}.key.insecure"
        destination = "/home/core/etcd-key.pem"
        connection {
            user = "core"
        }
    }
    provisioner "file" {
        source = "./client.crt"
        destination = "/home/core/client.pem"
        connection {
            user = "core"
        }
    }
    provisioner "file" {
        source = "./client.key.insecure"
        destination = "/home/core/client-key.pem"
        connection {
            user = "core"
        }
    }
    provisioner "file" {
        source = "${var.etcd_discovery_url}"
        destination = "/home/core/provider_url"
        connection {
            user = "core"
        }
    }

    # TODO: permissions on these keys
    provisioner "remote-exec" {
        inline = [
            "sudo mkdir -p /etc/kubernetes/ssl",
            "sudo cp /home/core/{ca,etcd,etcd-key}.pem /etc/kubernetes/ssl/.",
            "sudo mkdir -p /etc/ssl/etcd/",
            "sudo cp /home/core/{ca,etcd,etcd-key}.pem /etc/ssl/etcd/."
        ]
        connection {
            user = "core"
        }
    }

    # Start kubelet
    provisioner "remote-exec" {
        inline = [
            "echo -e '[Service]\nEnvironment=ETCD_NAME=${self.name}' | sudo tee /run/systemd/system/etcd2.service.d/35-name.conf",
            "echo -ne '[Service]\nEnvironment=ETCD_DISCOVERY=' > /tmp/34-discovery.conf",
            "cat /home/core/provider_url >> /tmp/34-discovery.conf",
            "echo '' >> /tmp/34-discovery.conf",
            "sudo mv /tmp/34-discovery.conf /run/systemd/system/etcd2.service.d/34-discovery.conf",

            # Enable swap
            "sudo dd if=/dev/zero of=/swap bs=1M count=2048",
            "sudo chmod 0600 /swap",
            "sudo mkswap /swap",
            "sudo swapon /swap",

            "sudo systemctl daemon-reload",
            "sudo systemctl enable extraswap",
            "sudo systemctl restart systemd-resolved",

            "sudo systemctl start etcd2",
            "sudo systemctl enable etcd2",
            "until curl --cacert /home/core/ca.pem --cert /home/core/client.pem --key /home/core/client-key.pem -X PUT -d 'value={\"Network\":\"10.2.0.0/16\",\"Backend\":{\"Type\":\"vxlan\"}}' https://${self.ipv4_address}:2379/v2/keys/coreos.com/network/config; do sleep 1; done",

            "sudo systemctl start flanneld",
            "sudo systemctl enable flanneld",
            "sudo systemctl start kubelet",
            "sudo systemctl enable kubelet"
        ]
        connection {
            user = "core"
        }
    }
}


resource "digitalocean_record" "worker_a" {
    count  = "${var.number_of_workers}"
    domain = "${var.domain}"
    type   = "A"
    name   = "${element(digitalocean_droplet.k8s_worker.*.name, count.index)}"
    value  = "${element(digitalocean_droplet.k8s_worker.*.ipv4_address, count.index)}"
}


###############################################################################
#
# Master host's user data template
#
###############################################################################
#
#
#data "template_file" "master_yaml" {
#    template = "${file("01-master.yaml")}"
#    vars {
#        DNS_SERVICE_IP = "10.3.0.10"
#        ETCD_IP = "${digitalocean_droplet.k8s_etcd.ipv4_address_private}"
#        POD_NETWORK = "10.2.0.0/16"
#        SERVICE_IP_RANGE = "10.3.0.0/24"
#        HYPERCUBE_VERSION = "${var.hypercube_version}"
#    }
#}


###############################################################################
#
# Master host
#
###############################################################################


#resource "digitalocean_droplet" "k8s_master" {
#    image = "coreos-stable"
#    name = "k8s-master"
#    region = "${var.do_region}"
#    private_networking = true
#    size = "512mb"
#    user_data = "${data.template_file.master_yaml.rendered}"
#    ssh_keys = [
#        "${var.ssh_fingerprint}"
#    ]
#
#    # Generate k8s_master server certificate
#    provisioner "local-exec" {
#        command = <<EOF
#            $PWD/cfssl/generate_server.sh k8s_master "${digitalocean_droplet.k8s_master.ipv4_address},${digitalocean_droplet.k8s_master.ipv4_address_private},10.3.0.1,kubernetes.default,kubernetes,ltc.chibitronics.com,ltc-ns.chibitronics.com"
#EOF
#    }
#
#    # Provision k8s_etcd server certificate
#    provisioner "file" {
#        source = "./secrets/ca.pem"
#        destination = "/home/core/ca.pem"
#        connection {
#            user = "core"
#        }
#    }
#    provisioner "file" {
#        source = "./secrets/k8s_master.pem"
#        destination = "/home/core/apiserver.pem"
#        connection {
#            user = "core"
#        }
#    }
#    provisioner "file" {
#        source = "./secrets/k8s_master-key.pem"
#        destination = "/home/core/apiserver-key.pem"
#        connection {
#            user = "core"
#        }
#    }
#
#    # Generate k8s_master client certificate
#    provisioner "local-exec" {
#        command = <<EOF
#            $PWD/cfssl/generate_client.sh k8s_master
#EOF
#    }
#
#    # Provision k8s_master client certificate
#    provisioner "file" {
#        source = "./secrets/client-k8s_master.pem"
#        destination = "/home/core/client.pem"
#        connection {
#            user = "core"
#        }
#    }
#    provisioner "file" {
#        source = "./secrets/client-k8s_master-key.pem"
#        destination = "/home/core/client-key.pem"
#        connection {
#            user = "core"
#        }
#    }
#
#    # TODO: figure out permissions and chown, chmod key.pem files
#    provisioner "remote-exec" {
#        inline = [
#            "sudo mkdir -p /etc/kubernetes/ssl",
#            "sudo cp /home/core/{ca,apiserver,apiserver-key,client,client-key}.pem /etc/kubernetes/ssl/.",
#            "rm /home/core/{apiserver,apiserver-key}.pem",
#            "sudo mkdir -p /etc/ssl/etcd",
#            "sudo mv /home/core/{ca,client,client-key}.pem /etc/ssl/etcd/.",
#        ]
#        connection {
#            user = "core"
#        }
#    }
#
#    # Start kubelet and create kube-system namespace
#    provisioner "remote-exec" {
#        inline = [
#            "sudo systemctl daemon-reload",
#            "curl --cacert /etc/kubernetes/ssl/ca.pem --cert /etc/kubernetes/ssl/client.pem --key /etc/kubernetes/ssl/client-key.pem -X PUT -d 'value={\"Network\":\"10.2.0.0/16\",\"Backend\":{\"Type\":\"vxlan\"}}' https://${digitalocean_droplet.k8s_etcd.ipv4_address_private}:2379/v2/keys/coreos.com/network/config",
#            "sudo systemctl start flanneld",
#            "sudo systemctl enable flanneld",
#            "sudo systemctl start kubelet",
#            "sudo systemctl enable kubelet",
#            "until $(curl --output /dev/null --silent --head --fail http://127.0.0.1:8080); do printf '.'; sleep 5; done",
#            "curl -XPOST -H 'Content-type: application/json' -d'{\"apiVersion\":\"v1\",\"kind\":\"Namespace\",\"metadata\":{\"name\":\"kube-system\"}}' http://127.0.0.1:8080/api/v1/namespaces"
#        ]
#        connection {
#            user = "core"
#        }
#    }
#}


###############################################################################
#
# Worker host's user data template
#
###############################################################################


#data "template_file" "master_yaml" {
#    template = "${file("02-worker.yaml")}"
#    vars {
#        DNS_SERVICE_IP = "10.3.0.10"
#        ETCD_IP = "${digitalocean_droplet.k8s_etcd.ipv4_address_private}"
#        MASTER_HOST = "${digitalocean_droplet.k8s_master.ipv4_address_private}"
#        HYPERCUBE_VERSION = "${var.hypercube_version}"
#    }
#}


###############################################################################
#
# Worker hosts
#
###############################################################################


#resource "digitalocean_droplet" "k8s_worker" {
#    count = "${var.number_of_workers}"
#    image = "coreos-stable"
#    name = "${format("k8s-worker-%02d", count.index + 1)}"
#    region = "${var.do_region}"
#    size = "512mb"
#    private_networking = true
#    user_data = "${data.template_file.worker_yaml.rendered}"
#    ssh_keys = [
#        "${var.ssh_fingerprint}"
#    ]
#
#
#
#    # Generate k8s_worker client certificate
#    provisioner "local-exec" {
#        command = <<EOF
#            $PWD/cfssl/generate_client.sh k8s_worker
#EOF
#    }
#
#    # Provision k8s_master client certificate
#    provisioner "file" {
#        source = "./secrets/ca.pem"
#        destination = "/home/core/ca.pem"
#        connection {
#            user = "core"
#        }
#    }
#    provisioner "file" {
#        source = "./secrets/client-k8s_worker.pem"
#        destination = "/home/core/worker.pem"
#        connection {
#            user = "core"
#        }
#    }
#    provisioner "file" {
#        source = "./secrets/client-k8s_worker-key.pem"
#        destination = "/home/core/worker-key.pem"
#        connection {
#            user = "core"
#        }
#    }
#
#    # TODO: permissions on these keys
#    provisioner "remote-exec" {
#        inline = [
#            "sudo mkdir -p /etc/kubernetes/ssl",
#            "sudo cp /home/core/{ca,worker,worker-key}.pem /etc/kubernetes/ssl/.",
#            "sudo mkdir -p /etc/ssl/etcd/",
#            "sudo mv /home/core/{ca,worker,worker-key}.pem /etc/ssl/etcd/."
#        ]
#        connection {
#            user = "core"
#        }
#    }
#
#    # Start kubelet
#    provisioner "remote-exec" {
#        inline = [
#            "sudo systemctl daemon-reload",
#            "sudo systemctl start flanneld",
#            "sudo systemctl enable flanneld",
#            "sudo systemctl start kubelet",
#            "sudo systemctl enable kubelet"
#        ]
#        connection {
#            user = "core"
#        }
#    }
#}

###############################################################################
#
# Make config file and export variables for kubectl
#
###############################################################################


#resource "null_resource" "make_admin_key" {
#    depends_on = ["digitalocean_droplet.k8s_worker"]
#    provisioner "local-exec" {
#        command = <<EOF
#            $PWD/cfssl/generate_admin.sh
#EOF
#    }
#}
# 
#resource "null_resource" "setup_kubectl" {
#    depends_on = ["null_resource.make_admin_key"]
#    provisioner "local-exec" {
#        command = <<EOF
#            echo export MASTER_HOST=${digitalocean_droplet.k8s_master.ipv4_address} > $PWD/secrets/setup_kubectl.sh
#            echo export CA_CERT=$PWD/secrets/ca.pem >> $PWD/secrets/setup_kubectl.sh
#            echo export ADMIN_KEY=$PWD/secrets/admin-key.pem >> $PWD/secrets/setup_kubectl.sh
#            echo export ADMIN_CERT=$PWD/secrets/admin.pem >> $PWD/secrets/setup_kubectl.sh
#            . $PWD/secrets/setup_kubectl.sh
#            kubectl config set-cluster default-cluster \
#                --server=https://$MASTER_HOST --certificate-authority=$CA_CERT
#            kubectl config set-credentials default-admin \
#                 --certificate-authority=$CA_CERT --client-key=$ADMIN_KEY --client-certificate=$ADMIN_CERT
#            kubectl config set-context default-system --cluster=default-cluster --user=default-admin
#            kubectl config use-context default-system
#EOF
#    }
#}
#
#resource "null_resource" "deploy_dns_addon" {
#    depends_on = ["null_resource.setup_kubectl"]
#    provisioner "local-exec" {
#        command = <<EOF
#            until kubectl get pods 2>/dev/null; do printf '.'; sleep 5; done
#            kubectl create -f 03-dns-addon.yaml
#EOF
#    }
#}
#
#resource "null_resource" "deploy_microbot" {
#    depends_on = ["null_resource.setup_kubectl"]
#    provisioner "local-exec" {
#        command = <<EOF
#            sed -e "s/\$EXT_IP1/${digitalocean_droplet.k8s_worker.0.ipv4_address}/" < 04-microbot.yaml > ./secrets/04-microbot.rendered.yaml
#            until kubectl get pods 2>/dev/null; do printf '.'; sleep 5; done
#            kubectl create -f ./secrets/04-microbot.rendered.yaml
#
#EOF
#    }
#}
