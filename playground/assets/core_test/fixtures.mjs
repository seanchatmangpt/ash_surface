// Introspect-shaped metadata + records, and the fixture server's routing.
const attr = (name, kind, extra = {}) => ({ name, type: extra.type ?? kind, kind, constraints: {}, allow_nil: true, primary_key: false, writable: true, has_default: false, sensitive: false, ...extra });

export const postMeta = {
  name: "Post",
  module: "Playground.Blog.Post",
  primary_key: ["id"],
  attributes: [
    attr("id", "uuid", { primary_key: true, allow_nil: false }),
    attr("title", "string", { allow_nil: false }),
    attr("status", "atom", { constraints: { one_of: ["draft", "published"] } }),
    attr("points", "integer"),
    attr("tags", "array:string", { type: "array of String", items: { name: null, type: "String", kind: "string", constraints: {} } }),
    attr("secret", "string", { sensitive: true }),
    attr("address", "embedded", { fields: [attr("street", "string"), attr("zip", "string")] }),
    attr("payload", "union", { types: [{ name: "int", type: "Integer", kind: "integer", constraints: {} }, { name: "text", type: "String", kind: "string", constraints: {} }] }),
  ],
  relationships: [{ name: "comments", type: "has_many", cardinality: "many", destination: "Comment", destination_module: "Playground.Blog.Comment", source_attribute: "id", destination_attribute: "post_id" }],
  calculations: [{ name: "title_length", type: "Integer", kind: "integer", tag: "calculation", arguments: [] }],
  aggregates: [{ name: "comment_count", type: "Integer", kind: "integer", tag: "aggregate", arguments: [] }],
  actions: [
    { name: "read", type: "read", primary: true, accept: [], arguments: [], pagination: { offset: true, keyset: false, countable: true } },
    { name: "create", type: "create", primary: true, accept: ["title", "status", "points", "tags", "address", "payload"], arguments: [], managed_relationships: [] },
    { name: "update", type: "update", primary: true, accept: ["title"], arguments: [], managed_relationships: [] },
    { name: "publish", type: "update", primary: false, accept: [], arguments: [], managed_relationships: [] },
    { name: "destroy", type: "destroy", primary: true, accept: [], arguments: [], managed_relationships: [] },
  ],
};

export const commentMeta = {
  name: "Comment", module: "Playground.Blog.Comment", primary_key: ["id"],
  attributes: [attr("id", "uuid", { primary_key: true }), attr("body", "string"), attr("post_id", "uuid")],
  calculations: [], aggregates: [],
  actions: [
    { name: "read", type: "read", primary: true, accept: [], arguments: [], pagination: null },
    { name: "create", type: "create", primary: true, accept: ["body", "post_id"], arguments: [], managed_relationships: [] },
  ],
  // belongs_to back to Post: its foreign key is set by the parent, so nested forms hide it
  relationships: [{ name: "post", type: "belongs_to", cardinality: "one", destination: "Post", destination_module: "Playground.Blog.Post", source_attribute: "post_id", destination_attribute: "id" }],
};

export const posts = [
  { id: "p1", title: "Alpha post", status: "draft", points: 3, tags: ["x", "y"], address: { street: "1 Main", zip: "99999" }, payload: { type: "int", value: 7 }, title_length: 10, comment_count: 2 },
  { id: "p2", title: "Beta post", status: "published", points: 9, tags: [], address: null, payload: { type: "text", value: "hello" }, title_length: 9, comment_count: 0 },
  { id: "p3", title: "Gamma post", status: "draft", points: 1, tags: ["z"], address: null, payload: null, title_length: 10, comment_count: 1 },
];

export const fixtures = {
  route(method, url, body) {
    const p = url.pathname;
    if (p === "/admin/api/resources/Playground.Blog.Post" && method === "GET") return { body: postMeta };
    if (p === "/admin/api/resources/Playground.Blog.Comment" && method === "GET") return { body: commentMeta };
    if (p === "/admin/api/resources/Playground.Blog.Post/records") return { body: { records: posts, count: posts.length, limit: Number(url.searchParams.get("limit") ?? 25), offset: 0, pagination: "offset" } };
    if (p === "/admin/api/resources/Playground.Blog.Comment/records")
      return { body: { records: [{ id: "c1", body: "first!", post_id: "p1" }], count: 1, limit: 10, offset: 0 } };
    const one = p.match(/^\/admin\/api\/resources\/Playground\.Blog\.Post\/records\/(\w+)$/);
    if (one) {
      const rec = posts.find((x) => x.id === one[1]);
      return rec ? { body: { ...rec, secret: url.searchParams.get("reveal") === "true" ? "s3cret" : undefined } } : { status: 404, body: { error: "not_found", message: "record not found" } };
    }
    if (p === "/admin/api/resources/Playground.Blog.Post/validate") {
      const t = body?.params?.title ?? "";
      return { body: { valid: t.length >= 3, errors: t.length >= 3 ? [] : [{ field: "title", message: "length must be greater than or equal to 3" }] } };
    }
    if (p === "/admin/api/resources/Playground.Blog.Post/submit") return { body: { record: { id: "new", ...body.params }, errors: [] } };
    if (p === "/admin/api/resources/Playground.Blog.Post/bulk")
      return { body: { op: body.op, status: "success", affected: body.ids.length, requested: body.ids.length, errors: [] } };
    return { status: 404, body: { error: "not_found", message: `no fixture for ${method} ${p}` } };
  },
};
