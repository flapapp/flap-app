import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL") ?? "",
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);

Deno.serve(async () => {
  const { data, error } = await supabase.rpc("advance_challenge_statuses_rpc");
  if (error) {
    return new Response(JSON.stringify({ ok: false, error: error.message }), {
      status: 500,
    });
  }

  return new Response(
    JSON.stringify({
      ok: true,
      updated_rows: data ?? 0,
    }),
    { status: 200 },
  );
});
