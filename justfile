start-kind:
  #!/usr/bin/env bash
  echo "Start kind cluster"
  kind create cluster --config kuber/kind-config.yaml
  kubectl cluster-info --context kind-kind
  nix build .#ingress-deployment
  kubectl apply -f result --wait
  wait_for_ingress() { 
    kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=90s
  }
  until wait_for_ingress
  do
    sleep 1
    echo "Waiting for ingress to start..."
  done


build-images-and-load-to-kind:
  nix build .#sqlx-migration-image 
  docker load < result 
  kind load docker-image sqlx-migration:latest

  nix build .#project-docker-image
  docker load < result 
  kind load docker-image zero2prod:latest



start-cluster:
  helm lint kuber/demo
  helm install --dry-run --debug zero2prod kuber/demo/
  helm install --debug --wait zero2prod kuber/demo/

stop-cluster:
  helm uninstall zero2prod


stop-kind:
 kind delete cluster 
