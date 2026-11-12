# 🧠 BrainLib

BrainLib is a Vala library designed to simplify the integration of Artificial Intelligence.
It provides a unified interface to communicate with the APIs of the major models (Gemini, OpenAI, Anthropic, Mistral, GLM) while remaining lightweight and fast.

## ✨ Features

- Multi-Provider: Native support for Gemini, OpenAI, Anthropic, Mistral and GLM.
- Unified Interface: A single `send()` method to interact with any model, and `send_async()` for non-blocking, cancellable requests.
- Automatic Routing: The provider is picked from the model id, no extra configuration.
- Multi-Language: Thanks to GObject-Introspection, BrainLib can be used from any language supporting GObject bindings (Python, C, Rust, etc.)

## 📦 Adding BrainLib to your project

BrainLib is meant to be consumed as a Meson subproject. Drop a `brainlib.wrap` file
into your `subprojects/` directory:

```ini
# subprojects/brainlib.wrap
[wrap-file]
directory = brainlib-1.0
source_url = https://gitlab.com/nda-cunh/brainlib/-/archive/1.0/brainlib-1.0.tar.gz
source_filename = brainlib-1.0.tar.gz
source_hash = 53f7e68e9f3ebf1e9942a9df05e0c215e4efdfebbdaf55593ee7ed22a7923f07

[provide]
dependency_names = BrainLib
```

Or grab it straight from the repository:

```bash
curl -L -o subprojects/brainlib.wrap https://gitlab.com/nda-cunh/brainlib/-/raw/master/brainlib.wrap
```

Then simply ask for the dependency in your `meson.build`; Meson downloads and builds the
subproject on demand:

```meson
project('myapp', 'vala', 'c')

brainlib_dep = dependency('BrainLib')

executable('myapp',
  'main.vala',
  dependencies : [
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('gio-2.0'),
    brainlib_dep,
  ],
)
```

```bash
meson setup build
meson compile -C build
```

# 💻 Usage Example

```vala
void main() {
    // Client creation (Model, API Key)
    var app = Brain.create("gemini-3.1-flash-lite-preview", "YOUR_API_KEY");

    try {
        // Send a message and get the response
        var response = app.send("Hey there, how are you doing?");
        print ("AI : %s\n", response.content);
    }
    catch (Error e) {
        // Network or API error handling
        print ("Error : %s\n", e.message);
    }
}
```

## ⚡ Asynchronous requests

`send_async()` does not block the main loop and can be cancelled at any time
(the connection is closed and `IOError.CANCELLED` is thrown):

```vala
var app = Brain.create("gpt-4o-mini", "YOUR_API_KEY");
var cancellable = new Cancellable();

app.send_async.begin("Hello!", cancellable, (obj, res) => {
    try {
        print("AI : %s\n", app.send_async.end(res).content);
    }
    catch (Error e) {
        print("Error : %s\n", e.message);
    }
});
// cancellable.cancel(); to abort the request
```

## 💬 Conversations and prompt caching

`send_messages()` sends a system prompt and a list of messages (oldest first).
Providers cache prompts per message: keep the system prompt identical and only
append messages, and the next request reads the start of the conversation from
the cache (`response.cached_tokens`), which is much cheaper.

```vala
Brain.Message[] messages = {
    new Brain.Message("user", "Hello!"),
    new Brain.Message("assistant", "Hi, how can I help?"),
    new Brain.Message("user", "Tell me a joke."),
};
var response = app.send_messages("You are a friendly assistant.", messages);
```

`send_messages_async()` is the cancellable asynchronous version.

## 📊 Token usage

Every response carries the token counts reported by the provider (OpenAI-compatible,
Anthropic and Gemini formats), or 0 when the API does not send them:

```vala
var response = app.send("Hello!");
print("%d in (%d cached), %d out (%d reasoning)\n",
      response.input_tokens, response.cached_tokens,
      response.output_tokens, response.reasoning_tokens);
```

`input_tokens` includes the cached ones and `output_tokens` the reasoning ones.
`cache_write_tokens` is the part of the prompt written to the cache (Anthropic, and OpenAI models that bill cache writes).

## 🔑 Picking the API key

`Brain.provider_of()` tells which provider `create()` will use for a model, so you
can choose the matching key beforehand:

```vala
var provider = Brain.provider_of("claude-sonnet-4-5"); // Brain.Provider.ANTHROPIC
print("%s\n", provider.get_id());                       // "anthropic"
```

## 🤖 Supported models

The provider is deduced from the model id prefix, so any model of a supported
provider works, even a brand new one.

| Model id prefix                                | Provider  | Class     |
| ---------------------------------------------- | --------- | --------- |
| `gemini-*`, `gemma-*`                            | Google    | `Gemini`    |
| `gpt-*`, `o1-*` (and any unknown id)             | OpenAI    | `OpenAi`    |
| `claude-*`                                       | Anthropic | `Anthropic` |
| `mistral-*`, `ministral-*`, `pixtral-*`, `codestral-*` | Mistral   | `Mistral`   |
| `glm-*`                                          | Zhipu-AI  | `Glm`       |
