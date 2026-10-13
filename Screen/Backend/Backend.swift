import Foundation
import Supabase

enum BackendError: LocalizedError {
    case notConfigured, looseningRequiresApproval, server(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Falta configurar el servidor."
        case .looseningRequiresApproval: return "Este cambio necesita la aprobación de tu dupla."
        case .server(let m): return Self.spanish[m] ?? m
        }
    }

    static let spanish = [
        "invalid_code": "Ese código no existe o ya se usó.",
        "own_code": "Ese es tu propio código.",
        "already_paired": "Ya tenés una dupla en Screen.",
        "request_expired": "El pedido ya venció.",
        "not_pending": "Ese pedido ya tiene respuesta.",
        "too_many_groups": "Podés tener hasta 5 grupos.",
        "not_paired": "Todavía no tenés dupla en Screen.",
    ]
}

final class Backend {
    static let shared = Backend()
    let client: SupabaseClient?

    init() {
        let url = Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String ?? ""
        let key = Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String ?? ""
        if let u = URL(string: url), !url.isEmpty, !key.isEmpty {
            client = SupabaseClient(supabaseURL: u, supabaseKey: key)
        } else {
            client = nil
        }
    }

    private func c() throws -> SupabaseClient {
        guard let client else { throw BackendError.notConfigured }
        return client
    }

    /// Turns `raise exception 'code'` from the RPCs into typed errors.
    @discardableResult
    private func call<T>(_ work: () async throws -> T) async throws -> T {
        do { return try await work() } catch let e as PostgrestError {
            if e.message.contains("loosening_requires_approval") { throw BackendError.looseningRequiresApproval }
            throw BackendError.server(e.message)
        }
    }

    // MARK: Auth & profile

    func currentUserID() async -> UUID? { try? await client?.auth.session.user.id }

    func signUp(email: String, password: String, name: String) async throws {
        _ = try await c().auth.signUp(email: email, password: password)
        try await ensureProfile(name: name)
    }

    func signIn(email: String, password: String) async throws {
        _ = try await c().auth.signIn(email: email, password: password)
        let id = await currentUserID()
        if try await profiles().first(where: { $0.id == id }) == nil {
            try await ensureProfile(name: String(email.prefix { $0 != "@" }))
        }
    }

    func signOut() async { try? await client?.auth.signOut() }

    func ensureProfile(name: String) async throws {
        try await call { try await c().rpc("ensure_profile", params: ["p_name": name]).execute() }
    }

    func profiles() async throws -> [ProfileRow] {
        try await c().from("profiles").select().execute().value
    }

    // MARK: Pairing

    func myPair() async throws -> PairRow? {
        let rows: [PairRow] = try await c().from("pairs").select().execute().value
        return rows.first
    }

    func createInvite() async throws -> String {
        try await call { try await c().rpc("create_invite").execute().value }
    }

    func joinPair(code: String) async throws {
        try await call { try await c().rpc("join_pair", params: ["p_code": code]).execute() }
    }

    func leavePair() async throws {
        try await call { try await c().rpc("leave_pair").execute() }
    }

    func heartbeat(authStatus: String, apnsToken: String?) async throws -> UUID? {
        struct P: Encodable { let p_auth_status: String; let p_apns_token: String? }
        return try await call {
            try await c().rpc("heartbeat", params: P(p_auth_status: authStatus, p_apns_token: apnsToken)).execute().value
        }
    }

    // MARK: Groups

    @discardableResult
    func saveGroup(_ g: LimitGroup, removesApps: Bool) async throws -> String {
        struct P: Encodable {
            let p_id: UUID; let p_name: String; let p_app_count: Int
            let p_daily_minutes: Int?; let p_window_start: Int?; let p_window_end: Int?
            let p_removes_apps: Bool
        }
        let p = P(p_id: g.id, p_name: g.name, p_app_count: g.appCount, p_daily_minutes: g.dailyMinutes,
                  p_window_start: g.window?.startMinute, p_window_end: g.window?.endMinute, p_removes_apps: removesApps)
        return try await call { try await c().rpc("save_group", params: p).execute().value }
    }

    func deleteGroup(_ id: UUID) async throws {
        try await call { try await c().rpc("delete_group", params: ["p_id": id]).execute() }
    }

    func remoteGroups() async throws -> [GroupRow] {
        try await c().from("limit_groups").select().execute().value
    }

    // MARK: Requests & events

    func requestExtra(groupID: UUID, minutes: Int, message: String?) async throws -> UUID {
        struct P: Encodable { let p_group_id: UUID; let p_minutes: Int; let p_message: String? }
        return try await call {
            try await c().rpc("request_extra_time", params: P(p_group_id: groupID, p_minutes: minutes, p_message: message)).execute().value
        }
    }

    func requestLoosen(groupID: UUID, payload: LoosenPayload, message: String?) async throws -> UUID {
        struct P: Encodable { let p_group_id: UUID; let p_payload: LoosenPayload; let p_message: String? }
        return try await call {
            try await c().rpc("request_loosen", params: P(p_group_id: groupID, p_payload: payload, p_message: message)).execute().value
        }
    }

    func answer(requestID: UUID, grant: Bool, minutes: Int?) async throws {
        struct P: Encodable { let p_request_id: UUID; let p_grant: Bool; let p_minutes: Int? }
        try await call {
            try await c().rpc("answer_request", params: P(p_request_id: requestID, p_grant: grant, p_minutes: minutes)).execute()
        }
    }

    func markApplied(_ id: UUID) async throws {
        try await call { try await c().rpc("mark_applied", params: ["p_request_id": id]).execute() }
    }

    func cancelRequest(_ id: UUID) async throws {
        try await call { try await c().rpc("cancel_request", params: ["p_request_id": id]).execute() }
    }

    func logEvent(_ item: OutboxItem) async throws -> UUID? {
        struct P: Encodable { let p_kind: String; let p_group_id: UUID?; let p_client_id: String }
        return try await call {
            try await c().rpc("log_event", params: P(p_kind: item.kind, p_group_id: item.groupID, p_client_id: item.clientID)).execute().value
        }
    }

    func requests() async throws -> [RequestRow] {
        try await c().from("requests").select().order("created_at", ascending: false).limit(50).execute().value
    }

    func myUnappliedGrants() async throws -> [RequestRow] {
        guard let me = await currentUserID() else { return [] }
        return try await c().from("requests").select()
            .eq("from_user", value: me.uuidString)
            .eq("status", value: "granted")
            .filter("applied_at", operator: "is", value: "null")
            .execute().value
    }

    func events() async throws -> [EventRow] {
        try await c().from("events").select().order("created_at", ascending: false).limit(100).execute().value
    }

    /// Best effort: a missing push is recovered by the next foreground sync.
    func notify(requestID: UUID) async {
        try? await client?.functions.invoke("notify", options: FunctionInvokeOptions(body: ["request_id": requestID.uuidString]))
    }

    func notify(eventID: UUID) async {
        try? await client?.functions.invoke("notify", options: FunctionInvokeOptions(body: ["event_id": eventID.uuidString]))
    }
}
