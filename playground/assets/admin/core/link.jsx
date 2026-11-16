import React from "react";
import { useAdmin } from "../context.jsx";

export const recordPath = (module, id) => `/admin/r/${encodeURIComponent(module)}/${encodeURIComponent(id)}`;
export const resourcePath = (module) => `/admin/r/${encodeURIComponent(module)}`;

// SPA link: real href (SSR / open-in-new-tab) with client-side navigation on plain clicks.
export function Link({ to, children, className, ...rest }) {
  const { navigate } = useAdmin();
  return (
    <a
      href={to}
      className={className}
      onClick={(e) => {
        if (e.metaKey || e.ctrlKey || e.shiftKey || e.button > 0) return;
        e.preventDefault();
        navigate(to);
      }}
      {...rest}
    >
      {children}
    </a>
  );
}
