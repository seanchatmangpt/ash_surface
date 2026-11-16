import React from "react";
import { FileQuestion, ShieldAlert, TriangleAlert } from "lucide-react";
import { Button } from "../../ui/button.jsx";
import { Card, CardContent } from "../../ui/card.jsx";

const ICONS = { 404: FileQuestion, 403: ShieldAlert };

export function ErrorPage({ status = 500, title, message, onHome, action }) {
  const Icon = ICONS[status] ?? TriangleAlert;
  const heading = title ?? (status === 404 ? "Not found" : status === 403 ? "Forbidden" : "Something went wrong");
  return (
    <Card role="alert" className="mx-auto mt-12 max-w-lg">
      <CardContent className="grid justify-items-center gap-3 p-8 text-center">
        <Icon className="size-10 text-muted-foreground" />
        <div className="text-4xl font-semibold tracking-tight">{status}</div>
        <h1 className="text-lg font-medium">{heading}</h1>
        {message && <p className="text-sm text-muted-foreground">{message}</p>}
        <div className="flex gap-2">
          {action}
          {onHome && <Button variant="outline" onClick={onHome}>Back to admin</Button>}
        </div>
      </CardContent>
    </Card>
  );
}

// Maps an api.js error (status + body) onto an ErrorPage.
export function ApiErrorPage({ error, onHome }) {
  const status = error?.status ?? 500;
  return <ErrorPage status={status === 422 ? 500 : status} message={error?.message} onHome={onHome} />;
}

export class ErrorBoundary extends React.Component {
  state = { error: null };
  static getDerivedStateFromError(error) { return { error }; }
  componentDidUpdate(prev) {
    if (prev.resetKey !== this.props.resetKey && this.state.error) this.setState({ error: null });
  }
  render() {
    if (this.state.error) return <ErrorPage status={500} message={String(this.state.error.message ?? this.state.error)} onHome={this.props.onHome} />;
    return this.props.children;
  }
}
