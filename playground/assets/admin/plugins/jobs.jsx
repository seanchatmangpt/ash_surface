import React, { useState } from "react";
import { Briefcase } from "lucide-react";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "../../ui/tabs.jsx";
import { JobsTable, ResourceJobs, TriggersTable } from "../jobs/panels.jsx";
import { jobsApi } from "../jobs/api.js";

// Resources that declare AshOban triggers; filled client-side (never at import on the server).
const withTriggers = new Set();
if (typeof window !== "undefined") {
  jobsApi.triggers().then((d) => d.triggers.forEach((t) => withTriggers.add(t.resource))).catch(() => {});
}

function JobsPage() {
  const [key, setKey] = useState(0);
  return (
    <div className="grid gap-4">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Jobs</h1>
        <p className="text-sm text-muted-foreground">AshOban triggers, scheduled actions and Oban jobs.</p>
      </div>
      <Tabs defaultValue="triggers">
        <TabsList>
          <TabsTrigger value="triggers">Triggers</TabsTrigger>
          <TabsTrigger value="jobs">Jobs</TabsTrigger>
        </TabsList>
        <TabsContent value="triggers"><TriggersTable onRan={() => setKey((k) => k + 1)} /></TabsContent>
        <TabsContent value="jobs"><JobsTable refreshKey={key} /></TabsContent>
      </Tabs>
    </div>
  );
}

export default {
  id: "jobs",
  pages: [{ path: "jobs", label: "Jobs", icon: Briefcase, Page: JobsPage }],
  tabs: [
    {
      id: "jobs",
      label: "Jobs",
      render: (meta) => (withTriggers.has(meta.module) ? <ResourceJobs resource={meta.module} /> : null),
    },
  ],
};
