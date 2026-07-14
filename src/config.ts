import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

/** MCP metadata declared in package.json (single source of truth). */
interface PackageJson {
  version: string;
  description: string;
  mcp: {
    name: string;
    title: string;
  };
}

const projectRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const pkg = JSON.parse(
  readFileSync(join(projectRoot, "package.json"), "utf8")
) as PackageJson;

/** Exposed to the MCP client via initialize → serverInfo. */
export const serverInfo = {
  name: pkg.mcp.name,
  version: pkg.version,
  title: pkg.mcp.title,
  description: pkg.description,
} as const;
