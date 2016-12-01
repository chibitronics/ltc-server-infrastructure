Setting up Infrastructure
=========================

1. Build etcd-ca

  docker run -ti --rm -v /tmp:/out golang /bin/bash
  git clone https://github.com/coreos/etcd-ca
  cd etcd-ca
  ./build
  cp /go/etcd-ca/bin/etcd-ca /out
  exit
  sudo cp /tmp/etcd-ca /usr/local/bin/

2. Set up a CA

  etcd-ca init --passphrase ''

3. Use terraform to apply

  terraform apply
