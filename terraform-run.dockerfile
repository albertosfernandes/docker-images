FROM debian:bookwork-slim

  ARG TERRAFORM_VERSION=1.9.6
  ARG TERRAGRUNT_VERSION=0.67.4
  ARG AWSCLI_VERSION=2.17.62

  ENV DEBIAN_FRONTEND=noninteractive

  RUN apt-get update && apt-get install -y --no-install-recommends \
  bash \
  curl \
  unzip \
  git \
  openssh-client \
  jq \
  ca-certificates \
  gnupg \
  && rm -rf /var/lib/apt/lists

  # AWS CLI v2
  RUN curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip" -o /tmp/awscliv2.zip \
  && unzip -q /tmp/awscliv2.zip -d /tmp \
  && /tmp/aws/install \
  && rm -rf /tmp/awscliv2.zip /tmp/aws

  # Terraform
  RUN curl -sSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}_linux_amd64.zip" -o /tmp/terraform.zip \
  && unzip -q /tmp/terraform.zip -d /usr/local/bin \
  && chmod +x /usr/local/bin/terraform \
  && rm -rf /tmp/terraform.zip

  # Terragrunt
  RUN curl -sSL "github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64" -o /usr/local/bin/terragrunt \
  && chmod +x /usr/local/bin/terragrunt

  # User no-root
  RUN useradd -m -u 1000 runner
  WORKDIR /workspace
  RUN chown -R runner:runner /workspace

  COPY entrypoint.sh /usr/local/bin/entrypoint.sh
  RUN chmod +x /usr/local/bin/entrypoint.sh

  USER runner

  ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
