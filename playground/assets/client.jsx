import React from "react";
import { hydrateRoot } from "react-dom/client";
import { Playground } from "./component/surface_playground.jsx";
import { loadSchemas, makeValidator } from "./validate.mjs";

const props = JSON.parse(document.getElementById("pg-props").textContent);
const root = document.getElementById("root");

// Hydrate first with SSR-identical props (no validator), then enable zod.
const app = hydrateRoot(root, <Playground {...props} />);
const mod = await loadSchemas(props.artifact, new URL("/assets/zod.mjs", location.href).href);
app.render(<Playground {...props} validate={makeValidator(mod)} />);
root.setAttribute("data-hydrated", "true");
window.__pgReady = true;
