// Lane `realtime`: live connection badge + recent-activity feed at /admin/activity.
import React from "react";
import { Badge } from "../../ui/badge.jsx";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../../ui/card.jsx";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "../../ui/table.jsx";
import { useAdmin } from "../context.jsx";
import { useRealtime } from "../realtime/hooks.js";

const variant = { connected: "default", connecting: "secondary", disconnected: "destructive", idle: "outline" };

export function ConnectionBadge({ status }) {
  return <Badge variant={variant[status] ?? "outline"}>{status}</Badge>;
}

function ActivityPage() {
  const admin = useAdmin();
  const { status, events } = useRealtime(admin?.actorId ?? "");
  return (
    <Card>
      <CardHeader>
        <CardTitle>
          Live activity <ConnectionBadge status={status} />
        </CardTitle>
        <CardDescription>Changes published by Ash.Notifier.PubSub, newest first.</CardDescription>
      </CardHeader>
      <CardContent>
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>Time</TableHead>
              <TableHead>Resource</TableHead>
              <TableHead>Action</TableHead>
              <TableHead>Record</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {events.length === 0 && (
              <TableRow>
                <TableCell colSpan={4}>No events yet.</TableCell>
              </TableRow>
            )}
            {events.map((e) => (
              <TableRow key={e.seq}>
                <TableCell>{e.at}</TableCell>
                <TableCell>{e.resource}</TableCell>
                <TableCell>
                  <Badge variant={e.type === "destroy" ? "destructive" : "secondary"}>{e.action}</Badge>
                </TableCell>
                <TableCell className="font-mono text-xs">{e.id}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </CardContent>
    </Card>
  );
}

export default { id: "realtime", pages: [{ path: "activity", label: "Activity", Page: ActivityPage }], tabs: [] };
