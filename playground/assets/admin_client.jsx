import React from "react";
import { hydrateRoot } from "react-dom/client";
import { AdminApp } from "./component/admin_app.jsx";

const props = JSON.parse(document.getElementById("admin-props").textContent);
hydrateRoot(document.getElementById("root"), <AdminApp {...props} />);
window.__adminReady = true;
