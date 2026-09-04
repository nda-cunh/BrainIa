# 🧠 BrainLib

BrainLib is a Vala library designed to simplify the integration of Artificial Intelligence.
It provides a unified interface to communicate with the APIs of the major models (Gemini, OpenAI, Anthropic, Mistral, GLM) while remaining lightweight and fast.

## ✨ Features

- Multi-Provider: Native support for Gemini, OpenAI, Anthropic, Mistral and GLM.
- Unified Interface: A single `send()` method to interact with any model.
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
