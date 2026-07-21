import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	type AutocompleteItem,
	type AutocompleteProvider,
	type AutocompleteSuggestions,
	fuzzyFilter,
} from "@earendil-works/pi-tui";
import { terraformRoot } from "./terraform";

type GitHubIssue = {
	number: number;
	title: string;
	state: string;
};

const MAX_ISSUES = 100;
const MAX_SUGGESTIONS = 20;

function issueToken(textBeforeCursor: string): string | undefined {
	return textBeforeCursor.match(/(?:^|[ \t])#([^\s#]*)$/)?.[1];
}

function issueItem(issue: GitHubIssue): AutocompleteItem {
	return {
		value: `#${issue.number}`,
		label: `#${issue.number}`,
		description: `[${issue.state.toLowerCase()}] ${issue.title}`,
	};
}

function matchingIssues(issues: GitHubIssue[], query: string): AutocompleteItem[] {
	if (!query) {
		return issues.slice(0, MAX_SUGGESTIONS).map(issueItem);
	}

	if (/^\d+$/.test(query)) {
		const matches = issues
			.filter((issue) => String(issue.number).startsWith(query))
			.slice(0, MAX_SUGGESTIONS)
			.map(issueItem);
		if (matches.length > 0) {
			return matches;
		}
	}

	return fuzzyFilter(issues, query, (issue) => `${issue.number} ${issue.title}`)
		.slice(0, MAX_SUGGESTIONS)
		.map(issueItem);
}

function issueAutocomplete(
	current: AutocompleteProvider,
	getIssues: () => Promise<GitHubIssue[] | undefined>,
): AutocompleteProvider {
	return {
		async getSuggestions(lines, cursorLine, cursorCol, options): Promise<AutocompleteSuggestions | null> {
			const token = issueToken((lines[cursorLine] ?? "").slice(0, cursorCol));
			if (token === undefined) {
				return current.getSuggestions(lines, cursorLine, cursorCol, options);
			}

			const issues = await getIssues();
			if (options.signal.aborted || !issues) {
				return current.getSuggestions(lines, cursorLine, cursorCol, options);
			}

			const matches = matchingIssues(issues, token);
			return matches.length > 0
				? { items: matches, prefix: `#${token}` }
				: current.getSuggestions(lines, cursorLine, cursorCol, options);
		},

		applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
			return current.applyCompletion(lines, cursorLine, cursorCol, item, prefix);
		},

		shouldTriggerFileCompletion(lines, cursorLine, cursorCol) {
			return current.shouldTriggerFileCompletion?.(lines, cursorLine, cursorCol) ?? true;
		},
	};
}

export default function (pi: ExtensionAPI): void {
	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui" || !(await terraformRoot(pi, ctx.cwd))) {
			return;
		}

		let issuesPromise: Promise<GitHubIssue[] | undefined> | undefined;
		const getIssues = (): Promise<GitHubIssue[] | undefined> => {
			issuesPromise ||= (async () => {
				const result = await pi.exec(
					"gh",
					[
						"issue",
						"list",
						"--repo",
						"hashicorp/terraform",
						"--state",
						"open",
						"--limit",
						String(MAX_ISSUES),
						"--json",
						"number,title,state",
					],
					{ cwd: ctx.cwd, timeout: 5_000 },
				);
				if (result.code !== 0) {
					const details = result.stderr.trim() || `exit code ${result.code}`;
					ctx.ui.notify(`Terraform issue autocomplete unavailable: ${details}`, "warning");
					return undefined;
				}

				try {
					return JSON.parse(result.stdout) as GitHubIssue[];
				} catch {
					ctx.ui.notify("Terraform issue autocomplete returned invalid JSON", "warning");
					return undefined;
				}
			})();
			return issuesPromise;
		};

		void getIssues();
		ctx.ui.addAutocompleteProvider((current) => issueAutocomplete(current, getIssues));
	});
}
