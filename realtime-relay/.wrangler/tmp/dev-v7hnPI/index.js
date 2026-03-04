var __defProp = Object.defineProperty;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });

// .wrangler/tmp/bundle-WB4ncQ/strip-cf-connecting-ip-header.js
function stripCfConnectingIPHeader(input, init) {
  const request = new Request(input, init);
  request.headers.delete("CF-Connecting-IP");
  return request;
}
__name(stripCfConnectingIPHeader, "stripCfConnectingIPHeader");
globalThis.fetch = new Proxy(globalThis.fetch, {
  apply(target, thisArg, argArray) {
    return Reflect.apply(target, thisArg, [
      stripCfConnectingIPHeader.apply(null, argArray)
    ]);
  }
});

// src/auth.ts
function encodeUtf8(str) {
  return new TextEncoder().encode(str);
}
__name(encodeUtf8, "encodeUtf8");
function hexToBuffer(hex) {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
  }
  return bytes;
}
__name(hexToBuffer, "hexToBuffer");
function base64urlDecode(b64) {
  const padded = b64.replace(/-/g, "+").replace(/_/g, "/");
  const binary = atob(padded);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++)
    bytes[i] = binary.charCodeAt(i);
  return new TextDecoder().decode(bytes);
}
__name(base64urlDecode, "base64urlDecode");
async function hmacVerify(secret, data, signature) {
  const key = await crypto.subtle.importKey(
    "raw",
    encodeUtf8(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"]
  );
  const sigBytes = hexToBuffer(signature);
  return crypto.subtle.verify("HMAC", key, sigBytes, encodeUtf8(data));
}
__name(hmacVerify, "hmacVerify");
async function verifyToken(secret, token) {
  try {
    const parts = token.split(".");
    if (parts.length !== 2)
      return null;
    const [payloadB64, signature] = parts;
    const valid = await hmacVerify(secret, payloadB64, signature);
    if (!valid)
      return null;
    const payload = JSON.parse(base64urlDecode(payloadB64));
    const nowSec = Math.floor(Date.now() / 1e3);
    if (payload.exp && payload.exp < nowSec)
      return null;
    return payload;
  } catch {
    return null;
  }
}
__name(verifyToken, "verifyToken");

// src/bus-room.ts
var BusRoom = class {
  state;
  env;
  clients = /* @__PURE__ */ new Map();
  lastLocation = null;
  lastBroadcastTime = 0;
  pendingBroadcast = null;
  broadcastTimer = null;
  constructor(state, env) {
    this.state = state;
    this.env = env;
    this.state.getWebSockets().forEach((ws) => {
      const meta = ws.deserializeAttachment();
      if (meta) {
        this.clients.set(ws, meta);
      }
    });
  }
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === "/location") {
      return new Response(
        JSON.stringify(this.lastLocation || { error: "no_data" }),
        {
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": this.env.CORS_ORIGIN || "*"
          }
        }
      );
    }
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Expected WebSocket", { status: 426 });
    }
    const token = url.searchParams.get("token");
    if (!token) {
      return new Response("Missing token", { status: 401 });
    }
    const secret = this.env.RELAY_HMAC_SECRET;
    const payload = await verifyToken(secret, token);
    if (!payload) {
      return new Response("Invalid or expired token", { status: 401 });
    }
    const pathParts = url.pathname.split("/");
    const busIdFromUrl = pathParts[pathParts.length - 1] || "";
    if (payload.busId !== busIdFromUrl && busIdFromUrl !== "") {
      return new Response("Token busId mismatch", { status: 403 });
    }
    const pair = new WebSocketPair();
    const [client, server] = [pair[0], pair[1]];
    const clientInfo = {
      role: payload.role,
      userId: payload.sub,
      busId: payload.busId,
      collegeId: payload.collegeId
    };
    this.state.acceptWebSocket(server);
    server.serializeAttachment(clientInfo);
    this.clients.set(server, clientInfo);
    if (this.lastLocation) {
      server.send(
        JSON.stringify({
          type: "bus_location_update",
          ...this.lastLocation,
          serverTs: Date.now()
        })
      );
    }
    server.send(
      JSON.stringify({
        type: "connected",
        role: payload.role,
        busId: payload.busId,
        clientCount: this.clients.size
      })
    );
    return new Response(null, { status: 101, webSocket: client });
  }
  /**
   * Handle incoming WebSocket messages (Hibernation API).
   */
  async webSocketMessage(ws, message) {
    const info = this.clients.get(ws);
    if (!info) {
      ws.close(4001, "Unknown client");
      return;
    }
    try {
      const msgStr = typeof message === "string" ? message : new TextDecoder().decode(message);
      const data = JSON.parse(msgStr);
      switch (data.type) {
        case "driver_location":
          if (info.role !== "driver") {
            ws.send(JSON.stringify({ type: "error", message: "Only drivers can send location" }));
            return;
          }
          this.handleDriverLocation(data, info);
          break;
        case "ping":
          ws.send(JSON.stringify({ type: "pong", ts: Date.now() }));
          break;
        default:
          ws.send(JSON.stringify({ type: "error", message: `Unknown message type: ${data.type}` }));
      }
    } catch (err) {
      ws.send(JSON.stringify({ type: "error", message: "Invalid message format" }));
    }
  }
  /**
   * Handle WebSocket close (Hibernation API).
   */
  async webSocketClose(ws, code, reason, wasClean) {
    this.clients.delete(ws);
  }
  /**
   * Handle WebSocket error (Hibernation API).
   */
  async webSocketError(ws, error) {
    this.clients.delete(ws);
  }
  /**
   * Process a driver location update.
   * Stores the location and schedules a throttled broadcast.
   */
  handleDriverLocation(data, info) {
    let speedMps = Math.max(0, data.speedMps || 0);
    if (speedMps === 0 && data.speedMph) {
      speedMps = Math.max(0, data.speedMph) / 2.23694;
    }
    const speedMph = Math.round(speedMps * 2.23694);
    const location = {
      busId: info.busId,
      tripId: data.tripId,
      lat: data.lat,
      lng: data.lng,
      speedMps,
      speedMph,
      heading: data.heading || 0,
      accuracyM: data.accuracyM || 0,
      ts: data.ts || Date.now(),
      serverTs: Date.now()
    };
    this.lastLocation = location;
    const now = Date.now();
    const elapsed = now - this.lastBroadcastTime;
    if (elapsed >= 1e3) {
      this.broadcastToWatchers(location);
      this.lastBroadcastTime = now;
      this.pendingBroadcast = null;
    } else {
      this.pendingBroadcast = location;
      if (!this.broadcastTimer) {
        const delay = 1e3 - elapsed;
        this.broadcastTimer = setTimeout(() => {
          this.broadcastTimer = null;
          if (this.pendingBroadcast) {
            this.broadcastToWatchers(this.pendingBroadcast);
            this.lastBroadcastTime = Date.now();
            this.pendingBroadcast = null;
          }
        }, delay);
      }
    }
  }
  /**
   * Broadcast a location update to all connected watchers (admin + student).
   * Also sends to the driver for round-trip confirmation.
   */
  broadcastToWatchers(location) {
    const message = JSON.stringify({
      type: "bus_location_update",
      ...location
    });
    for (const [ws, info] of this.clients) {
      try {
        ws.send(message);
      } catch {
        this.clients.delete(ws);
      }
    }
  }
};
__name(BusRoom, "BusRoom");

