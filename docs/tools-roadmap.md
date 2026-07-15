# Roadmap des outils MCP Godot

Ce document liste les outils qu’un MCP Godot **utile et maintenable** devrait
couvrir — sans viser l’intégralité de l’API Godot.

## Principe : ~20 outils, pas 200

Les bons MCP (Blender, browsers, etc.) restent souvent autour de **15–25
outils** même pour des logiciels très complexes. Pourquoi :

| Ce qui marche | Ce qui échoue |
|---------------|---------------|
| Outils **composés** (`list_node_properties` + `set_node_property`) | Un outil par propriété Godot |
| Couvrir les **workflows IA** (inspecter → modifier → tester) | Exposer chaque menu de l’éditeur |
| **Découverte** puis **action ciblée** | Dump complet du projet à chaque appel |
| Paramètres avec **filtres** (`relevant_only`) | Listes infinies sans filtre |

L’IA n’a pas besoin d’un équivalent de `Node3D.set_physics_process()` en MCP.
Elle a besoin de : *voir la scène, comprendre un nœud, changer ce qui compte,
lancer le jeu, lire les erreurs.*

---

## État actuel (5 outils)

| Outil | Rôle |
|-------|------|
| `ping_godot` | Connectivité + version protocole |
| `get_scene_tree` | Hiérarchie de la scène ouverte |
| `list_node_properties` | Découverte des propriétés (filtres IA) |
| `get_node_property` | Lecture d’une valeur |
| `set_node_property` | Écriture d’une valeur |

C’est la bonne base **inspect / modify** pour la scène courante.

---

## Cible recommandée : 18 outils

Répartition en 4 catégories. Chaque outil est noté :

- **Difficulté** : Facile / Moyen / Difficile
- **Valeur IA** : Haute / Moyenne / Faible — est-ce que ça débloque vraiment des tâches ?
- **Priorité** : P0 (essentiel) → P2 (nice-to-have)

### 1. Contexte éditeur (3 outils)

L’IA doit savoir *où* elle travaille avant d’agir.

| Outil | Description | Difficulté | Valeur | Priorité |
|-------|-------------|------------|--------|----------|
| `get_editor_state` | Scène ouverte, nœud(s) sélectionné(s), mode (2D/3D/script) | Facile | Haute | **P0** |
| `list_scenes` | Scènes principales / récentes (`res://*.tscn`, main scene) | Facile | Moyenne | P1 |
| `open_scene` | Ouvrir une scène dans l’éditeur | Moyen | Moyenne | P2 |

**Pourquoi pas plus ?** Un `list_project_files` générique est tentant mais
renvoie trop de bruit. Mieux vaut des listes ciblées (`list_scenes`,
`list_scripts`) si besoin.

---

### 2. Scène & nœuds (6 outils)

Compléter la lecture/écriture de propriétés par la **structure**.

| Outil | Description | Difficulté | Valeur | Priorité |
|-------|-------------|------------|--------|----------|
| `get_scene_tree` | ✅ Déjà fait | — | — | — |
| `list_node_properties` | ✅ Déjà fait | — | — | — |
| `get_node_property` | ✅ Déjà fait | — | — | — |
| `set_node_property` | ✅ Déjà fait | — | — | — |
| `create_node` | Ajouter un nœud enfant (type + nom + parent path) | Moyen | Haute | **P0** |
| `delete_node` | Supprimer un nœud par path | Moyen | Haute | **P0** |
| `reparent_node` | Déplacer un nœud dans l’arbre | Moyen | Moyenne | P1 |
| `instantiate_scene` | Instancier un `.tscn` packed sous un parent | Moyen | Haute | **P0** |

**Volontairement exclus :**

- `set_transform` — redondant avec `set_node_property` sur `position` / `rotation` / `scale`
- `duplicate_node` — P2, rarement bloquant
- `rename_node` — peut passer par `set_node_property` sur `name` (avec prudence)

---

### 3. Scripts (3 outils)

Indispensable pour l’IA qui code la logique de jeu.

| Outil | Description | Difficulté | Valeur | Priorité |
|-------|-------------|------------|--------|----------|
| `get_script` | Lire le `.gd` attaché à un nœud (ou par path) | Facile | Haute | **P0** |
| `set_script` | Écrire / remplacer un script (avec sauvegarde disque) | Moyen | Haute | **P0** |
| `attach_script` | Lier un script existant à un nœud | Facile | Moyenne | P1 |

**Volontairement exclus :**

