ARG TERRAFORM_VERSION=1.9.6
ARG AWSCLI_VERSION=2.17.62

FROM hashicorp/terraform:${TERRAFORM_VERSION} AS terraform

FROM alpine:3.20

RUN apk add --no-cache \
      bash curl git openssh-client jq ca-certificates aws-cli

COPY --from=terraform /bin/terraform /usr/local/bin/terraform

ENV HOME=/workspace
RUN addgroup -S -g 1000 runner \
 && adduser -S -D -H -u 1000 -G runner runner \
 && mkdir -p /workspace \
 && chown -R runner:runner /workspace

WORKDIR /workspace
USER runner
CMD ["bash"]