// src/index.ts
var src_default = {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;
    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: corsHeaders()
      });
    }
    if (path === "/health") {
      return jsonResponse({ ok: true, ts: Date.now() });
    }
    const liveMatch = path.match(/^\/live\/bus\/([^/]+)$/);
    if (liveMatch) {
      const busId = liveMatch[1];
      const roomId = env.BUS_ROOM.idFromName(busId);
      const room = env.BUS_ROOM.get(roomId);
      const doUrl = new URL(request.url);
      doUrl.pathname = "/location";
      const resp = await room.fetch(doUrl.toString());
      const data = await resp.text();
      return new Response(data, {
        headers: {
          "Content-Type": "application/json",
          ...corsHeaders()
        }
      });
    }
    const wsMatch = path.match(/^\/ws\/bus\/([^/]+)$/);
    if (wsMatch) {
      const busId = wsMatch[1];
      if (request.headers.get("Upgrade") !== "websocket") {
        return jsonResponse({ error: "Expected WebSocket upgrade" }, 426);
      }
      const roomId = env.BUS_ROOM.idFromName(busId);
      const room = env.BUS_ROOM.get(roomId);
      return room.fetch(request);
    }
    if (path === "/geo/reverse") {
      const lat = url.searchParams.get("lat");
      const lon = url.searchParams.get("lon");
      if (!lat || !lon) {
        return jsonResponse({ error: "Missing lat/lon query params" }, 400);
      }
      try {
        const nominatimUrl = `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lon}&format=json&zoom=16`;
        const resp = await fetch(nominatimUrl, {
          headers: {
            "User-Agent": "Halo BusBusTracker/1.0 (live-bus-tracking)"
          }
        });
        const data = await resp.text();
        return new Response(data, {
          headers: {
            "Content-Type": "application/json",
            "Cache-Control": "public, max-age=3600",
            ...corsHeaders()
          }
        });
      } catch (err) {
        return jsonResponse({ error: "Geocoding failed" }, 502);
      }
    }
    return jsonResponse(
      {
        error: "Not found",
        routes: [
          "GET /health",
          "GET /live/bus/:busId",
          "GET /ws/bus/:busId?token=...",
          "GET /geo/reverse?lat=..&lon=.."
        ]
      },
      404
    );
  }
};
function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders()
    }
  });
}
__name(jsonResponse, "jsonResponse");
function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization"
  };
}
__name(corsHeaders, "corsHeaders");

