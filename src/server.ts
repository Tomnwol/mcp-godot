#!/usr/bin/env node
/**
 * Serveur MCP minimaliste — validation du protocole.
 *
 * Expose un unique outil factice `hello` qui retourne "Hello World".
 * Une fois ce squelette validé avec Claude Code / Cursor, on pourra
 * ajouter d'autres outils communiquant avec un plugin Godot (par ex.
 * via un socket TCP/WebSocket exposé par Godot, ou via une petite
 * API HTTP locale, selon l'architecture choisie).
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

// Instance du serveur : nom + version, tels qu'ils apparaîtront côté client
const server = new McpServer({
  name: "hello-server",
  version: "0.1.0",
});

// Outil factice de test : ne prend aucun paramètre, retourne un texte fixe
server.registerTool(
  "hello",
  {
    title: "Hello",
    description: "Outil factice de test : retourne un simple message de bienvenue.",
    inputSchema: {}, // pas de paramètre pour ce premier prototype
  },
  async () => {
    return {
      content: [{ type: "text", text: "Hello World" }],
    };
  }
);

async function main() {
  // Transport stdio : c'est ce que Claude Code / Cursor utilisent
  // pour lancer le serveur comme un sous-processus local.
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("hello-server (MCP) démarré sur stdio");
}

main().catch((error) => {
  console.error("Erreur fatale du serveur MCP :", error);
  process.exit(1);
});
