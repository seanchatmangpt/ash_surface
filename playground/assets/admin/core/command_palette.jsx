import React, { useEffect, useState } from "react";
import { Database, Home, LayoutGrid, Moon, Sun } from "lucide-react";
import { CommandDialog, CommandEmpty, CommandGroup, CommandInput, CommandItem, CommandList } from "../../ui/command.jsx";
import { resourcePath } from "./link.jsx";

// Cmd/Ctrl-K palette: jump to any resource, plugin page, or toggle the theme.
// `pluginPages` is the stable plugins/index.js export ([{path, label}]).
export function CommandPalette({ domains, pluginPages = [], navigate, theme, setTheme, open: controlled, onOpenChange }) {
  const [inner, setInner] = useState(false);
  const open = controlled ?? inner;
  const setOpen = onOpenChange ?? setInner;

  useEffect(() => {
    const onKey = (e) => {
      if (e.key.toLowerCase() === "k" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        setOpen(!open);
      }
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [open, setOpen]);

  const go = (to) => { setOpen(false); navigate(to); };
  return (
    <CommandDialog open={open} onOpenChange={setOpen}>
      <CommandInput placeholder="Jump to a resource or page…" />
      <CommandList>
        <CommandEmpty>No results.</CommandEmpty>
        <CommandGroup heading="Navigate">
          <CommandItem value="home admin dashboard" onSelect={() => go("/admin")}><Home className="size-4" /> Home</CommandItem>
        </CommandGroup>
        {domains.map((d) => (
          <CommandGroup key={d.module} heading={d.name}>
            {d.resources.map((r) => (
              <CommandItem key={r.module} value={`${d.name} ${r.name} ${r.module}`} onSelect={() => go(resourcePath(r.module))}>
                <Database className="size-4" /> {r.name}
              </CommandItem>
            ))}
          </CommandGroup>
        ))}
        {pluginPages.length > 0 && (
          <CommandGroup heading="Tools">
            {pluginPages.map((p) => (
              <CommandItem key={p.path} value={`tool page ${p.label} ${p.path}`} onSelect={() => go(`/admin/${p.path}`)}>
                <LayoutGrid className="size-4" /> {p.label}
              </CommandItem>
            ))}
          </CommandGroup>
        )}
        <CommandGroup heading="Preferences">
          <CommandItem value="toggle theme dark light mode" onSelect={() => { setTheme(theme === "dark" ? "light" : "dark"); setOpen(false); }}>
            {theme === "dark" ? <Sun className="size-4" /> : <Moon className="size-4" />} Toggle dark mode
          </CommandItem>
        </CommandGroup>
      </CommandList>
    </CommandDialog>
  );
}
