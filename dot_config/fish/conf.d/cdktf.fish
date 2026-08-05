# CHECKPOINT_DISABLE and CDKTF_EXPERIMENTAL_PROVIDER_SCHEMA_CACHE_PATH live in
# .chezmoidata/shell.yaml so bash and zsh get them too.

# helpers
alias cdktfl="$HOME/work/cdktf/terraform-cdk/packages/cdktf-cli/bundle/bin/cdktf"
alias jestd="node --inspect-brk ./node_modules/jest/bin/jest.js"

# TFC related
alias tfc_user_bigdane="cp ~/.terraform.d/credentials.tfrc.bigdane.json ~/.terraform.d/credentials.tfrc.json"
alias tfc_user_danielschmidt="cp ~/.terraform.d/credentials.tfrc.danielschmidt.json ~/.terraform.d/credentials.tfrc.json"
