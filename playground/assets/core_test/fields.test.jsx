import React, { useState } from "react";
import { describe, expect, test } from "bun:test";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { FieldControl, ValueView, encodeValue } from "../admin/fields.jsx";
import { postMeta } from "./fixtures.mjs";

const field = (n) => postMeta.attributes.find((a) => a.name === n);

// Controlled harness: renders FieldControl with state and exposes the latest value.
function Harness({ f, initial, onValue }) {
  const [v, setV] = useState(initial);
  return <FieldControl id="t" field={f} value={v} onChange={(x) => { setV(x); onValue(x); }} />;
}

describe("FieldControl", () => {
  test("string input reports typed text", () => {
    let got;
    render(<Harness f={field("title")} initial="" onValue={(v) => (got = v)} />);
    fireEvent.change(screen.getByRole("textbox"), { target: { value: "hello" } });
    expect(got).toBe("hello");
  });

  test("array control adds, edits and removes items", () => {
    let got;
    render(<Harness f={field("tags")} initial={["a"]} onValue={(v) => (got = v)} />);
    fireEvent.click(screen.getByRole("button", { name: /add/i }));
    const inputs = screen.getAllByRole("textbox");
    expect(inputs).toHaveLength(2);
    fireEvent.change(inputs[1], { target: { value: "b" } });
    expect(got).toEqual(["a", "b"]);
    fireEvent.click(screen.getByRole("button", { name: "remove item 1" }));
    expect(got).toEqual(["b"]);
  });

  test("embedded control renders nested fields and merges edits", () => {
    let got;
    render(<Harness f={field("address")} initial={{ street: "1 Main", zip: "999" }} onValue={(v) => (got = v)} />);
    const street = screen.getByDisplayValue("1 Main");
    fireEvent.change(street, { target: { value: "2 Side" } });
    expect(got).toEqual({ street: "2 Side", zip: "999" });
  });

  test("union control shows the control of the selected member type", () => {
    let got;
    render(<Harness f={field("payload")} initial={{ type: "int", value: "7" }} onValue={(v) => (got = v)} />);
    const num = screen.getByDisplayValue("7");
    expect(num.getAttribute("type")).toBe("number");
    fireEvent.change(num, { target: { value: "8" } });
    expect(got).toEqual({ type: "int", value: "8" });
  });

  test("json control flags invalid JSON and only emits parsed values", () => {
    let got;
    const f = { name: "meta", kind: "json", constraints: {} };
    render(<Harness f={f} initial={{ a: 1 }} onValue={(v) => (got = v)} />);
    const ta = screen.getByRole("textbox");
    fireEvent.change(ta, { target: { value: "{bad" } });
    expect(screen.getByText("Invalid JSON")).toBeTruthy();
    expect(got).toBeUndefined();
    fireEvent.change(ta, { target: { value: '{"b":2}' } });
    expect(got).toEqual({ b: 2 });
    expect(screen.queryByText("Invalid JSON")).toBeNull();
  });
});

describe("encodeValue", () => {
  test("union values become AshPhoenix _union_type params, recursing through arrays/embedded", () => {
    expect(encodeValue(field("payload"), { type: "int", value: "7" })).toEqual({ _union_type: "int", value: "7" });
    const arr = { kind: "array:union", items: field("payload") };
    expect(encodeValue(arr, [{ type: "text", value: "x" }])).toEqual([{ _union_type: "text", value: "x" }]);
    expect(encodeValue(field("address"), { street: "s" })).toEqual({ street: "s" });
    expect(encodeValue(field("title"), "plain")).toBe("plain");
  });
});

describe("ValueView", () => {
  test("renders union as a typed badge, embedded as a definition list, arrays as items", () => {
    const { container } = render(
      <div>
        <ValueView field={field("payload")} value={{ type: "int", value: 7 }} />
        <ValueView field={field("address")} value={{ street: "1 Main", zip: "99999" }} />
        <ValueView field={field("tags")} value={["x", "y"]} />
      </div>,
    );
    expect(screen.getByText("int")).toBeTruthy();
    expect(screen.getByText("7")).toBeTruthy();
    expect(container.querySelector("dl")?.textContent).toContain("1 Main");
    expect(screen.getByText("y")).toBeTruthy();
  });
});
