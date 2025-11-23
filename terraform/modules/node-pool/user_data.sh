#!/bin/bash
set -o errexit
set -o pipefail
set -o nounset

# Bootstrap script for EKS nodes
/etc/eks/bootstrap.sh ${cluster_name} \
  --b64-cluster-ca ${cluster_ca} \
  --apiserver-endpoint ${cluster_endpoint} \
  ${bootstrap_extra_args} \
  --kubelet-extra-args "${kubelet_extra_args}"

