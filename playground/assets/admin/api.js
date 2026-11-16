// Thin fetch client for /admin/api. Actor/tenant/authorize ride on every call.
const base = "/admin/api";

function qs(params) {
  const u = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v === undefined || v === null || v === "") continue;
    if (typeof v === "object") {
      for (const [k2, v2] of Object.entries(v)) {
        if (typeof v2 === "object") for (const [op, val] of Object.entries(v2)) u.append(`${k}[${k2}][${op}]`, val);
        else u.append(`${k}[${k2}]`, v2);
      }
    } else u.append(k, v);
  }
  return u.toString();
}

async function call(method, path, { query, body } = {}) {
  const res = await fetch(`${base}${path}${query ? `?${qs(query)}` : ""}`, {
    method,
    headers: body ? { "content-type": "application/json" } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw Object.assign(new Error(data.message || res.statusText), { data, status: res.status });
  return data;
}

const enc = encodeURIComponent;

export const api = {
  domains: () => call("GET", "/domains"),
  actors: () => call("GET", "/actors"),
  resource: (r) => call("GET", `/resources/${enc(r)}`),
  records: (r, query) => call("GET", `/resources/${enc(r)}/records`, { query }),
  record: (r, id, query) => call("GET", `/resources/${enc(r)}/records/${enc(id)}`, { query }),
  bulk: (r, body, ctx) => call("POST", `/resources/${enc(r)}/bulk`, { body: { ...ctx, ...body } }),
  // Same query params as `records`; the browser downloads the response (csv | json).
  exportUrl: (r, query) => `${base}/resources/${enc(r)}/export?${qs(query)}`,
  validate: (r, body, ctx) => call("POST", `/resources/${enc(r)}/validate`, { body: { ...ctx, ...body } }),
  submit: (r, body, ctx) => call("POST", `/resources/${enc(r)}/submit`, { body: { ...ctx, ...body } }),
  run: (r, body, ctx) => call("POST", `/resources/${enc(r)}/run`, { body: { ...ctx, ...body } }),
};
