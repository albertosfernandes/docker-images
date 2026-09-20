ARG TERRAFORM_VERSION=1.9.6
ARG TERRAGRUNT_VERSION=1.1.5
ARG AWSCLI_VERSION=2.17.62

# ============================================================
# Stage 1 - Terraform
# ============================================================
FROM hashicorp/terraform:${TERRAFORM_VERSION} AS terraform

# ============================================================
# Stage 2 - AWS CLI
# ============================================================
FROM public.ecr.aws/aws-cli/aws-cli:${AWSCLI_VERSION} AS awscli

# ============================================================
# Stage 3 - Final image
# ============================================================
FROM alpine:latest

  RUN apk add --no-cache \
  bash \
  curl \
  git \
  openssh-client \
  jq \
  ca-certificates 

  # Terraform
  COPY --from=terraform /bin/terraform /usr/local/bin/terraform

  # AWS CLI v2
  COPY --from=awscli /usr/local/aws-cli /usr/local/aws-cli
  COPY --from=awscli /usr/local/bin/aws /usr/local/bin/aws

  # Terragrunt
  RUN curl -sSL "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64" -o /usr/local/bin/terragrunt \
  && chmod +x /usr/local/bin/terragrunt

  # Non-root user
  ENV HOME=/workspace
  ENV PATH=$PATH:/usr/local/bin
  RUN addgroup -S -g 1000 runner \
    && adduser -S -D -H -u 1000 -G runner runner \
    && mkdir -p /workspace \
    && chown -R runner:runner /workspace
    
  COPY entrypoint.sh /usr/local/bin/entrypoint.sh
  RUN chmod +x /usr/local/bin/entrypoint.sh
    
  WORKDIR /workspace  
  USER runner

  ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
