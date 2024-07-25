# Don't track me
set -x CHECKPOINT_DISABLE true

# helpers
alias cdktfl="$HOME/work/cdktf/terraform-cdk/packages/cdktf-cli/bundle/bin/cdktf"
alias jestd="node --inspect-brk ./node_modules/jest/bin/jest.js"

# TFC related
alias tfc_user_bigdane="cp ~/.terraform.d/credentials.tfrc.bigdane.json ~/.terraform.d/credentials.tfrc.json"
alias tfc_user_danielschmidt="cp ~/.terraform.d/credentials.tfrc.danielschmidt.json ~/.terraform.d/credentials.tfrc.json"

# Caching layer

set -x CDKTF_EXPERIMENTAL_PROVIDER_SCHEMA_CACHE_PATH "$HOME/.cdktf/schema-cache"
