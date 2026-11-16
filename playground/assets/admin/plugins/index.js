// Plugin registry. Each lane owns exactly one file here and exports
//   { id, pages: [{ path, label, icon?, Page }], tabs: [{ id, label, render(meta) }] }
// pages appear in the sidebar under "Tools" at /admin/<path>; tabs appear on every resource
// (return null from render to hide for a resource you do not apply to).
import realtime from "./realtime.jsx";
import auth from "./auth.jsx";
import ai from "./ai.jsx";
import ide from "./ide.jsx";
import workflow from "./workflow.jsx";
import jobs from "./jobs.jsx";
import history from "./history.jsx";
import jsonapi from "./jsonapi.jsx";
import surface from "./surface.jsx";

export const plugins = [realtime, auth, ai, ide, workflow, jobs, history, jsonapi, surface];
export const pluginPages = plugins.flatMap((p) => p.pages ?? []);
export const pluginTabs = plugins.flatMap((p) => p.tabs ?? []);
