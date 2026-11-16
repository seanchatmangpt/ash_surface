import React from "react";
import { describe, expect, test } from "bun:test";
import { cleanup, fireEvent, screen } from "@testing-library/react";
import { RecordShow } from "../admin/core/record_show.jsx";
import { postMeta } from "./fixtures.mjs";
import { clearRequests, lastRequest, renderAdmin, requests, until } from "./helpers.jsx";

describe("RecordShow", () => {
  test("renders attributes, embedded and union values, aggregates; loads has_many lazily", async () => {
    clearRequests();
    renderAdmin(<RecordShow meta={postMeta} id="p1" />);
    await until(() => screen.getByTestId("attr-title"));
    expect(screen.getByTestId("attr-title").textContent).toBe("Alpha post");
    expect(screen.getByTestId("attr-address").textContent).toContain("1 Main");
    expect(screen.getByTestId("attr-payload").textContent).toContain("int");
    expect(screen.getByTestId("agg-comment_count").textContent).toBe("2");
    expect(screen.queryByText("secret")).toBeNull();

    // lazy: no comments request until the section opens
    expect(requests().some((r) => r.path.endsWith("Comment/records"))).toBe(false);
    fireEvent.click(screen.getByRole("button", { name: /comments/ }));
    await until(() => screen.getByText("first!"));
    const req = lastRequest((r) => r.path.endsWith("Comment/records"));
    expect(JSON.parse(req.query.filter)).toEqual({ post_id: { eq: "p1" } });
  });

  test("sensitive toggle refetches with reveal=true and shows the value", async () => {
    clearRequests();
    renderAdmin(<RecordShow meta={postMeta} id="p1" />);
    await until(() => screen.getByTestId("attr-title"));
    fireEvent.click(screen.getByRole("switch", { name: "show sensitive" }));
    await until(() => screen.getByTestId("attr-secret").textContent === "s3cret");
  });

  test("unknown record renders a 404 error page", async () => {
    renderAdmin(<RecordShow meta={postMeta} id="nope" />);
    await until(() => screen.getByRole("alert"));
    expect(screen.getByRole("alert").textContent).toContain("404");
  });
});
