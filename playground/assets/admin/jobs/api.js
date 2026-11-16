// Jobs lane API client (own file; the shared api.js is not edited).
const base = "/admin/api/jobs";
const enc = encodeURIComponent;

async function call(method, path, query) {
  const q = query ? new URLSearchParams(Object.entries(query).filter(([, v]) => v !== "" && v != null)).toString() : "";
  const res = await fetch(`${base}${path}${q ? `?${q}` : ""}`, { method, headers: { "content-type": "application/json" } });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.message || res.statusText);
  return data;
}

export const jobsApi = {
  triggers: () => call("GET", "/triggers"),
  jobs: (query) => call("GET", "", query),
  run: (resource, name, id) => call("POST", `/triggers/${enc(resource)}/${enc(name)}/run`, id ? { id } : undefined),
  cancel: (id) => call("POST", `/${id}/cancel`),
  retry: (id) => call("POST", `/${id}/retry`),
};
