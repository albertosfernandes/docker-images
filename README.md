# docker-images
Dockerfiles de containers de teste

### tf-runner
1. docker run -it --rm --name tf-runner-toolbox   -v "$(pwd)":/workspace   -v ~/.aws:/workspace/.aws:ro   -e AWS_PROFILE=default   -e AWS_REGION=us-east-1   tf-runner:1.2
2. git clone https://github.com/albertosfernandes/bancada.git /workspace/src
3. cd /workspace/src/IaC/terraform/
4. export TF_DATA_DIR=/tmp/.terraform
5. export TF_PLUGIN_CACHE_DIR=/tmp/plugin-cache
6. mkdir -p $TF_PLUGIN_CACHE_DIR
7. terraform init
8. terraform plan