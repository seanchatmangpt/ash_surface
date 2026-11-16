import React, { createContext, useContext, useEffect, useState } from "react";

const Ctx = createContext(null);
export const useAdmin = () => useContext(Ctx);

const THEME_KEY = "ash_admin_theme";

// actor / tenant / authorize? mirror ash_admin's actor + tenant + policy toggles.
// theme is SSR-safe: render starts as "system"; localStorage is read and the `dark` class is
// applied only in effects.
export function AdminProvider({ children, navigate, path }) {
  const [actorId, setActorId] = useState("");
  const [tenant, setTenant] = useState("");
  const [authorize, setAuthorize] = useState(true);
  const [theme, setTheme] = useState("system");
  const [themeReady, setThemeReady] = useState(false);

  useEffect(() => {
    try {
      const saved = window.localStorage.getItem(THEME_KEY);
      if (saved === "light" || saved === "dark") setTheme(saved);
    } catch {}
    setThemeReady(true);
  }, []);

  useEffect(() => {
    if (!themeReady) return;
    const dark = theme === "dark" || (theme === "system" && window.matchMedia?.("(prefers-color-scheme: dark)").matches);
    document.documentElement.classList.toggle("dark", !!dark);
    try {
      if (theme === "system") window.localStorage.removeItem(THEME_KEY);
      else window.localStorage.setItem(THEME_KEY, theme);
    } catch {}
  }, [theme, themeReady]);

  const ctx = { actor_id: actorId, tenant, authorize: String(authorize) };
  return (
    <Ctx.Provider value={{ actorId, setActorId, tenant, setTenant, authorize, setAuthorize, ctx, navigate, path, theme, setTheme, themeReady }}>
      {children}
    </Ctx.Provider>
  );
}
