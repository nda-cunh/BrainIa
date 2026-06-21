public class Brain.ChatApiResponse : Brain.Response {
    public ChatApiResponse(string data_json) throws Error {
        base(data_json);
    }

    public override string parse_text_from_json(string raw_data) throws Error {
        int start = raw_data.index_of("{");
        int end = raw_data.last_index_of("}");

        if (start == -1 || end == -1) throw new ResponseError.InvalidJson("Format JSON invalide");

        string clean_json = raw_data.substring(start, end - start + 1);
        var doc = YYJson.Doc.read(clean_json, clean_json.length);
        if (doc == null) throw new ResponseError.InvalidJson("Format JSON invalide");
        unowned var root = doc.get_root();

        unowned var error_val = root.obj_get("error");
        if (error_val != null) {
            unowned var msg = error_val.obj_get("message");
            throw new ResponseError.ApiError("Erreur API: %s", msg != null ? msg.get_str() : "unknown");
        }

        unowned var choices = root.obj_get("choices");
        if (choices != null) {
            unowned var first = choices.arr_get(0);
            if (first != null) {
                unowned var message = first.obj_get("message");
                if (message != null) {
                    unowned var content = message.obj_get("content");
                    if (content != null) return content.get_str();
                }
            }
        }

        throw new ResponseError.UnknownStructure("Structure JSON inconnue");
    }
}

public class Brain.OpenAiCompatible : Brain.HttpClient {
    protected string endpoint;

    public OpenAiCompatible(string host, string endpoint, string model_id, string api_key) {
        this.host = host;
        this.endpoint = endpoint;
        this.model_id = model_id;
        this.api_key = api_key;
    }

    public override Response? send(string prompt) throws Error {
        var doc = new YYJson.MutDoc();
        unowned var root = doc.obj();
        root.obj_add_str(doc, "model", this.model_id);
        unowned var messages = root.obj_add_arr(doc, "messages");
        unowned var msg_obj = messages.arr_add_obj(doc);
        msg_obj.obj_add_str(doc, "role", "user");
        msg_obj.obj_add_str(doc, "content", prompt);
        doc.set_root(root);

        string? payload = doc.write();
        if (payload == null) throw new ResponseError.InvalidJson("Erreur de sérialisation JSON");
        var payload_utf8 = payload.make_valid();

        debug("Payload JSON envoyé : %s", payload_utf8);

        var raw = send_request(
            "POST",
            this.endpoint,
            {
                "Content-Type: application/json",
                "Authorization: Bearer " + this.api_key,
            },
            payload_utf8
        );

        return new ChatApiResponse(raw);
    }
}