// node_modules/wrangler/templates/middleware/middleware-ensure-req-body-drained.ts
var drainBody = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } finally {
    try {
      if (request.body !== null && !request.bodyUsed) {
        const reader = request.body.getReader();
        while (!(await reader.read()).done) {
        }
      }
    } catch (e) {
      console.error("Failed to drain the unused request body.", e);
    }
  }
}, "drainBody");
var middleware_ensure_req_body_drained_default = drainBody;

// node_modules/wrangler/templates/middleware/middleware-miniflare3-json-error.ts
function reduceError(e) {
  return {
    name: e?.name,
    message: e?.message ?? String(e),
    stack: e?.stack,
    cause: e?.cause === void 0 ? void 0 : reduceError(e.cause)
  };
}
__name(reduceError, "reduceError");
var jsonError = /* @__PURE__ */ __name(async (request, env, _ctx, middlewareCtx) => {
  try {
    return await middlewareCtx.next(request, env);
  } catch (e) {
    const error = reduceError(e);
    return Response.json(error, {
      status: 500,
      headers: { "MF-Experimental-Error-Stack": "true" }
    });
  }
}, "jsonError");
var middleware_miniflare3_json_error_default = jsonError;

// .wrangler/tmp/bundle-WB4ncQ/middleware-insertion-facade.js
var __INTERNAL_WRANGLER_MIDDLEWARE__ = [
  middleware_ensure_req_body_drained_default,
  middleware_miniflare3_json_error_default
];
var middleware_insertion_facade_default = src_default;

