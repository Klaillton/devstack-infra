#!/bin/bash
# setup-devserverpi.sh
# Idempotent setup for devserverpi to be ready for devstack-infra deploys.
# Standardized to 'master' branch for consistency with source repos (brewer uses master).

set -euo pipefail

echo "=== Preparando devserverpi para devstack-infra (padronizado em master) ==="

setup_repo() {
    local name="$1"
    local url="$2"
    local dir="$3"

    echo ""
    echo ">>> $name ($dir)"

    if [ -d "$dir/.git" ]; then
        echo "Diretório já existe. Atualizando de forma segura..."
        cd "$dir"
        git remote set-url origin "$url" 2>/dev/null || true
        git fetch origin --prune

        if git show-ref --verify --quiet refs/remotes/origin/master; then
            echo "Resetando para origin/master..."
            git reset --hard origin/master
            git checkout -B master origin/master
        elif git show-ref --verify --quiet refs/remotes/origin/main; then
            echo "Detectado origin/main (legado). Resetando para master..."
            git fetch origin main:master 2>/dev/null || true
            git reset --hard origin/master 2>/dev/null || git reset --hard origin/main
            git checkout -B master origin/master 2>/dev/null || git checkout -B master
        else
            echo "Nenhuma ref master/main — usando HEAD remoto..."
            git fetch origin
            git reset --hard $(git ls-remote origin HEAD | cut -f1)
            git checkout -B master
        fi
    else
        echo "Clonando $name..."
        git clone "$url" "$dir"
        cd "$dir"
        git checkout -B master origin/master 2>/dev/null || git checkout -B master origin/main 2>/dev/null || git checkout -B master
    fi

    cd "$dir"
    echo "Commit atual: $(git rev-parse --short HEAD) ($(git rev-parse --abbrev-ref HEAD))"
}

# Brewer (usa master no remoto)
setup_repo "brewer" "https://github.com/Klaillton/brewer.git" "$HOME/brewer"

# Observability (pode usar main ou master)
setup_repo "observability-epo" "https://github.com/Klaillton/observability.git" "$HOME/observability-epo"

echo ""
echo "=== Validação ==="

if command -v kubectl >/dev/null 2>&1; then
    if kubectl get ns >/dev/null 2>&1; then
        echo "✓ kubectl direto OK"
    elif sudo -n kubectl get ns >/dev/null 2>&1; then
        echo "✓ kubectl via sudo -n OK"
    else
        echo "⚠️ kubectl existe mas sem acesso ao cluster"
    fi
fi

kubectl get ns brewer observability 2>/dev/null || echo "kubectl indisponível no momento"

echo ""
echo "Manifests brewer:"
ls -1 "$HOME/brewer/k8s" 2>/dev/null | head -6 || echo "  (não encontrado)"

echo ""
echo "Manifests observability:"
ls -1 "$HOME/observability-epo/k8s/observability" 2>/dev/null | head -6 || echo "  (não encontrado)"

echo ""
echo "=== Setup finalizado ==="
echo "Repositórios alinhados com master. Pronto para deploys via devstack-infra."
