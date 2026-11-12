public abstract class Brain.HttpClient : BrainIa {
    protected string host;
    protected int port = 443;

    /**
    * Build the request of a conversation, specific to each provider.
    * @param system The system prompt, or null.
    * @param messages The user and assistant messages, oldest first.
    * @param endpoint The path to request on the host.
    * @param body The JSON body to send.
    * @return The headers of the request.
    * @throws Error If the payload cannot be serialized.
    */
    protected abstract string[] build_request(string? system, Message[] messages, out string endpoint, out string body) throws Error;

    /**
    * Parse the body answered by the API, specific to each provider.
    * @param raw The body of the response, headers stripped.
    * @return The response of the model.
    * @throws Error If the API answered an error or an unknown structure.
    */
    protected abstract Response parse_response(string raw) throws Error;

    public override Response? send(string prompt) throws Error {
        return send_messages(null, { new Message("user", prompt) });
    }

    public override async Response? send_async(string prompt, Cancellable? cancellable = null) throws Error {
        return yield send_messages_async(null, { new Message("user", prompt) }, cancellable);
    }

    public override Response? send_messages(string? system, Message[] messages) throws Error {
        string endpoint, body;
        var headers = build_request(system, messages, out endpoint, out body);
        var raw = send_request("POST", endpoint, headers, body);
        return parse_response(raw);
    }

    public override async Response? send_messages_async(string? system, Message[] messages, Cancellable? cancellable = null) throws Error {
        string endpoint, body;
        var headers = build_request(system, messages, out endpoint, out body);
        var raw = yield send_request_async("POST", endpoint, headers, body, cancellable);
        return parse_response(raw);
    }

    /**
    * Send an HTTPS request and return the body of the response.
    * @param method The HTTP method to use.
    * @param endpoint The path to request on the host.
    * @param headers The headers to append to the request.
    * @param body The body to send.
    * @return The decoded body of the response, headers stripped.
    * @throws Error If the connection fails or the server answers an error without a JSON body.
    */
    protected string send_request(string method, string endpoint, string[] headers, string body) throws Error {
        var client = new SocketClient() { tls = true };
        var conn = client.connect_to_host(this.host, (uint16)this.port);

        conn.output_stream.write_all(build_http_request(method, endpoint, headers, body).data, null);

        var input = conn.input_stream;
        var response = new StringBuilder();
        uint8 buffer[4096];
        ssize_t bytes;

        try {
            while ((bytes = input.read(buffer)) > 0) {
                response.append_len((string)buffer, (long)bytes);
            }
        }
        catch (Error e) {
            // the server may close the TLS connection abruptly once everything is sent
        }

        return parse_http_response(response);
    }

    /**
    * Non-blocking version of send_request(): connection, write and read are
    * asynchronous, and cancellable aborts the request at any moment.
    * @param method The HTTP method to use.
    * @param endpoint The path to request on the host.
    * @param headers The headers to append to the request.
    * @param body The body to send.
    * @param cancellable Abort the request; it then throws IOError.CANCELLED.
    * @return The decoded body of the response, headers stripped.
    * @throws Error If the connection fails, the request is cancelled or the server answers an error without a JSON body.
    */
    protected async string send_request_async(string method, string endpoint, string[] headers, string body, Cancellable? cancellable = null) throws Error {
        var client = new SocketClient() { tls = true };
        var conn = yield client.connect_to_host_async(this.host, (uint16)this.port, cancellable);

        size_t written;
        yield conn.output_stream.write_all_async(build_http_request(method, endpoint, headers, body).data,
            Priority.DEFAULT, cancellable, out written);

        var input = conn.input_stream;
        var response = new StringBuilder();
        var buffer = new uint8[4096];
        ssize_t bytes;

        try {
            while ((bytes = yield input.read_async(buffer, Priority.DEFAULT, cancellable)) > 0) {
                response.append_len((string)buffer, (long)bytes);
            }
        }
        catch (Error e) {
            if (e is IOError.CANCELLED)
                throw e;
            // the server may close the TLS connection abruptly once everything is sent
        }

        return parse_http_response(response);
    }

    /**
    * Build the raw HTTP/1.1 request.
    */
    private string build_http_request(string method, string endpoint, string[] headers, string body) {
        var request = new StringBuilder();
        request.append("%s %s HTTP/1.1\r\n".printf(method, endpoint));
        request.append("Host: %s\r\n".printf(this.host));
        foreach (var header in headers) {
            request.append(header + "\r\n");
        }
        request.append("Content-Length: %d\r\n".printf(body.length));
        request.append("Connection: close\r\n\r\n");
        request.append(body);
        return request.str;
    }

    /**
    * Split the raw response, check its status and return its decoded body.
    * @param response The raw response, headers included.
    * @return The decoded body.
    * @throws Error If the response is incomplete or an error without a JSON body.
    */
    private string parse_http_response(StringBuilder response) throws Error {
        int sep = response.str.index_of("\r\n\r\n");
        if (sep == -1)
            throw new ResponseError.ApiError("Incomplete HTTP response from %s", this.host);

        string head = response.str.substring(0, sep);
        string content = response.str.substring(sep + 4);

        if ("transfer-encoding: chunked" in head.down())
            content = decode_chunked(content);

        int status = parse_status(head);

        if (status == 429)
            throw new ResponseError.ApiError("HTTP 429: rate limit or quota reached on %s (wait a moment, switch model, or check your plan)", this.host);

        if (status >= 400 && ("{" in content) == false)
            throw new ResponseError.ApiError("HTTP %d: %s", status, content._strip());

        return content;
    }

    /**
    * Read the status code out of the response head.
    * @param head The header block of the response.
    * @return The HTTP status code, or 0 if the status line is unreadable.
    */
    private static int parse_status (string head) {
        var status_line = head.split("\r\n")[0].split(" ");
        return status_line.length > 1 ? int.parse(status_line[1]) : 0;
    }

    /**
    * Reassemble a body sent with Transfer-Encoding: chunked.
    * @param content The raw body, chunk sizes included.
    * @return The concatenated chunks.
    */
    private static string decode_chunked (string content) {
        var decoded = new StringBuilder();
        int pos = 0;

        while (pos < content.length) {
            int eol = content.index_of("\r\n", pos);
            if (eol == -1)
                break;

            var size_line = content.substring(pos, eol - pos).split(";")[0]._strip();
            int size = (int)uint64.parse(size_line, 16);
            if (size <= 0)
                break;

            pos = eol + 2;
            if (pos + size > content.length)
                size = content.length - pos;
            decoded.append_len(content.offset(pos), size);
            pos += size + 2;
        }
        return decoded.str;
    }
}