// node_modules/wrangler/templates/middleware/common.ts
var __facade_middleware__ = [];
function __facade_register__(...args) {
  __facade_middleware__.push(...args.flat());
}
__name(__facade_register__, "__facade_register__");
function __facade_invokeChain__(request, env, ctx, dispatch, middlewareChain) {
  const [head, ...tail] = middlewareChain;
  const middlewareCtx = {
    dispatch,
    next(newRequest, newEnv) {
      return __facade_invokeChain__(newRequest, newEnv, ctx, dispatch, tail);
    }
  };
  return head(request, env, ctx, middlewareCtx);
}
__name(__facade_invokeChain__, "__facade_invokeChain__");
function __facade_invoke__(request, env, ctx, dispatch, finalMiddleware) {
  return __facade_invokeChain__(request, env, ctx, dispatch, [
    ...__facade_middleware__,
    finalMiddleware
  ]);
}
__name(__facade_invoke__, "__facade_invoke__");

// .wrangler/tmp/bundle-WB4ncQ/middleware-loader.entry.ts
var __Facade_ScheduledController__ = class {
  constructor(scheduledTime, cron, noRetry) {
    this.scheduledTime = scheduledTime;
    this.cron = cron;
    this.#noRetry = noRetry;
  }
  #noRetry;
  noRetry() {
    if (!(this instanceof __Facade_ScheduledController__)) {
      throw new TypeError("Illegal invocation");
    }
    this.#noRetry();
  }
};
__name(__Facade_ScheduledController__, "__Facade_ScheduledController__");
function wrapExportedHandler(worker) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return worker;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  const fetchDispatcher = /* @__PURE__ */ __name(function(request, env, ctx) {
    if (worker.fetch === void 0) {
      throw new Error("Handler does not export a fetch() function.");
    }
    return worker.fetch(request, env, ctx);
  }, "fetchDispatcher");
  return {
    ...worker,
    fetch(request, env, ctx) {
      const dispatcher = /* @__PURE__ */ __name(function(type, init) {
        if (type === "scheduled" && worker.scheduled !== void 0) {
          const controller = new __Facade_ScheduledController__(
            Date.now(),
            init.cron ?? "",
            () => {
            }
          );
          return worker.scheduled(controller, env, ctx);
        }
      }, "dispatcher");
      return __facade_invoke__(request, env, ctx, dispatcher, fetchDispatcher);
    }
  };
}
__name(wrapExportedHandler, "wrapExportedHandler");
function wrapWorkerEntrypoint(klass) {
  if (__INTERNAL_WRANGLER_MIDDLEWARE__ === void 0 || __INTERNAL_WRANGLER_MIDDLEWARE__.length === 0) {
    return klass;
  }
  for (const middleware of __INTERNAL_WRANGLER_MIDDLEWARE__) {
    __facade_register__(middleware);
  }
  return class extends klass {
    #fetchDispatcher = (request, env, ctx) => {
      this.env = env;
      this.ctx = ctx;
      if (super.fetch === void 0) {
        throw new Error("Entrypoint class does not define a fetch() function.");
      }
      return super.fetch(request);
    };
    #dispatcher = (type, init) => {
      if (type === "scheduled" && super.scheduled !== void 0) {
        const controller = new __Facade_ScheduledController__(
          Date.now(),
          init.cron ?? "",
          () => {
          }
        );
        return super.scheduled(controller);
      }
    };
    fetch(request) {
      return __facade_invoke__(
        request,
        this.env,
        this.ctx,
        this.#dispatcher,
        this.#fetchDispatcher
      );
    }
  };
}
__name(wrapWorkerEntrypoint, "wrapWorkerEntrypoint");
var WRAPPED_ENTRY;
if (typeof middleware_insertion_facade_default === "object") {
  WRAPPED_ENTRY = wrapExportedHandler(middleware_insertion_facade_default);
} else if (typeof middleware_insertion_facade_default === "function") {
  WRAPPED_ENTRY = wrapWorkerEntrypoint(middleware_insertion_facade_default);
}
var middleware_loader_entry_default = WRAPPED_ENTRY;
export {
  BusRoom,
  __INTERNAL_WRANGLER_MIDDLEWARE__,
  middleware_loader_entry_default as default
};
//# sourceMappingURL=index.js.map
