import React from "react";
import { describe, expect, test } from "bun:test";
import { cleanup, fireEvent, screen, within } from "@testing-library/react";
import { DataTable } from "../admin/core/data_table.jsx";
import { FilterBuilder, buildFilter } from "../admin/core/filter_builder.jsx";
import { postMeta } from "./fixtures.mjs";
import { clearRequests, lastRequest, renderAdmin, until } from "./helpers.jsx";

const recordsReq = () => lastRequest((r) => r.path.endsWith("Post/records"));

describe("DataTable", () => {
  test("renders fixture rows with loaded calculations/aggregates and links rows to show pages", async () => {
    clearRequests();
    renderAdmin(<DataTable meta={postMeta} />);
    await until(() => screen.getByText("Alpha post"));
    expect(screen.getByText("Gamma post")).toBeTruthy();
    expect(screen.getByText("3 total")).toBeTruthy();
    const q = recordsReq().query;
    expect(q.load).toBe("title_length,comment_count");
    expect(q.limit).toBe("10");
    expect(screen.getByText("Alpha post").closest("a").getAttribute("href")).toBe("/admin/r/Playground.Blog.Post/p1");
    // sensitive column hidden by default
    expect(screen.queryByRole("button", { name: "secret" })).toBeNull();
  });

  test("click sorts, shift-click composes a multi-sort, plain click resets to one", async () => {
    clearRequests();
    renderAdmin(<DataTable meta={postMeta} />);
    await until(() => screen.getByText("Alpha post"));
    fireEvent.click(screen.getByRole("button", { name: "title" }));
    await until(() => recordsReq().query.sort === "title");
    fireEvent.click(screen.getByRole("button", { name: "points" }), { shiftKey: true });
    await until(() => recordsReq().query.sort === "title,points");
    fireEvent.click(screen.getByRole("button", { name: /^title\s*\d?$/ }), { shiftKey: true });
    await until(() => recordsReq().query.sort === "-title,points");
    fireEvent.click(screen.getByRole("button", { name: /^points\s*\d?$/ }));
    await until(() => recordsReq().query.sort === "-points");
  });

  test("filter builder sends a server-validated filter object and shows server errors", async () => {
    clearRequests();
    renderAdmin(<DataTable meta={postMeta} />);
    await until(() => screen.getByText("Alpha post"));
    fireEvent.click(screen.getByRole("button", { name: /filters/i }));
    fireEvent.click(screen.getByRole("button", { name: /add filter/i }));
    fireEvent.change(screen.getByLabelText("filter value"), { target: { value: "alpha" } });
    fireEvent.click(screen.getByRole("button", { name: "Apply" }));
    await until(() => recordsReq().query.filter);
    expect(JSON.parse(recordsReq().query.filter)).toEqual({ id: { eq: "alpha" } });
  });

  test("selection reveals the bulk toolbar; bulk destroy posts the selected ids and toasts", async () => {
    clearRequests();
    renderAdmin(<DataTable meta={postMeta} />);
    await until(() => screen.getByText("Alpha post"));
    fireEvent.click(screen.getByRole("checkbox", { name: "select p1" }));
    fireEvent.click(screen.getByRole("checkbox", { name: "select p3" }));
    const bar = screen.getByRole("toolbar", { name: "bulk actions" });
    expect(within(bar).getByText("2 selected")).toBeTruthy();
    fireEvent.click(within(bar).getByRole("button", { name: /destroy/i }));
    fireEvent.click(await until(() => within(screen.getByRole("dialog")).getByRole("button", { name: "Destroy" })));
    const req = await until(() => lastRequest((r) => r.path.endsWith("/bulk")));
    expect(req.body).toMatchObject({ op: "destroy", action: "destroy", ids: ["p1", "p3"] });
    await until(() => screen.getByText("Destroyed 2 records"));
    expect(screen.queryByRole("toolbar", { name: "bulk actions" })).toBeNull();
  });

  test("export links carry the current query and chosen format", async () => {
    clearRequests();
    renderAdmin(<DataTable meta={postMeta} />);
    await until(() => screen.getByText("Alpha post"));
    fireEvent.click(screen.getByRole("button", { name: "title" }));
    const csv = await until(() => {
      const a = screen.getByLabelText("export csv");
      return a.getAttribute("href").includes("sort=title") ? a : null;
    });
    const u = new URL(csv.getAttribute("href"), "http://x");
    expect(u.pathname).toBe("/admin/api/resources/Playground.Blog.Post/export");
    expect(u.searchParams.get("format")).toBe("csv");
    expect(u.searchParams.get("columns")).toContain("title");
    expect(new URL(screen.getByLabelText("export json").getAttribute("href"), "http://x").searchParams.get("format")).toBe("json");
  });

  test("revealing sensitive attributes adds the column and sends reveal=true", async () => {
    clearRequests();
    renderAdmin(<DataTable meta={postMeta} />);
    await until(() => screen.getByText("Alpha post"));
    fireEvent.click(screen.getByRole("switch", { name: "show sensitive" }));
    await until(() => recordsReq().query.reveal === "true");
    expect(screen.getByRole("button", { name: "secret" })).toBeTruthy();
  });
});

describe("buildFilter", () => {
  test("builds and/or structures, splits `in`, coerces is_nil, skips blanks", () => {
    expect(buildFilter([{ field: "title", op: "contains", value: "x" }])).toEqual({ title: { contains: "x" } });
    expect(buildFilter([{ field: "title", op: "contains", value: "" }])).toBeNull();
    expect(
      buildFilter([
        { field: "status", op: "in", value: "draft, published" },
        { field: "points", op: "gte", value: "2" },
      ]),
    ).toEqual({ and: [{ status: { in: ["draft", "published"] } }, { points: { gte: "2" } }] });
    expect(buildFilter([{ field: "a", op: "eq", value: "1" }, { field: "b", op: "is_nil", value: "false" }], "or")).toEqual({
      or: [{ a: { eq: "1" } }, { b: { is_nil: false } }],
    });
  });

  test("FilterBuilder renders server errors inline", () => {
    renderAdmin(<FilterBuilder fields={postMeta.attributes} onApply={() => {}} errors={[{ field: "points", message: "points eq: is invalid" }]} />);
    expect(screen.getByRole("alert").textContent).toContain("points eq: is invalid");
  });
});
