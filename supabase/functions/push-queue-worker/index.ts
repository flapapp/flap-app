import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

Deno.serve(async () => {
  const { data: queueRows, error: fetchError } = await supabase
    .from("push_notification_queue")
    .select("id")
    .eq("status", "pending")
    .order("created_at", { ascending: true })
    .limit(200);

  if (fetchError) {
    return new Response(
      JSON.stringify({ ok: false, error: fetchError.message }),
      { status: 500 },
    );
  }

  if (!queueRows || queueRows.length === 0) {
    return new Response(JSON.stringify({ ok: true, processed: 0 }), {
      status: 200,
    });
  }

  const ids = queueRows.map((row) => row.id);
  const { error: updateError } = await supabase
    .from("push_notification_queue")
    .update({
      status: "cancelled",
      error_message: "Push transport disabled during Firebase removal",
      sent_at: new Date().toISOString(),
    })
    .in("id", ids);

  if (updateError) {
    return new Response(
      JSON.stringify({ ok: false, error: updateError.message }),
      { status: 500 },
    );
  }

  return new Response(JSON.stringify({ ok: true, processed: ids.length }), {
    status: 200,
  });
});
