// Lane `history`: AshPaperTrail timeline, AshStateMachine diagram, AshArchival restore.
// Applicability is derived synchronously from resource meta (tabs only receive `meta`):
//   History       -> public `paper_trail_versions` relationship (paper_trail relationship_opts public?: true)
//   State machine -> atom attribute whose constraints list states, plus update actions
//   Archived      -> a read action named `*archived*` (AshArchival exclude_read_actions) and a `restore` action
import React from "react";
import { HistoryTab } from "../history/history_tab.jsx";
import { StateMachineTab } from "../history/state_machine_tab.jsx";
import { ArchivedTab } from "../history/archived_tab.jsx";

export const hasHistory = (meta) => meta.relationships?.some((r) => r.name === "paper_trail_versions");
export const hasStateMachine = (meta) =>
  meta.attributes?.some((a) => a.name === "state" && a.kind === "atom" && a.constraints?.one_of?.length > 0) &&
  meta.actions?.some((a) => a.type === "update");
export const hasArchive = (meta) =>
  meta.actions?.some((a) => a.type === "read" && /archived/.test(a.name)) && meta.actions?.some((a) => a.name === "restore");

export default {
  id: "history",
  pages: [],
  tabs: [
    { id: "history", label: "History", render: (meta) => (hasHistory(meta) ? <HistoryTab meta={meta} /> : null) },
    { id: "state-machine", label: "State machine", render: (meta) => (hasStateMachine(meta) ? <StateMachineTab meta={meta} /> : null) },
    { id: "archived", label: "Archived", render: (meta) => (hasArchive(meta) ? <ArchivedTab meta={meta} /> : null) },
  ],
};
