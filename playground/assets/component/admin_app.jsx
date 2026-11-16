import React, { useEffect, useState } from "react";
import { Command as CommandIcon, Database, Menu, Moon, Shield, ShieldOff, Sun, UserRound } from "lucide-react";
import { AdminProvider, useAdmin } from "../admin/context.jsx";
import { ResourceView } from "../admin/resource_view.jsx";
import { api } from "../admin/api.js";
import { cn } from "../lib/utils.js";
import { pluginPages } from "../admin/plugins/index.js";
import { Input } from "../ui/input.jsx";
import { Button } from "../ui/button.jsx";
import { ToastProvider } from "../ui/toast.jsx";
import { Sheet, SheetContent, SheetDescription, SheetTitle } from "../ui/sheet.jsx";
import { CommandPalette } from "../admin/core/command_palette.jsx";
import { ErrorBoundary, ErrorPage } from "../admin/core/error_page.jsx";
import { Switch } from "../ui/switch.jsx";
import { Separator } from "../ui/separator.jsx";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "../ui/select.jsx";

// Shared by SSR (phoenix_react_server renderToString) and the browser hydrate.
export function AdminApp({ path: initialPath = "/", domains = [] }) {
  const [path, setPath] = useState(initialPath);
  const navigate = (to) => {
    if (typeof window !== "undefined") window.history.pushState({}, "", to);
    setPath(to.replace(/^\/admin/, "") || "/");
  };
  useEffect(() => {
    const on = () => setPath(window.location.pathname.replace(/^\/admin/, "") || "/");
    window.addEventListener("popstate", on);
    return () => window.removeEventListener("popstate", on);
  }, []);
  return (
    <AdminProvider navigate={navigate} path={path}>
      <ToastProvider>
        <Shell domains={domains} path={path} navigate={navigate} />
      </ToastProvider>
    </AdminProvider>
  );
}

function Shell({ domains, path, navigate }) {
  const { theme, setTheme, themeReady } = useAdmin();
  const parts = path.split("/").filter(Boolean);
  const [view, ...rest] = parts;
  const current = view === "r" ? decodeURIComponent(rest[0] ?? "") : null;
  const recordId = view === "r" && rest[1] ? decodeURIComponent(rest.slice(1).join("/")) : null;
  const page = pluginPages.find((p) => p.path === view);
  const known = current && domains.some((d) => d.resources.some((r) => r.module === current));
  const [menu, setMenu] = useState(false);
  const [palette, setPalette] = useState(false);
  const go = (to) => { setMenu(false); navigate(to); };
  const dark = themeReady && theme === "dark";

  return (
    <div className="flex min-h-screen flex-col md:flex-row">
      <header className="flex items-center justify-between gap-2 border-b bg-card px-4 py-2 md:hidden">
        <Button variant="ghost" size="icon" aria-label="Open menu" onClick={() => setMenu(true)}><Menu /></Button>
        <span className="flex items-center gap-2 font-semibold"><Database className="size-4" /> Ash Admin</span>
        <Button variant="ghost" size="icon" aria-label="Open command palette" onClick={() => setPalette(true)}><CommandIcon /></Button>
      </header>
      <aside className="hidden w-64 shrink-0 border-r bg-card p-4 md:block">
        <Sidebar domains={domains} current={current} page={page} navigate={go} palette={() => setPalette(true)} dark={dark} toggleTheme={() => setTheme(dark ? "light" : "dark")} />
      </aside>
      <Sheet open={menu} onOpenChange={setMenu}>
        <SheetContent>
          <SheetTitle className="sr-only">Navigation</SheetTitle>
          <SheetDescription className="sr-only">Resources and tools</SheetDescription>
          <Sidebar domains={domains} current={current} page={page} navigate={go} palette={() => { setMenu(false); setPalette(true); }} dark={dark} toggleTheme={() => setTheme(dark ? "light" : "dark")} />
        </SheetContent>
      </Sheet>
      <CommandPalette domains={domains} pluginPages={pluginPages} navigate={navigate} theme={theme} setTheme={setTheme} open={palette} onOpenChange={setPalette} />
      <main className="min-w-0 flex-1 p-4 md:p-6">
        <ErrorBoundary resetKey={path} onHome={() => navigate("/admin")}>
          {current ? (
            known || !domains.length ? (
              <ResourceView key={`${current}/${recordId ?? ""}`} resource={current} recordId={recordId} />
            ) : (
              <ErrorPage status={404} message={`No resource named ${current}`} onHome={() => navigate("/admin")} />
            )
          ) : page ? (
            <page.Page navigate={navigate} domains={domains} />
          ) : view ? (
            <ErrorPage status={404} message={`No page at /admin/${parts.join("/")}`} onHome={() => navigate("/admin")} />
          ) : (
            <Home domains={domains} navigate={navigate} />
          )}
        </ErrorBoundary>
      </main>
    </div>
  );
}

