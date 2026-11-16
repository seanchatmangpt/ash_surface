const base = "/admin/api/workflows";

async function call(method, path, body) {
  const res = await fetch(`${base}${path}`, {
    method,
    headers: body ? { "content-type": "application/json" } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  // 422 carries a full run report (status "error"), so only 404/5xx are transport errors
  if (!res.ok && !data.status) throw Object.assign(new Error(data.message || res.statusText), { data, status: res.status });
  return data;
}

export const workflowApi = {
  list: () => call("GET", ""),
  graph: (name) => call("GET", `/${encodeURIComponent(name)}/graph`),
  run: (name, inputs, ctx) => call("POST", `/${encodeURIComponent(name)}/run`, { ...ctx, inputs }),
};
