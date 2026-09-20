#!/usr/bin/env_bash
set -euo pipefail

log()  { echo "[tf-runner] $*" >&2; }
fail() { echo "[tf-runner]-[ERROR] $*" >&2; exit 1; }

# Variaveis obrigatorias
: "${ACTION: ?Defina ACTION=plan|apply|destroy}"
: "${GIT_REPO_URL: ?Defina GIT_REPO_URL seu repositorio com diretório IaC e código terraform}"
