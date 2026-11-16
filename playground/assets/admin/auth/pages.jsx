import React, { useEffect, useState } from "react";
import { Button } from "../../ui/button.jsx";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "../../ui/card.jsx";
import { Input } from "../../ui/input.jsx";
import { Label } from "../../ui/label.jsx";
import { Badge } from "../../ui/badge.jsx";

async function auth(method, path, body) {
  const res = await fetch(`/admin/api/auth${path}`, {
    method,
    credentials: "same-origin",
    headers: body ? { "content-type": "application/json" } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw Object.assign(new Error(data.message || res.statusText), { status: res.status });
  return data;
}

function useMe() {
  const [state, setState] = useState({ loading: true, user: null });
  useEffect(() => {
    let live = true;
    auth("GET", "/me")
      .then((d) => live && setState({ loading: false, user: d.user }))
      .catch(() => live && setState({ loading: false, user: null }));
    return () => { live = false; };
  }, []);
  return [state, setState];
}

export function Page() {
  const [mode, setMode] = useState("sign_in");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);
  const register = mode === "register";

  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await auth("POST", register ? "/register" : "/sign_in", { email, password });
      window.location.assign("/admin/account");
    } catch (err) {
      setError(err.status === 401 ? "Invalid email or password" : firstLine(err.message));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="mx-auto max-w-sm py-10">
      <Card>
        <form onSubmit={submit}>
          <CardHeader>
            <CardTitle>{register ? "Create account" : "Sign in"}</CardTitle>
            <CardDescription>{register ? "Register a new reader account." : "Use your admin credentials."}</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="auth-email">Email</Label>
              <Input id="auth-email" type="email" autoComplete="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="auth-password">Password</Label>
              <Input id="auth-password" type="password" autoComplete={register ? "new-password" : "current-password"} required minLength={register ? 8 : undefined} value={password} onChange={(e) => setPassword(e.target.value)} />
            </div>
            {error ? <p role="alert" className="text-sm text-destructive">{error}</p> : null}
          </CardContent>
          <CardFooter className="flex justify-between">
            <Button type="submit" disabled={busy}>{register ? "Register" : "Sign in"}</Button>
            <Button type="button" variant="ghost" onClick={() => { setMode(register ? "sign_in" : "register"); setError(null); }}>
              {register ? "Have an account? Sign in" : "Need an account? Register"}
            </Button>
          </CardFooter>
        </form>
      </Card>
    </div>
  );
}

export function AccountPage() {
  const [{ loading, user }, setState] = useMe();

  async function signOut() {
    await auth("DELETE", "/sign_out").catch(() => {});
    setState({ loading: false, user: null });
  }

  return (
    <div className="mx-auto max-w-sm py-10">
      <Card>
        <CardHeader>
          <CardTitle>Account</CardTitle>
          <CardDescription>Current session user</CardDescription>
        </CardHeader>
        <CardContent className="space-y-2">
          {loading ? <p className="text-sm text-muted-foreground">Loading...</p> : user ? (
            <>
              <p className="text-sm font-medium">{user.email}</p>
              <Badge>{user.role}</Badge>
            </>
          ) : (
            <p className="text-sm text-muted-foreground">
              Not signed in. <a className="underline" href="/admin/login">Go to login</a>
            </p>
          )}
        </CardContent>
        {user ? <CardFooter><Button variant="outline" onClick={signOut}>Sign out</Button></CardFooter> : null}
      </Card>
    </div>
  );
}

function firstLine(m) {
  const line = String(m || "Request failed").split("\n").map((s) => s.trim()).filter((s) => s && !s.startsWith("Bread") && !s.startsWith(">") && !s.endsWith("Error"))[0];
  return line?.replace(/^\*\s*/, "") ?? "Request failed";
}
