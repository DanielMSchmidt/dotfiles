import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { basename, relative, sep } from "node:path";
import { pathInTerraformRoot, terraformRoot } from "./terraform";

const acceptanceTestPattern = /(?:^|\s)TF_ACC=1(?:\s|$)|(?:^|\s)go\s+test\b[^\n]*\binternal\/command\/e2etest\b/;

async function confirm(
	ctx: ExtensionContext,
	title: string,
	message: string,
	reason: string,
): Promise<{ block: true; reason: string } | undefined> {
	if (!ctx.hasUI) {
		return { block: true, reason };
	}

	if (await ctx.ui.confirm(title, message)) {
		return undefined;
	}
	return { block: true, reason };
}

export default function (pi: ExtensionAPI): void {
	pi.on("tool_call", async (event, ctx) => {
		const root = await terraformRoot(pi, ctx.cwd);
		if (!root) {
			return undefined;
		}

		if (event.toolName === "bash") {
			const command = event.input.command as string;
			if (!acceptanceTestPattern.test(command)) {
				return undefined;
			}
			return confirm(
				ctx,
				"Terraform acceptance test",
				"Run an acceptance or end-to-end test? These can be slow and require credentials.",
				"Terraform acceptance tests require explicit confirmation",
			);
		}

		if (event.toolName !== "edit" && event.toolName !== "write") {
			return undefined;
		}

		const path = event.input.path as string;
		const target = pathInTerraformRoot(root, ctx.cwd, path);
		if (!target) {
			return undefined;
		}

		const fileName = basename(target);
		if (fileName === "go.sum" || target.endsWith(".pb.go")) {
			const generator = fileName === "go.sum" ? "make syncdeps" : "make protobuf";
			if (ctx.hasUI) {
				ctx.ui.notify(`Blocked direct edit of generated file: ${path}`, "warning");
			}
			return {
				block: true,
				reason: `${path} is generated; use ${generator} instead`,
			};
		}

		const pathFromRoot = relative(root, target).split(sep);
		if (!pathFromRoot.includes("testdata")) {
			return undefined;
		}

		return confirm(
			ctx,
			"Terraform testdata change",
			"Edit a testdata fixture? Some Terraform fixtures are generated; verify this file is not generated first.",
			"Terraform testdata edit was not confirmed",
		);
	});
}
