import Dispatch
import Foundation
import OSLog
import Synchronization
import XPC

enum HelperXPCError: Error, Equatable {
    case connectionFailed, requestFailed, invalidReply, timedOut
    case identityRequirement(Int32)
}

protocol HelperXPCConnecting {
    func send(_ command: String, reply: @escaping @Sendable (Result<Void, HelperXPCError>) -> Void)
    func cancel()
}

struct HelperXPCClient {
    var connect: () throws -> any HelperXPCConnecting = { try HelperXPCConnection() }

    func request(_ command: String, timeout: TimeInterval = 5) throws {
        let connection = try connect()
        defer { connection.cancel() }
        let completed = DispatchSemaphore(value: 0)
        let result = Mutex<Result<Void, HelperXPCError>?>(nil)
        // コアの同期ポートを保つため、応答はメインキューとは別のキューで受ける。
        connection.send(command) { reply in
            result.withLock { value in
                guard value == nil else { return }
                value = reply
                completed.signal()
            }
        }
        _ = completed.wait(timeout: .now() + timeout)
        try result.withLock { value in
            if value == nil {
                value = .failure(.timedOut)
            }
            try value?.get()
        }
    }
}

private struct HelperXPCConnection: HelperXPCConnecting {
    let connection: xpc_connection_t
    let queue = DispatchQueue(label: "Capsaicin.helper.reply")

    init() throws {
        let connection = xpc_connection_create_mach_service(
            HelperIdentity.serviceName, queue, UInt64(XPC_CONNECTION_MACH_SERVICE_PRIVILEGED),
        )
        self.connection = connection
        xpc_connection_set_event_handler(connection) { _ in }
        let error = xpc_connection_set_peer_team_identity_requirement(connection, HelperIdentity.signingIdentifier)
        if error != 0 {
            xpc_connection_cancel(connection)
            xpc_connection_activate(connection)
            throw HelperXPCError.identityRequirement(error)
        }
        xpc_connection_activate(connection)
    }

    func send(_ command: String, reply: @escaping @Sendable (Result<Void, HelperXPCError>) -> Void) {
        let request = xpc_dictionary_create_empty()
        xpc_dictionary_set_string(request, "command", command)
        xpc_connection_send_message_with_reply(connection, request, queue) { response in
            guard xpc_get_type(response) == XPC_TYPE_DICTIONARY else {
                let description = xpc_copy_description(response)
                defer { free(description) }
                Logger(subsystem: HelperIdentity.appIdentifier, category: "Helper")
                    .error("Helper XPC failed: \(String(cString: description), privacy: .private)")
                reply(.failure(.connectionFailed))
                return
            }
            guard xpc_dictionary_get_count(response) == 1,
                  let success = xpc_dictionary_get_value(response, "success"),
                  xpc_get_type(success) == XPC_TYPE_BOOL
            else {
                reply(.failure(.invalidReply))
                return
            }
            reply(xpc_bool_get_value(success) ? .success(()) : .failure(.requestFailed))
        }
    }

    func cancel() {
        xpc_connection_cancel(connection)
    }
}