- `run_gdscript` / `eval` — dangereux, difficile à sandboxer, faible confiance
- `create_shader` — niche ; un `set_script` + fichier suffit

---

### 4. Exécution & feedback (4 outils)

Boucle **modifier → tester → corriger**, critique pour l’IA.

| Outil | Description | Difficulté | Valeur | Priorité |
|-------|-------------|------------|--------|----------|
| `run_project` | Lancer F5 (jeu) | Facile | Haute | **P0** |
| `stop_project` | Arrêter l’exécution | Facile | Haute | **P0** |
| `get_output_log` | Dernières lignes console / erreurs Godot | Moyen | Haute | **P0** |
| `capture_viewport` | Screenshot du viewport éditeur ou jeu | Moyen | Moyenne | P1 |

**Volontairement exclus :**

- `run_scene` seul vs `run_project` — un seul outil avec param `mode` suffit
- `get_performance` — faible valeur pour la plupart des tâches IA
- `simulate_input` — difficile, P2 au mieux

---

### 5. Persistance (2 outils)

Sans ça, l’IA modifie en mémoire et l’utilisateur perd tout.

| Outil | Description | Difficulté | Valeur | Priorité |
|-------|-------------|------------|--------|----------|
| `save_scene` | Sauvegarder la scène ouverte | Facile | Haute | **P0** |
| `save_all` | Sauvegarder toutes les scènes/scripts modifiés | Facile | Moyenne | P1 |

---

## Synthèse : le « MCP parfait » minimal

```
Inspecter     ping_godot, get_editor_state, get_scene_tree,
              list_node_properties, get_node_property, get_script

Modifier      set_node_property, create_node, delete_node,
              instantiate_scene, set_script, save_scene

Tester        run_project, stop_project, get_output_log

Optionnel     capture_viewport, reparent_node, open_scene, attach_script
```

**Total P0 : ~14 outils** (dont 5 existants → **9 à implémenter**).  
**Total P0 + P1 : ~18 outils** — bon plafond, comparable à Blender MCP.

---

## Grille de décision : faut-il un nouvel outil ?

Avant d’ajouter un outil, se poser :

1. **L’IA peut-elle déjà le faire** avec les outils existants ?
   (ex. changer `text` → `set_node_property`, pas besoin de `set_label_text`)
2. **Est-ce un workflow fréquent** pour un assistant de dev de jeu ?
3. **La réponse est-elle compacte** (< ~100 lignes JSON) ?
4. **L’action est-elle sûre** (undo possible, pas d’exécution arbitraire) ?

Si 2 réponses « non » → ne pas ajouter.

---

## Comparatif Blender (complexité similaire)

Blender MCP typique (~15–20 outils) :

- Obtenir la scène / l’objet actif → `get_editor_state`, `get_scene_tree`
- CRUD objets → `create_node`, `delete_node`, `instantiate_scene`
- Propriétés → `list_node_properties`, `get/set_node_property`
- Matériaux / modifiers → équivalent Godot : `set_node_property` sur `material`, etc.
- Rendu screenshot → `capture_viewport`
- Exécuter opérateur → **éviter** l’équivalent `call_method` générique

Godot n’a pas besoin de plus d’outils que Blender — la structure scène + scripts +
run/stop couvre 90 % des demandes IA.

---

## Ordre d’implémentation suggéré

1. `get_editor_state` — contexte immédiat, facile
2. `save_scene` — sécuriser les modifications existantes
3. `create_node` / `delete_node` — structurer la scène
4. `get_script` / `set_script` — boucle code
5. `run_project` / `stop_project` / `get_output_log` — boucle test
6. `instantiate_scene` — prefabs / UI
7. P1 : `capture_viewport`, `reparent_node`, …

---

## Anti-patterns à éviter

| Tentation | Problème |
|-----------|----------|
| `call_godot_method(node, method, args)` | Trop générique, imprévisible, difficile à documenter |
| `get_all_project_files` | Token bomb, l’IA noie |
| Un outil par type de nœud | Explosion combinatoire (`create_button`, `create_sprite`, …) |
| 50 filtres sur `list_node_properties` | Un outil bien filtré vaut mieux que dix variantes |
| Dupliquer l’inspecteur Godot | L’IA n’a pas besoin de voir *toutes* les propriétés |

---

## Références internes

- Protocole WebSocket actuel : [`godot-plugin/README.md`](../godot-plugin/README.md)
- Outils implémentés : `src/tools/`