function Sidebar({ domains, current, page, navigate, palette, dark, toggleTheme }) {
  return (
    <>
      <div className="mb-4 flex items-center justify-between gap-2">
        <button type="button" className="flex items-center gap-2 text-lg font-semibold" onClick={() => navigate("/admin")}>
          <Database className="size-5" /> Ash Admin
        </button>
        <Button variant="ghost" size="icon" aria-label="Toggle dark mode" onClick={toggleTheme}>{dark ? <Sun /> : <Moon />}</Button>
      </div>
      <button type="button" onClick={palette} className="mb-4 flex w-full items-center justify-between rounded-md border px-3 py-1.5 text-sm text-muted-foreground hover:bg-accent">
        Jump to… <kbd className="rounded border px-1 text-xs">⌘K</kbd>
      </button>
      <Actor />
      <Separator className="my-4" />
      <nav className="grid gap-4 text-sm">
        {domains.map((d) => (
          <div key={d.module}>
            <div className="mb-1 px-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">{d.name}</div>
            {d.resources.map((r) => (
              <a
                key={r.module}
                href={`/admin/r/${encodeURIComponent(r.module)}`}
                onClick={(e) => { e.preventDefault(); navigate(`/admin/r/${encodeURIComponent(r.module)}`); }}
                className={cn("block rounded-md px-2 py-1.5 hover:bg-accent", current === r.module && "bg-accent font-medium")}
              >
                {r.name}
              </a>
            ))}
          </div>
        ))}
        {pluginPages.length > 0 && (
          <div>
            <div className="mb-1 px-2 text-xs font-semibold uppercase tracking-wide text-muted-foreground">Tools</div>
            {pluginPages.map((p) => (
              <a key={p.path} href={`/admin/${p.path}`}
                onClick={(e) => { e.preventDefault(); navigate(`/admin/${p.path}`); }}
                className={cn("block rounded-md px-2 py-1.5 hover:bg-accent", page?.path === p.path && "bg-accent font-medium")}>
                {p.label}
              </a>
            ))}
          </div>
        )}
      </nav>
    </>
  );
}

function Home({ domains, navigate }) {
  return (
    <div className="grid gap-4">
      <h1 className="text-2xl font-semibold tracking-tight">Domains</h1>
      <p className="text-sm text-muted-foreground">Select a resource to browse, create, edit and run actions.</p>
      {domains.map((d) => (
        <div key={d.module}>
          <h2 className="mb-2 font-medium">{d.name}</h2>
          <div className="flex flex-wrap gap-2">
            {d.resources.map((r) => (
              <button key={r.module} type="button" onClick={() => navigate(`/admin/r/${encodeURIComponent(r.module)}`)}
                className="rounded-lg border bg-card px-4 py-3 text-left text-sm hover:bg-accent">
                <div className="font-medium">{r.name}</div>
                <div className="text-xs text-muted-foreground">{r.module}</div>
              </button>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

function Actor() {
  const { actorId, setActorId, tenant, setTenant, authorize, setAuthorize } = useAdmin();
  const [actors, setActors] = useState([]);
  useEffect(() => { api.actors().then((d) => setActors(d.actors)).catch(() => {}); }, []);
  return (
    <div className="grid gap-3 text-sm">
      <div className="flex items-center gap-2 text-muted-foreground"><UserRound className="size-4" /> Actor</div>
      <Select value={actorId || "none"} onValueChange={(v) => setActorId(v === "none" ? "" : v)}>
        <SelectTrigger><SelectValue placeholder="No actor" /></SelectTrigger>
        <SelectContent>
          <SelectItem value="none">No actor</SelectItem>
          {actors.map((a) => <SelectItem key={a.id} value={a.id}>{a.name} ({a.role})</SelectItem>)}
        </SelectContent>
      </Select>
      <Input placeholder="Tenant" value={tenant} onChange={(e) => setTenant(e.target.value)} />
      <label className="flex items-center justify-between gap-2">
        <span className="flex items-center gap-2 text-muted-foreground">{authorize ? <Shield className="size-4" /> : <ShieldOff className="size-4" />} Authorize</span>
        <Switch checked={authorize} onCheckedChange={setAuthorize} />
      </label>
    </div>
  );
}

export const Component = (props) => <AdminApp {...props} />;
