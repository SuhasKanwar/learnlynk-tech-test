// LearnLynk Tech Test - Task 3: Edge Function create-task

// Deno + Supabase Edge Functions style
// Docs reference: https://supabase.com/docs/guides/functions

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

type CreateTaskPayload = {
  application_id: string;
  task_type: string;
  due_at: string;
};

const VALID_TYPES = ["call", "email", "review"];

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  try {
    const body = (await req.json()) as Partial<CreateTaskPayload>;
    const { application_id, task_type, due_at } = body;

    // Validate required fields
    if (!application_id || !task_type || !due_at) {
      return new Response(
        JSON.stringify({ 
          error: "Missing required fields: application_id, task_type, and due_at are required" 
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Validate task_type
    if (!VALID_TYPES.includes(task_type)) {
      return new Response(
        JSON.stringify({ 
          error: `Invalid task_type. Must be one of: ${VALID_TYPES.join(", ")}` 
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Validate and parse due_at
    const dueDate = new Date(due_at);
    if (isNaN(dueDate.getTime())) {
      return new Response(
        JSON.stringify({ error: "Invalid due_at format. Must be a valid ISO 8601 timestamp" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Ensure due_at is in the future
    const now = new Date();
    if (dueDate <= now) {
      return new Response(
        JSON.stringify({ error: "due_at must be in the future" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Verify application exists
    const { data: appData, error: appError } = await supabase
      .from("applications")
      .select("id, tenant_id")
      .eq("id", application_id)
      .single();

    if (appError || !appData) {
      return new Response(
        JSON.stringify({ error: "Application not found" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      );
    }

    // Insert task into tasks table
    const { data, error } = await supabase
      .from("tasks")
      .insert({
        application_id,
        type: task_type,
        due_at,
        tenant_id: appData.tenant_id,
        status: "open",
      })
      .select()
      .single();

    if (error) {
      console.error("Database error:", error);
      return new Response(
        JSON.stringify({ error: "Failed to create task", details: error.message }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // Emit Realtime broadcast event
    try {
      await supabase.channel("tasks").send({
        type: "broadcast",
        event: "task.created",
        payload: { task_id: data.id, application_id, task_type, due_at },
      });
    } catch (broadcastErr) {
      console.error("Broadcast error:", broadcastErr);
      // Continue even if broadcast fails
    }

    return new Response(
      JSON.stringify({ success: true, task_id: data.id }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error(err);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
