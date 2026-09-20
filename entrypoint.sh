#!/usr/bin/env bash
set -euo pipefail

# =========================================================================
# entrypoint.sh
# Clona um repositório Git com código Terraform/Terragrunt, executa init
# com backend remoto S3 e roda plan | apply | destroy.
# =========================================================================

log()  { echo "[tf-runner] $*" >&2; }
fail() { echo "[tf-runner][ERRO] $*" >&2; exit 1; }

# ---------------------------------------------------------------------
# Variáveis obrigatórias
# ---------------------------------------------------------------------
: "${ACTION:?Defina ACTION=plan|apply|destroy}"
: "${GIT_REPO_URL:?Defina GIT_REPO_URL (ex: https://github.com/org/repo.git)}"
: "${BACKEND_BUCKET:?Defina BACKEND_BUCKET (bucket S3 do backend remoto)}"
: "${BACKEND_KEY:?Defina BACKEND_KEY (caminho do state dentro do bucket, ex: magellan/prd/terraform.tfstate)}"

# ---------------------------------------------------------------------
# Variáveis opcionais (com default)
# ---------------------------------------------------------------------
TOOL="${TOOL:-terragrunt}"                     # terraform | terragrunt
GIT_BRANCH="${GIT_BRANCH:-main}"
GIT_SUBDIR="${GIT_SUBDIR:-.}"                  # subpasta dentro do repo onde está o código
BACKEND_REGION="${BACKEND_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
BACKEND_DYNAMODB_TABLE="${BACKEND_DYNAMODB_TABLE:-}"   # lock table (opcional, mas recomendado)
BACKEND_ENCRYPT="${BACKEND_ENCRYPT:-true}"
AUTO_APPROVE="${AUTO_APPROVE:-true}"           # aplica -auto-approve em apply/destroy
TF_VAR_FILE="${TF_VAR_FILE:-}"                 # ex: envs/prd.tfvars
EXTRA_ARGS="${EXTRA_ARGS:-}"                   # args adicionais livres, ex: "-target=aws_s3_bucket.x"
WORKDIR="/workspace/src"

case "$ACTION" in
  plan|apply|destroy) ;;
  *) fail "ACTION inválido: '$ACTION' (use plan, apply ou destroy)" ;;
esac

case "$TOOL" in
  terraform|terragrunt) ;;
  *) fail "TOOL inválido: '$TOOL' (use terraform ou terragrunt)" ;;
esac

# ---------------------------------------------------------------------
# 1) Clonar o repositório
# ---------------------------------------------------------------------
log "Clonando ${GIT_REPO_URL} (branch: ${GIT_BRANCH})..."
rm -rf "$WORKDIR"

CLONE_URL="$GIT_REPO_URL"
if [[ -n "${GIT_TOKEN:-}" && "$GIT_REPO_URL" == https://* ]]; then
  # injeta token para repositórios privados via HTTPS (ex: GitHub PAT, GitLab token)
  CLONE_URL="$(echo "$GIT_REPO_URL" | sed -E "s#https://#https://${GIT_TOKEN}@#")"
fi

git clone --depth 1 --branch "$GIT_BRANCH" "$CLONE_URL" "$WORKDIR" \
  || fail "Falha ao clonar o repositório. Verifique GIT_REPO_URL, GIT_BRANCH e GIT_TOKEN."

TARGET_DIR="${WORKDIR}/${GIT_SUBDIR}"
[[ -d "$TARGET_DIR" ]] || fail "Diretório '${GIT_SUBDIR}' não encontrado no repositório."
cd "$TARGET_DIR"

# ---------------------------------------------------------------------
# 2) Confirmar identidade AWS (falha cedo se credenciais estiverem erradas)
# ---------------------------------------------------------------------
log "Validando credenciais AWS..."
aws sts get-caller-identity --output text >/dev/null \
  || fail "Credenciais AWS inválidas/ausentes. Configure AWS_ACCESS_KEY_ID/SECRET, um profile ou uma IAM Role."

# ---------------------------------------------------------------------
# 3) terraform/terragrunt init com backend remoto S3
# ---------------------------------------------------------------------
if [[ "$TOOL" == "terraform" ]]; then
  log "Executando terraform init (backend S3: s3://${BACKEND_BUCKET}/${BACKEND_KEY})..."
  INIT_ARGS=(
    -backend-config="bucket=${BACKEND_BUCKET}"
    -backend-config="key=${BACKEND_KEY}"
    -backend-config="region=${BACKEND_REGION}"
    -backend-config="encrypt=${BACKEND_ENCRYPT}"
    -input=false
  )
  [[ -n "$BACKEND_DYNAMODB_TABLE" ]] && INIT_ARGS+=(-backend-config="dynamodb_table=${BACKEND_DYNAMODB_TABLE}")
  terraform init "${INIT_ARGS[@]}"
else
  # Terragrunt normalmente gerencia o backend via bloco remote_state no
  # terragrunt.hcl (com generate = "backend.tf"). As variáveis abaixo ficam
  # disponíveis para o HCL via get_env(), caso o repo esteja parametrizado assim.
  export TG_BACKEND_BUCKET="$BACKEND_BUCKET"
  export TG_BACKEND_KEY="$BACKEND_KEY"
  export TG_BACKEND_REGION="$BACKEND_REGION"
  export TG_BACKEND_DYNAMODB_TABLE="$BACKEND_DYNAMODB_TABLE"
  log "Executando terragrunt init..."
  terragrunt init -input=false --terragrunt-non-interactive
fi

# ---------------------------------------------------------------------
# 4) Montar comando final e executar a ação
# ---------------------------------------------------------------------
CMD=("$TOOL" "$ACTION" -input=false)
[[ -n "$TF_VAR_FILE" ]] && CMD+=(-var-file="$TF_VAR_FILE")
[[ "$TOOL" == "terragrunt" ]] && CMD+=(--terragrunt-non-interactive)

if [[ "$ACTION" != "plan" && "$AUTO_APPROVE" == "true" ]]; then
  CMD+=(-auto-approve)
fi

# shellcheck disable=SC2206
[[ -n "$EXTRA_ARGS" ]] && CMD+=($EXTRA_ARGS)

log "Executando: ${CMD[*]}"
exec "${CMD[@]}"
