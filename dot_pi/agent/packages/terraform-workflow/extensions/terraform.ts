import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { access } from "node:fs/promises";
import { join, relative, resolve, sep } from "node:path";

const roots = new Map<string, string | undefined>();

export async function terraformRoot(pi: ExtensionAPI, cwd: string): Promise<string | undefined> {
	if (roots.has(cwd)) {
		return roots.get(cwd);
	}

	const result = await pi.exec("git", ["rev-parse", "--show-toplevel"], { cwd, timeout: 5_000 });
	if (result.code !== 0) {
		roots.set(cwd, undefined);
		return undefined;
	}

	const root = result.stdout.trim();
	try {
		await access(join(root, "internal", "terraform"));
		await access(join(root, "CLAUDE.md"));
	} catch {
		roots.set(cwd, undefined);
		return undefined;
	}

	roots.set(cwd, root);
	return root;
}

export function pathInTerraformRoot(root: string, cwd: string, path: string): string | undefined {
	const target = resolve(cwd, path.replace(/^@/, ""));
	const pathFromRoot = relative(root, target);
	if (pathFromRoot === ".." || pathFromRoot.startsWith(`..${sep}`)) {
		return undefined;
	}
	return target;
}
