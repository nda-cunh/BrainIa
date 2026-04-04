public abstract class Brain.HttpClient : BrainIa {
    protected string host;
    protected int port = 443;

    protected string send_request(string method, string endpoint, string[] headers, string body) throws Error {
        var client = new SocketClient() { tls = true };
        var conn = client.connect_to_host(this.host, (uint16)this.port);

        StringBuilder request = new StringBuilder();
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
			// Lecture simplifiée
			while ((bytes = input.read(buffer)) > 0) {
				buffer[bytes] = 0; // Null-terminate the buffer
				response.append_len((string)buffer, (long)bytes);
			}
		}
		catch (Error e) {
			// Gérer les erreurs de lecture, par exemple, si la connexion est fermée
		}
        return response.str;
    }
}
