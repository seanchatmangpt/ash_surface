import React from "react";
import { describe, expect, test } from "bun:test";
import { cleanup, fireEvent, screen } from "@testing-library/react";
import { RecordForm } from "../admin/record_form.jsx";
import { postMeta } from "./fixtures.mjs";
import { clearRequests, lastRequest, renderAdmin, until } from "./helpers.jsx";

describe("RecordForm", () => {
  test("validates live against the server, shows its errors, and submits params", async () => {
    clearRequests();
    let done;
    renderAdmin(<RecordForm meta={postMeta} onCancel={() => {}} onDone={(r) => (done = r)} />);

    const title = screen.getByLabelText(/^title/);
    fireEvent.change(title, { target: { value: "ab" } });
    await until(() => screen.getByText("length must be greater than or equal to 3"));
    expect(lastRequest((r) => r.path.endsWith("/validate")).body.params.title).toBe("ab");

    fireEvent.change(title, { target: { value: "A fine title" } });
    await until(() => !screen.queryByText("length must be greater than or equal to 3"));

    fireEvent.click(screen.getByRole("button", { name: /add/i, hidden: true }));
    fireEvent.click(screen.getByRole("button", { name: "Create" }));
    const sub = await until(() => lastRequest((r) => r.path.endsWith("/submit")));
    expect(sub.body.action).toBe("create");
    expect(sub.body.params.title).toBe("A fine title");
    await until(() => done);
    expect(done.title).toBe("A fine title");
  });

  test("sensitive attributes absent from the record are not sent on update", async () => {
    clearRequests();
    let done;
    const rec = { id: "p1", title: "Alpha post" }; // `secret` omitted by the server
    renderAdmin(<RecordForm meta={postMeta} record={rec} onCancel={() => {}} onDone={(r) => (done = r)} />);
    fireEvent.click(screen.getByRole("button", { name: "Save" }));
    const sub = await until(() => lastRequest((r) => r.path.endsWith("/submit")));
    expect(sub.body.id).toBe("p1");
    expect("secret" in sub.body.params).toBe(false);
    await until(() => done);
  });

  test("manage_relationship arguments render nested forms and submit children", async () => {
    clearRequests();
    const meta = {
      ...postMeta,
      actions: postMeta.actions.map((a) =>
        a.name === "create"
          ? { ...a, arguments: [{ name: "comments", type: "array of Map", kind: "array:json", constraints: {}, allow_nil: true }],
              managed_relationships: [{ argument: "comments", relationship: "comments", cardinality: "many", destination: "Comment", destination_module: "Playground.Blog.Comment", type: "create" }] }
          : a,
      ),
    };
    let done;
    renderAdmin(<RecordForm meta={meta} onCancel={() => {}} onDone={(r) => (done = r)} />);
    const section = await until(() => screen.getByRole("group", { name: "comments" }));
    fireEvent.click(await until(() => screen.getByRole("button", { name: "Add comments" })));
    const body = await until(() => screen.getByLabelText(/^body/));
    expect(section.contains(body)).toBe(true);
    expect(screen.queryByLabelText(/^post_id/)).toBeNull();
    fireEvent.change(body, { target: { value: "first!" } });
    fireEvent.change(screen.getByLabelText(/^title/), { target: { value: "With kids" } });
    fireEvent.click(screen.getByRole("button", { name: "Create" }));
    const sub = await until(() => lastRequest((r) => r.path.endsWith("/submit")));
    expect(sub.body.params.comments).toEqual([{ body: "first!" }]);
    await until(() => done);
  });
});
