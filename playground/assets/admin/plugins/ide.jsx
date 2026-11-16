import React from "react";
import { Code2 } from "lucide-react";
import { Studio } from "../ide/studio.jsx";

// Lane `ide`: Ash Studio at /admin/studio.
export default {
  id: "ide",
  pages: [{ path: "studio", label: "Ash Studio", icon: Code2, Page: Studio }],
  tabs: [],
};
