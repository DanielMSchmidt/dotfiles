# Open Repo
alias repo="gh repo view --web"
# Open PR
alias pr="gh pr view --web"
# PR Copy URL
alias prc="gh pr view --json url | jq -r '.url' | pbcopy"
# Open all of my PRs
alias prs="gh pr list -A '@me' --web"
# Markdown list of all my PRs
alias prsmd="gh pr list --author=\"@me\" --json title,url,number --template '{{range .}}- [#{{.number}} {{.title}}]({{.url}}){{\"\n\"}}{{end}}'"

# Open the compare view for the current branch
alias compare="open https://github.com/(gh repo view --json='owner' --jq='.owner.login')/(gh repo view --json=name --jq='.name')/compare/(git rev-parse --abbrev-ref HEAD)"
# Create PR with PR template and open it in browser
function pr_create --wraps rm --description 'creates a PR with a template and opens it in the browser'
    gh pr create --web -b="$(cat ./.github/pull_request_template.md || git log main..HEAD -q)" $argv
end

alias "prs_all"="open 'https://github.com/search?q=is%3Aopen+author%3ADanielMSchmidt+org%3Ahashicorp&type=pullrequests&state=open'"

# Status overview of all my open PRs in the hashicorp org (or another org via
# `prstatus <org>`): review/feedback state, comment count, age and CI status.
function prstatus -d "List my open PRs in an org with review, comments, age and CI status"
    if not command -q gh
        echo "Error: gh CLI is not installed" >&2
        return 1
    end

    set -l org hashicorp
    if test (count $argv) -ge 1
        set org $argv[1]
    end

    set -l search "is:open is:pr author:@me org:$org archived:false"

    set -l query '
      query($q: String!) {
        search(query: $q, type: ISSUE, first: 100) {
          nodes {
            ... on PullRequest {
              number
              title
              url
              isDraft
              createdAt
              reviewDecision
              repository { nameWithOwner }
              comments { totalCount }
              reviews { totalCount }
              commits(last: 1) {
                nodes { commit { statusCheckRollup { state } } }
              }
            }
          }
        }
      }'

    # One TSV row per PR: repo, number, age, reviewDecision, feedbackCount, ciState, isDraft, title, url
    set -l rows (gh api graphql -f query=$query -f q=$search --jq '
      def age(t): (now - (t | fromdateiso8601)) as $s
        | if   $s < 3600  then "\(($s / 60)    | floor)m"
          elif $s < 86400 then "\(($s / 3600)  | floor)h"
          else                 "\(($s / 86400) | floor)d" end;
      .data.search.nodes
      | sort_by(.createdAt)
      | .[]
      | [ .repository.nameWithOwner,
          (.number | tostring),
          age(.createdAt),
          (.reviewDecision // "NONE"),
          ((.comments.totalCount + .reviews.totalCount) | tostring),
          (.commits.nodes[0].commit.statusCheckRollup.state // "NONE"),
          (.isDraft | tostring),
          .title,
          .url ]
      | @tsv')
    or return 1

    if test -z "$rows"
        echo "🎉 No open PRs for @me in $org"
        return 0
    end

    printf "\n%s%d open PR(s) in %s%s\n\n" (set_color --bold) (count $rows) $org (set_color normal)

    for row in $rows
        set -l f (string split \t -- $row)
        set -l repo $f[1]
        set -l num $f[2]
        set -l age $f[3]
        set -l review $f[4]
        set -l feedback $f[5]
        set -l ci $f[6]
        set -l draft $f[7]
        set -l title $f[8]
        set -l url $f[9]

        # CI rollup status
        set -l ci_label
        switch $ci
            case SUCCESS
                set ci_label (set_color green)"✓ CI"(set_color normal)
            case FAILURE ERROR
                set ci_label (set_color red)"✗ CI"(set_color normal)
            case PENDING EXPECTED
                set ci_label (set_color yellow)"● CI"(set_color normal)
            case '*'
                set ci_label (set_color brblack)"– CI"(set_color normal)
        end

        # Review decision
        set -l review_label
        switch $review
            case APPROVED
                set review_label (set_color green)"approved"(set_color normal)
            case CHANGES_REQUESTED
                set review_label (set_color red)"changes requested"(set_color normal)
            case REVIEW_REQUIRED
                set review_label (set_color yellow)"review needed"(set_color normal)
            case '*'
                set review_label (set_color brblack)"no review"(set_color normal)
        end

        # Comments / review feedback
        set -l feedback_label
        if test "$feedback" = 0
            set feedback_label (set_color brblack)"no feedback"(set_color normal)
        else
            set feedback_label "💬 $feedback"
        end

        # Truncate long titles so the list stays scannable
        set -l short_title $title
        if test (string length -- $title) -gt 72
            set short_title (string sub -l 70 -- $title)…
        end

        set -l draft_tag ""
        if test "$draft" = true
            set draft_tag (set_color brblack)" [draft]"(set_color normal)
        end

        printf "%s%s#%s%s%s · %s\n" (set_color --bold) $repo $num (set_color normal) $draft_tag $short_title
        printf "  %s   %s   %s   ⏱ %s   %s%s%s\n\n" $ci_label $review_label $feedback_label $age (set_color brblack) $url (set_color normal)
    end
end