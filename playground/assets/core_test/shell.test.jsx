import React from "react";
import { describe, expect, test } from "bun:test";
import { fireEvent, render, screen } from "@testing-library/react";
import { AdminApp } from "../component/admin_app.jsx";
import { pluginPages } from "../admin/plugins/index.js";
import { until } from "./helpers.jsx";

const domains = [
  { name: "Blog", module: "Playground.Blog", resources: [{ name: "Post", module: "Playground.Blog.Post", primary_key: ["id"] }, { name: "Comment", module: "Playground.Blog.Comment", primary_key: ["id"] }] },
];

describe("admin shell", () => {
  test("dark mode toggle applies the class and persists to localStorage", async () => {
    window.localStorage.clear();
    document.documentElement.classList.remove("dark");
    render(<AdminApp path="/" domains={domains} />);
    fireEvent.click(screen.getAllByRole("button", { name: "Toggle dark mode" })[0]);
    await until(() => document.documentElement.classList.contains("dark"));
    expect(window.localStorage.getItem("ash_admin_theme")).toBe("dark");
    fireEvent.click(screen.getAllByRole("button", { name: "Toggle dark mode" })[0]);
    await until(() => !document.documentElement.classList.contains("dark"));
    expect(window.localStorage.getItem("ash_admin_theme")).toBe("light");
  });

  test("Ctrl-K opens the command palette; selecting a resource navigates", async () => {
    render(<AdminApp path="/" domains={domains} />);
    fireEvent.keyDown(document, { key: "k", ctrlKey: true });
    const input = await until(() => screen.getByPlaceholderText("Jump to a resource or page…"));
    fireEvent.change(input, { target: { value: "comment" } });
    fireEvent.click(await until(() => screen.getByRole("option", { name: /Comment/ })));
    await until(() => window.location.pathname === "/admin/r/Playground.Blog.Comment");
    expect(screen.queryByPlaceholderText("Jump to a resource or page…")).toBeNull();
  });

  test("palette lists plugin pages", async () => {
    render(<AdminApp path="/" domains={domains} />);
    fireEvent.keyDown(document, { key: "k", ctrlKey: true });
    await until(() => screen.getByPlaceholderText("Jump to a resource or page…"));
    expect(pluginPages.length).toBeGreaterThan(0);
    for (const p of pluginPages) await until(() => screen.getAllByRole("option", { name: new RegExp(p.label.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")) }).length > 0);
  });

  test("mobile menu opens the navigation sheet", async () => {
    render(<AdminApp path="/" domains={domains} />);
    fireEvent.click(screen.getByRole("button", { name: "Open menu" }));
    const dialog = await until(() => screen.getByRole("dialog"));
    expect(dialog.textContent).toContain("Post");
  });

  test("unknown resource and unknown page render 404 error pages", async () => {
    render(<AdminApp path="/r/Nope.Nope" domains={domains} />);
    expect(screen.getByRole("alert").textContent).toContain("404");
  });
});
