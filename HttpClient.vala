public abstract class Brain.HttpClient : BrainIa {
    protected string host;
    protected int port = 443;

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

        var request = new StringBuilder();
        request.append("%s %s HTTP/1.1\r\n".printf(method, endpoint));
        request.append("Host: %s\r\n".printf(this.host));
        foreach (var header in headers) {
            request.append(header + "\r\n");
        }
        request.append("Content-Length: %d\r\n".printf(body.length));
        request.append("Connection: close\r\n\r\n");
        request.append(body);

        conn.output_stream.write_all(request.str.data, null);
        
        var input = new DataInputStream(conn.input_stream);
        StringBuilder response = new StringBuilder();
        uint8 buffer[4096];
        size_t bytes;
        
		try {
			while ((bytes = input.read(buffer)) > 0) {
				response.append_len((string)buffer, (long)bytes);
			}
		}
		catch (Error e) {
		}

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
