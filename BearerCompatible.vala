public class ChatApiResponse : Response {
    public ChatApiResponse(string data_json) throws Error {
        base(data_json);
    }

    public override string parse_text_from_json(string raw_data) throws Error {
        int start = raw_data.index_of("{");
        int end = raw_data.last_index_of("}");

        if (start == -1 || end == -1) throw new ResponseError.InvalidJson("Format JSON invalide");

        string clean_json = raw_data.substring(start, end - start + 1);
        var parser = new Json.Parser();
        parser.load_from_data(clean_json, -1);
        var root = parser.get_root().get_object();

        if (root.has_member("error")) {
            var err = root.get_object_member("error");
            throw new ResponseError.ApiError("Erreur API: %s", err.get_string_member("message"));
        }

        if (root.has_member("choices")) {
            var choices = root.get_array_member("choices");
            var message = choices.get_object_element(0).get_object_member("message");
            return message.get_string_member("content");
        }

        throw new ResponseError.UnknownStructure("Structure JSON inconnue");
    }
}

public class OpenAiCompatible : BrainIa {
    protected string host;
    protected string endpoint;

    public OpenAiCompatible(string host, string endpoint, string model_id, string api_key) {
        this.host = host;
        this.endpoint = endpoint;
        this.model_id = model_id;
        this.api_key = api_key;
    }

    public override Response? send(string prompt) throws Error {
        var client = new SocketClient() { tls = true };
        var conn = client.connect_to_host(this.host, 443);

        // Construction du JSON (Standard pour tous)
        var builder = new Json.Builder();
        builder.begin_object();
            builder.set_member_name("model");
            builder.add_string_value(this.model_id);
            builder.set_member_name("messages");
            builder.begin_array();
                builder.begin_object();
                    builder.set_member_name("role");
                    builder.add_string_value("user");
                    builder.set_member_name("content");
                    builder.add_string_value(prompt);
                builder.end_object();
            builder.end_array();
        builder.end_object();

        string payload = (new Json.Generator() { root = builder.get_root() }).to_data(null);

        // Requête HTTP générique
        StringBuilder sb = new StringBuilder();
        sb.append ("POST %s HTTP/1.1\r\n".printf(this.endpoint));
        sb.append ("Host: %s\r\n".printf(this.host));
        sb.append ("Content-Type: application/json\r\n");
        sb.append ("Authorization: Bearer %s\r\n".printf(this.api_key));
        sb.append ("Content-Length: %d\r\n".printf(payload.length));
        sb.append ("Connection: close\r\n\r\n");
        sb.append (payload);

        conn.output_stream.write_all(sb.str.data, null);
        
        var input = new DataInputStream(conn.input_stream);
        StringBuilder res_sb = new StringBuilder();
        uint8 buffer[4096];
        size_t bytes;
        while (input.read_all(buffer, out bytes, null) && bytes > 0) {
            res_sb.append_len((string)buffer, (ssize_t)bytes);
        }

        return new ChatApiResponse(res_sb.str);
    }
}
