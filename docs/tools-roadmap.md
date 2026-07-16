# Roadmap des outils MCP Godot

Principe : **~15–20 outils namespacés**, réponses compactes, search-first.
Voir aussi les anti-patterns en bas.

## État actuel (v0.2 — 16 outils)

| Outil | Rôle |
|-------|------|
| `godot_editor_ping` | Connectivité + version protocole |
| `godot_editor_get_state` | Scène ouverte, sélection, playing, écran |
| `godot_editor_run_project` | Lancer main/current scene |
| `godot_editor_stop_project` | Arrêter le play |
| `godot_scene_get_tree` | Hiérarchie shallow (outline, depth 2) |
| `godot_scene_search_nodes` | Recherche name/type (préféré vs tree) |
| `godot_scene_create_node` | Ajouter un nœud |
| `godot_scene_delete_node` | Supprimer un nœud |
| `godot_scene_instantiate` | Instancier un `.tscn` |
| `godot_scene_save` | Sauvegarder la scène |
| `godot_node_list_properties` | Découverte props (filtres + limit) |
| `godot_node_get_property` | Lire une valeur |
| `godot_node_set_property` | Écrire une valeur |
| `godot_script_get` | Lire un script (paginé) |
| `godot_script_set` | Écrire un script (full file) |
| `godot_log_get` | Tail logs (filtrable) |

### Contrats low-token (déjà en place)

- JSON compact (pas de pretty-print)
- Tree : `format=outline`, `max_depth=2`, `limit=80` par défaut
- Props : `detail=summary`, `relevant_only`, `limit=60`, `name_contains`
- Scripts / logs paginés
- Descriptions avec *when NOT to use* + annotations read/destructive

---

## Cible restante (P1–P2)

| Outil | Priorité | Notes |
|-------|----------|-------|
| `godot_scene_reparent_node` | P1 | |
| `godot_script_attach` | P1 | partiellement couvert via `set` + `attach_to` |
| `godot_editor_capture_viewport` | P1 | image tokens ≠ texte |
| `godot_scene_list_scenes` | P1 | ciblé, pas `list_project_files` |
| `godot_scene_open` | P2 | |
| Notes session (`res://.godot-mcp/NOTES.md`) | P2 | compaction hors contexte |

**Plafond recommandé : ~18–20 outils.** Au-delà, risque de confusion d’outil (LongFuncEval).

---

## Workflow IA recommandé

```
godot_editor_get_state
  → godot_scene_search_nodes (ou tree shallow)
  → godot_node_list_properties / get / set
  → godot_scene_create_node | instantiate | script_*
  → godot_scene_save
  → godot_editor_run_project → godot_log_get(level=error)
  → godot_editor_stop_project
```

---

## Grille de décision : nouvel outil ?

1. L’IA peut-elle déjà le faire avec les outils existants ?
2. Workflow fréquent pour un assistant de jeu ?
3. Réponse compacte (&lt; ~100 lignes JSON / outline) ?
4. Action sûre (undo / pas d’eval arbitraire) ?

Si 2 réponses « non » → ne pas ajouter.

---

## Anti-patterns

| Tentation | Problème |
|-----------|----------|
| `call_godot_method` générique | Imprévisible |
| `get_all_project_files` | Token bomb |
| Un outil par type de nœud | Explosion combinatoire |
| Dump scène illimité | Lost-in-the-middle |
| Pretty-print JSON | +30–50 % tokens gratuits |
| 50 micro-filtres = 50 outils | Un outil bien paramétré suffit |

## Références

- Protocole WebSocket : [`godot-plugin/README.md`](../godot-plugin/README.md)
- Outils : `src/tools/`
