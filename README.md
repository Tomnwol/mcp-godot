# mcp-hello-server (TypeScript)

Serveur MCP minimaliste, servant de squelette de validation avant intégration
avec un plugin Godot. Basé sur le SDK officiel
[`@modelcontextprotocol/sdk`](https://github.com/modelcontextprotocol/typescript-sdk).

Il expose un unique outil : `hello`, qui retourne `"Hello World"`.

## Pourquoi TypeScript ici ?

- SDK officiel maintenu par Anthropic, typé de bout en bout (schémas d'outils
  validés avec `zod`).
- Écosystème npm : facile d'ajouter ensuite un client WebSocket/TCP/HTTP pour
  parler à Godot sans changer d'écosystème.
- Compilation en JS standard (`build/`), donc exécutable partout où `node`
  est disponible — pas de venv à gérer côté client.

## 1. Installation

```bash
cd mcp-hello-server-ts
npm install
npm run build
```

Cela génère `build/server.js`, le fichier exécuté par les clients MCP.

## 2. Test en local (sans client)

Le SDK fournit un inspecteur web pour tester le serveur sans passer par
Claude Code ou Cursor :

```bash
npm run inspector
```

Cela lance le "MCP Inspector" dans le navigateur : l'outil `hello` doit
apparaître dans la liste, et on peut l'appeler manuellement pour vérifier
la réponse `"Hello World"`.

On peut aussi tester en pur JSON-RPC sur stdio, utile pour déboguer ou pour
de futurs tests automatisés :

```bash
node build/server.js
# puis coller des lignes JSON-RPC sur stdin, par ex. :
# {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"0.0.1"}}}
```

## 3. Intégration avec Claude Code

Un fichier `.mcp.json` est déjà présent à la racine du projet (config de
projet, chemin relatif — fonctionne tel quel une fois `npm run build`
exécuté) :

```json
{
  "mcpServers": {
    "hello-server": {
      "command": "node",
      "args": ["build/server.js"]
    }
  }
}
```

Depuis le dossier du projet :

```bash
claude
> /mcp
```

Le serveur `hello-server` doit apparaître comme connecté, avec l'outil
`hello` disponible. Il suffit ensuite de demander à Claude d'appeler l'outil
(« utilise l'outil hello du serveur MCP ») pour valider le cycle complet.

Alternative en config globale (utilisable depuis n'importe quel dossier) :

```bash
claude mcp add hello-server -- node /chemin/absolu/vers/mcp-hello-server-ts/build/server.js
```

## 4. Intégration avec Cursor

Dans Cursor : `Settings` → `Features` → `MCP` → `Add new MCP server`,
ou en éditant directement `~/.cursor/mcp.json` (global) ou
`.cursor/mcp.json` (projet) :

```json
{
  "mcpServers": {
    "hello-server": {
      "command": "node",
      "args": ["/chemin/absolu/vers/mcp-hello-server-ts/build/server.js"]
    }
  }
}
```

Redémarrer Cursor (ou recharger la fenêtre), puis vérifier dans les
paramètres MCP que le serveur est listé comme "connected" avec l'outil
`hello` visible.

> Remplacer `/chemin/absolu/vers/` par le chemin réel sur votre machine.

## 5. Étapes suivantes (extension vers Godot)

Une fois ce squelette validé de bout en bout (détection du serveur, outil
visible, appel fonctionnel), on peut étendre `src/server.ts` :

- Ajouter de nouveaux outils (`server.registerTool(...)`) qui, au lieu de
  retourner un texte statique, communiquent avec Godot via :
  - un serveur TCP/WebSocket exposé par un plugin GDScript côté Godot
    (le serveur MCP jouerait alors le rôle de client vers Godot, par ex.
    avec le module `ws` ou `net` de Node) ; ou
  - une petite API HTTP locale exposée par le jeu/l'éditeur Godot
    (le serveur MCP ferait de simples appels `fetch`) ; ou
  - un fichier ou pipe nommé partagé entre les deux processus.
- Définir un vrai `inputSchema` avec `zod` pour chaque nouvel outil
  (par ex. `{ nodePath: z.string(), value: z.number() }`), afin que le
  client (Claude Code, Cursor) sache quels arguments fournir.
- Ajouter une gestion d'erreurs propre (Godot non lancé, timeout de
  connexion, etc.), renvoyée comme résultat d'outil en erreur
  (`isError: true`) plutôt qu'une exception qui ferait planter le process.
- Repasser `npm run build` (ou `npm run watch` pendant le développement)
  après chaque modification.
