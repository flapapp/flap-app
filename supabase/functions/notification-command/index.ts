import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

function packMessageField(input: {
  message: string;
  data?: Record<string, unknown>;
  image_url?: string | null;
  action_url?: string | null;
}) {
  return JSON.stringify({
    v: 1,
    displayMessage: input.message,
    data: input.data ?? {},
    imageUrl: input.image_url ?? null,
    actionUrl: input.action_url ?? null,
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ ok: false, error: "Method not allowed" }), {
      status: 405,
    });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const authedClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const adminClient = createClient(url, serviceKey);

  const { data: authData, error: authError } = await authedClient.auth.getUser();
  const currentUser = authData.user;
  if (authError || !currentUser) {
    return new Response(JSON.stringify({ ok: false, error: "Unauthorized" }), {
      status: 401,
    });
  }

  const body = await req.json();
  const action = body.action as string | undefined;

  async function enqueueResolvedNotification(args: {
    userId: string;
    typeCode: string;
    title: string;
    message: string;
    data?: Record<string, unknown>;
    relatedTable?: string | null;
    relatedRecordId?: string | null;
    actionUrl?: string | null;
    imageUrl?: string | null;
    idempotencyKey: string;
  }) {
    const { data: lockRow, error: lockError } = await adminClient
      .from("notification_dispatch_log")
      .insert({
        idempotency_key: args.idempotencyKey,
        requested_by: currentUser.id,
        target_user_id: args.userId,
        type_code: args.typeCode,
        status: "processing",
      })
      .select("id")
      .maybeSingle();
    if (lockError) {
      if (lockError.code === "23505") return { ok: true, duplicate: true };
      return { ok: false, status: 500, error: lockError.message };
    }

    const { data: typeRow, error: typeError } = await adminClient
      .from("notification_types")
      .select("id")
      .eq("code", args.typeCode)
      .maybeSingle();
    if (typeError || !typeRow) {
      await adminClient.from("notification_dispatch_log").update({
        status: "failed",
        error_message: typeError?.message ?? "Unknown notification type",
      }).eq("id", lockRow!.id);
      return { ok: false, status: 400, error: "Unknown notification type" };
    }

    const packedMessage = packMessageField({
      message: args.message,
      data: args.data ?? {},
      image_url: args.imageUrl ?? null,
      action_url: args.actionUrl ?? null,
    });
    const { data: inserted, error: insertError } = await adminClient
      .from("notifications")
      .insert({
        user_id: args.userId,
        notification_type_id: typeRow.id,
        title: args.title,
        message: packedMessage,
        related_table: args.relatedTable ?? null,
        related_record_id: args.relatedRecordId ?? null,
        is_read: false,
      })
      .select("id")
      .single();
    if (insertError) {
      await adminClient.from("notification_dispatch_log").update({
        status: "failed",
        error_message: insertError.message,
      }).eq("id", lockRow!.id);
      return { ok: false, status: 500, error: insertError.message };
    }

    const { error: queueError } = await adminClient.from("push_notification_queue").insert({
      user_id: args.userId,
      notification_type_id: typeRow.id,
      title: args.title,
      message: args.message,
      related_table: args.relatedTable ?? null,
      related_record_id: args.relatedRecordId ?? null,
      status: "pending",
    });

    await adminClient.from("notification_dispatch_log").update({
      status: queueError ? "failed" : "created",
      error_message: queueError?.message ?? null,
      notification_id: inserted.id,
      processed_at: new Date().toISOString(),
    }).eq("id", lockRow!.id);

    if (queueError) return { ok: false, status: 500, error: queueError.message };
    return { ok: true, notificationId: inserted.id };
  }

  if (action === "register_push_token") {
    const token = (body.token as string | undefined)?.trim();
    const platform = body.platform as string | undefined;
    if (!token || (platform !== "android" && platform !== "ios")) {
      return new Response(JSON.stringify({ ok: false, error: "Invalid token payload" }), {
        status: 400,
      });
    }
    const { error } = await adminClient.from("push_tokens").upsert(
      {
        user_id: currentUser.id,
        token,
        platform,
        last_seen_at: new Date().toISOString(),
        revoked_at: null,
      },
      { onConflict: "token" },
    );
    if (error) {
      return new Response(JSON.stringify({ ok: false, error: error.message }), { status: 500 });
    }
    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  }

  if (action === "revoke_push_tokens") {
    const targetUserId = (body.user_id as string | undefined) ?? currentUser.id;
    if (targetUserId !== currentUser.id) {
      return new Response(JSON.stringify({ ok: false, error: "Forbidden" }), { status: 403 });
    }
    const { error } = await adminClient.from("push_tokens").update({
      revoked_at: new Date().toISOString(),
    }).eq("user_id", currentUser.id);
    if (error) {
      return new Response(JSON.stringify({ ok: false, error: error.message }), { status: 500 });
    }
    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  }

  if (action === "enqueue_notification") {
    const notification = body.notification as Record<string, unknown> | undefined;
    const idempotencyKey = (body.idempotency_key as string | undefined)?.trim();
    if (!notification || !idempotencyKey) {
      return new Response(JSON.stringify({ ok: false, error: "Missing notification payload" }), {
        status: 400,
      });
    }

    const userId = String(notification.user_id ?? "");
    const typeCode = String(notification.type_code ?? "");
    const title = String(notification.title ?? "");
    const message = String(notification.message ?? "");
    if (!userId || !typeCode || !title || !message) {
      return new Response(JSON.stringify({ ok: false, error: "Invalid notification payload" }), {
        status: 400,
      });
    }

    const result = await enqueueResolvedNotification({
      userId,
      typeCode,
      title,
      message,
      data: (notification.data as Record<string, unknown> | undefined) ?? {},
      relatedTable: (notification.related_table as string | undefined) ?? null,
      relatedRecordId: (notification.related_record_id as string | undefined) ?? null,
      actionUrl: (notification.action_url as string | undefined) ?? null,
      imageUrl: (notification.image_url as string | undefined) ?? null,
      idempotencyKey,
    });
    if (!result.ok) {
      return new Response(JSON.stringify({ ok: false, error: result.error }), { status: result.status });
    }
    return new Response(JSON.stringify({ ok: true, notification_id: result.notificationId }), { status: 200 });
  }

  if (action === "emit_domain_event") {
    const eventType = String(body.event_type ?? "");
    const payload = (body.payload as Record<string, unknown> | undefined) ?? {};
    const toUserId = String(payload.to_user_id ?? "");
    const idempotencyKey = String(body.idempotency_key ?? `${eventType}:${toUserId}:${Date.now()}`);
    let resolved:
      | { userId: string; typeCode: string; title: string; message: string; data: Record<string, unknown>; relatedTable?: string; relatedRecordId?: string; actionUrl?: string }
      | null = null;

    if (eventType === "friend_request_created") {
      resolved = {
        userId: toUserId,
        typeCode: "friend_request",
        title: "Friend request",
        message: `${String(payload.from_user_name ?? "A player")} sent you a friend request`,
        data: { type: "friend_request", requestId: payload.request_id ?? "" },
        actionUrl: "/friends",
      };
    } else if (eventType === "friend_request_accepted") {
      resolved = {
        userId: toUserId,
        typeCode: "friend_accepted",
        title: "Friend request accepted",
        message: `${String(payload.friend_name ?? "A friend")} accepted your friend request`,
        data: { type: "friend_accepted" },
        actionUrl: "/friends",
      };
    } else if (eventType === "challenge_invite_created") {
      const challengeId = String(payload.challenge_id ?? "");
      resolved = {
        userId: toUserId,
        typeCode: "challenge_invitation",
        title: "Challenge invite",
        message: `${String(payload.creator_name ?? "A player")} invited you to ${String(payload.challenge_title ?? "a challenge")}`,
        data: { type: "challenge_invitation", challengeId },
        relatedTable: "challenges",
        relatedRecordId: challengeId,
        actionUrl: `/challenge-details/${challengeId}`,
      };
    } else if (eventType === "match_invite_created") {
      const matchId = String(payload.match_id ?? "");
      resolved = {
        userId: toUserId,
        typeCode: "match_invite",
        title: String(payload.title_override ?? "Match invite"),
        message: String(payload.body_override ?? `${String(payload.organizer_name ?? "Organizer")} invited you to a match`),
        data: { type: "match_invite", matchId },
        relatedTable: "matches",
        relatedRecordId: matchId,
      };
    } else if (eventType === "match_finished") {
      const matchId = String(payload.match_id ?? "");
      const score = `${String(payload.team_a_name ?? "A")} ${String(payload.team_a_score ?? 0)}:${String(payload.team_b_score ?? 0)} ${String(payload.team_b_name ?? "B")}`;
      resolved = {
        userId: toUserId,
        typeCode: "match_finished",
        title: "Match finished",
        message: `Full time: ${score}. Please rate the players.`,
        data: { type: "match_finished", matchId },
        relatedTable: "matches",
        relatedRecordId: matchId,
        actionUrl: `/match/${matchId}/rate`,
      };
    } else if (eventType === "match_application_submitted") {
      const matchId = String(payload.match_id ?? "");
      resolved = {
        userId: toUserId,
        typeCode: "match_invite",
        title: "Match application",
        message: `${String(payload.applicant_name ?? "A player")} applied to join your match`,
        data: { type: "match_application_submitted", matchId },
        relatedTable: "matches",
        relatedRecordId: matchId,
      };
    } else if (eventType === "match_application_accepted") {
      const matchId = String(payload.match_id ?? "");
      resolved = {
        userId: toUserId,
        typeCode: "match_invite",
        title: "Application accepted",
        message: `${String(payload.organizer_name ?? "Organizer")} accepted your match application`,
        data: { type: "match_application_accepted", matchId },
        relatedTable: "matches",
        relatedRecordId: matchId,
      };
    } else if (eventType === "match_application_rejected") {
      const matchId = String(payload.match_id ?? "");
      resolved = {
        userId: toUserId,
        typeCode: "match_invite",
        title: "Application rejected",
        message: `${String(payload.organizer_name ?? "Organizer")} rejected your match application`,
        data: { type: "match_application_rejected", matchId },
        relatedTable: "matches",
        relatedRecordId: matchId,
      };
    } else if (eventType === "team_invite_created") {
      const teamId = String(payload.team_id ?? "");
      resolved = {
        userId: toUserId,
        typeCode: "team_invite",
        title: "Team invite",
        message: `You were invited to join "${String(payload.team_name ?? "a team")}"`,
        data: { type: "team_invite", teamId },
        relatedTable: "teams",
        relatedRecordId: teamId,
        actionUrl: "/profile",
      };
    } else if (eventType === "team_match_request_created") {
      const matchId = String(payload.match_id ?? "");
      resolved = {
        userId: toUserId,
        typeCode: "team_match_request",
        title: "Team match request",
        message: `Team "${String(payload.opponent_team_name ?? "opponent")}" requested a match`,
        data: { type: "team_match_request", matchId },
        relatedTable: "matches",
        relatedRecordId: matchId,
      };
    } else if (eventType === "team_join_request_created") {
      const teamId = String(payload.team_id ?? "");
      resolved = {
        userId: toUserId,
        typeCode: "team_join_request",
        title: "Team join request",
        message: `${String(payload.requester_name ?? "A player")} wants to join "${String(payload.team_name ?? "your team")}"`,
        data: { type: "team_join_request", teamId, requestId: payload.request_id ?? "" },
        relatedTable: "teams",
        relatedRecordId: teamId,
      };
    } else if (eventType === "team_roster_invite_created") {
      const matchId = String(payload.match_id ?? "");
      resolved = {
        userId: toUserId,
        typeCode: "team_roster_invite",
        title: "Roster invite",
        message: `You were invited to roster for "${String(payload.team_name ?? "team")}"`,
        data: { type: "team_roster_invite", matchId, teamKey: payload.team_key ?? "" },
        relatedTable: "matches",
        relatedRecordId: matchId,
      };
    } else if (eventType === "team_match_ready") {
      const matchId = String(payload.match_id ?? "");
      resolved = {
        userId: toUserId,
        typeCode: "team_match_ready",
        title: "Team match ready",
        message: `${String(payload.team_a_name ?? "Team A")} vs ${String(payload.team_b_name ?? "Team B")} is ready`,
        data: { type: "team_match_ready", matchId },
        relatedTable: "matches",
        relatedRecordId: matchId,
      };
    } else if (eventType === "challenge_submission_uploaded") {
      const challengeId = String(payload.challenge_id ?? "");
      resolved = {
        userId: toUserId,
        typeCode: "challenge_update",
        title: "Challenge update",
        message: `${String(payload.participant_name ?? "A player")} uploaded a video to "${String(payload.challenge_title ?? "challenge")}"`,
        data: { type: "challenge_update", challengeId },
        relatedTable: "challenges",
        relatedRecordId: challengeId,
      };
    } else if (eventType === "challenge_result_ready") {
      const challengeId = String(payload.challenge_id ?? "");
      resolved = {
        userId: toUserId,
        typeCode: "challenge_result",
        title: "Challenge result",
        message: `Result for "${String(payload.challenge_title ?? "challenge")}": place ${String(payload.position ?? "")}`,
        data: { type: "challenge_result", challengeId },
        relatedTable: "challenges",
        relatedRecordId: challengeId,
      };
    } else if (eventType === "challenge_completed") {
      const challengeId = String(payload.challenge_id ?? "");
      resolved = {
        userId: toUserId,
        typeCode: "challenge_completed",
        title: "Challenge completed",
        message: `"${String(payload.challenge_title ?? "Challenge")}" has completed`,
        data: { type: "challenge_completed", challengeId },
        relatedTable: "challenges",
        relatedRecordId: challengeId,
      };
    } else if (eventType === "challenge_voting_started") {
      const challengeId = String(payload.challenge_id ?? "");
      resolved = {
        userId: toUserId,
        typeCode: "challenge_update",
        title: "Challenge voting started",
        message: `Voting has started in "${String(payload.challenge_title ?? "challenge")}"`,
        data: { type: "challenge_update", challengeId, action: "vote" },
        relatedTable: "challenges",
        relatedRecordId: challengeId,
      };
    } else if (eventType === "video_vote_recorded") {
      resolved = {
        userId: toUserId,
        typeCode: "video_vote",
        title: "Video rated",
        message: `${String(payload.voter_name ?? "A user")} rated your video "${String(payload.video_title ?? "")}"`,
        data: { type: "video_vote" },
      };
    } else if (eventType === "rating_changed") {
      resolved = {
        userId: toUserId,
        typeCode: "rating_changed",
        title: "Rating updated",
        message: `Your rating changed to ${String(payload.new_rating ?? "")}`,
        data: { type: "rating_changed", delta: payload.delta ?? 0 },
      };
    } else if (eventType === "badge_earned") {
      resolved = {
        userId: toUserId,
        typeCode: "badge_earned",
        title: "Badge earned",
        message: `You earned "${String(payload.badge_emoji ?? "")} ${String(payload.badge_name ?? "badge")}"`,
        data: { type: "badge_earned", reason: payload.reason ?? "" },
        actionUrl: "/profile",
      };
    } else if (eventType === "coins_earned") {
      resolved = {
        userId: toUserId,
        typeCode: "coins_earned",
        title: "Coins earned",
        message: `You earned ${String(payload.amount ?? 0)} coins`,
        data: { type: "coins_earned", reason: payload.reason ?? "" },
        actionUrl: "/profile",
      };
    } else if (eventType === "rating_request_created") {
      const ids = (payload.to_user_ids as string[] | undefined) ?? [];
      const perUser = await Promise.all(ids.map((uid) => enqueueResolvedNotification({
        userId: uid,
        typeCode: "rating_request",
        title: "Rating request",
        message: `${String(payload.from_user_name ?? "A player")} asks you to rate their videos`,
        data: { type: "rating_request", videoIds: payload.video_ids ?? [] },
        idempotencyKey: `${idempotencyKey}:${uid}`,
      })));
      const failed = perUser.filter((r) => !r.ok);
      return new Response(JSON.stringify({ ok: failed.length === 0, failed: failed.length }), { status: failed.length === 0 ? 200 : 500 });
    } else if (eventType === "challenge_invite_bulk_created") {
      const ids = (payload.to_user_ids as string[] | undefined) ?? [];
      const challengeId = String(payload.challenge_id ?? "");
      const challengeTitle = String(payload.challenge_title ?? "a challenge");
      const creatorName = String(payload.creator_name ?? "A player");
      const perUser = await Promise.all(ids.map((uid) => enqueueResolvedNotification({
        userId: uid,
        typeCode: "challenge_invitation",
        title: "Challenge invite",
        message: `${creatorName} invited you to ${challengeTitle}`,
        data: { type: "challenge_invitation", challengeId },
        relatedTable: "challenges",
        relatedRecordId: challengeId,
        actionUrl: `/challenge-details/${challengeId}`,
        idempotencyKey: `${idempotencyKey}:${uid}`,
      })));
      const failed = perUser.filter((r) => !r.ok);
      return new Response(JSON.stringify({ ok: failed.length === 0, failed: failed.length }), { status: failed.length === 0 ? 200 : 500 });
    }

    if (!resolved) {
      return new Response(JSON.stringify({ ok: false, error: "Unsupported event_type" }), { status: 400 });
    }
    const result = await enqueueResolvedNotification({
      userId: resolved.userId,
      typeCode: resolved.typeCode,
      title: resolved.title,
      message: resolved.message,
      data: resolved.data,
      relatedTable: resolved.relatedTable,
      relatedRecordId: resolved.relatedRecordId,
      actionUrl: resolved.actionUrl,
      idempotencyKey,
    });
    if (!result.ok) {
      return new Response(JSON.stringify({ ok: false, error: result.error }), { status: result.status });
    }
    return new Response(JSON.stringify({ ok: true, notification_id: result.notificationId }), { status: 200 });
  }

  return new Response(JSON.stringify({ ok: false, error: "Unknown action" }), {
    status: 400,
  });
});
