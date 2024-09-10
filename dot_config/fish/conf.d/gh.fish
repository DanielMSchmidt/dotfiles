# Open Repo
alias repo="gh repo view --web"
# Open PR
alias pr="gh pr view --web"
# PR Copy URL
alias prc="gh pr view --json url | jq -r '.url' | pbcopy"
# Open all of my PRs
alias prs="gh pr list -A '@me' --web"
# Open the compare view for the current branch
alias compare="open https://github.com/(gh repo view --json='owner' --jq='.owner.login')/(gh repo view --json=name --jq='.name')/compare/(git rev-parse --abbrev-ref HEAD)"
# Create PR with PR template and open it in browser
function pr_create --wraps rm --description 'creates a PR with a template and opens it in the browser'
    gh pr create --web -b="$(cat ./.github/pull_request_template.md || git log main..HEAD -q)" $argv
end