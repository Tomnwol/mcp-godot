import { chmodSync } from "node:fs";

chmodSync("build/server.js", 0o755);
