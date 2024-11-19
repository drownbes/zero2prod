[group('kind')]
kind-start:
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

[group('kind')]
kind-stop:
 kind delete cluster 

[group('kind')]
kind-sqlx-migration-build-and-load-to-kind:
  nix build .#sqlx-migration-image 
  docker load < result 
  kind load docker-image sqlx-migration:latest

[group('kind')]
kind-zero2prod-build-and-load-to-kind:
  nix build .#project-docker-image
  docker load < result 
  kind load docker-image zero2prod:latest

[group('kind')]
kind-fakepostmark-build-and-load-to-kind:
  nix build .#fakepostmark-docker-image
  docker load < result 
  kind load docker-image fakepostmark:latest

[group('kind')]
kind-all-build-and-load-to-kind: 
  just kind-sqlx-migration-build-and-load-to-kind 
  just kind-zero2prod-build-and-load-to-kind 
  just kind-fakepostmark-build-and-load-to-kind


###################################################################

[group('helmfile')]
helmfile-lint:
  helmfile lint -f kuber/helmfile.yaml

[group('helmfile')]
helmfile-apply:
  helmfile apply -f kuber/helmfile.yaml

[group('helm')]
helm-lint:
  helm lint kuber/demo
  helm install --dry-run --debug zero2prod kuber/demo/

[group('helm')]
helm-install: helm-lint
  helm install --debug --wait zero2prod kuber/demo/

[group('helm')]
helm-uninstall:
  helm uninstall zero2prod

[group('helm')]
helm-upgrade:
  helm upgrade zero2prod kuber/demo/

[group('helm')]
helm-repos:
   helm repo add grafana https://grafana.github.io/helm-charts
   helm repo add bitnami https://charts.bitnami.com/bitnami
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

###################################################################


[group('dev')]
dev-process-compose-start-in-bg:
  process-compose --detached

[group('dev')]
dev-process-compose-stop:
  process-compose down

[group('dev')]
dev-local-psql:
  psql $DATABASE_URL
