# 🧠 BrainLib

BrainLib est une bibliothèque en Vala conçue pour simplifier l'intégration d'Intelligences Artificielles.
Elle offre une interface unifiée pour communiquer avec les API des plus grands modèles (Gemini, OpenAI, Mistral, GLM) tout en restant légère et performante.

## ✨ Caractéristiques

- Multi-Fournisseurs : Support natif pour Gemini, OpenAI, Mistral et GLM.
- Interface Unifiée : Une seule méthode send() pour interagir avec n'importe quel modèle
- Multi-Language: Grace a Gobject-Introspection, BrainLib est utilisable depuis n'importe quel langage supportant les bindings GObject (Python, C, Rust, etc.)

## 🚀 Installation

Le projet utilise le système de construction Meson

```bash
# Cloner le dépôt
git clone https://gitlab.com/nda-cunh/brainlib
cd brainlib
meson build --prefix=/usr
meson install -C build --skip-subprojects
```

# 💻 Exemple d'utilisation

```vala
void main() {
    // Initialisation du client (Modèle, Clé API)
    var app = new Brain.create("gemini-3.1-flash-lite-preview", "VOTRE_CLE_API");

    try {
        // Envoi d'un message et récupération de la réponse
        var response = app.send("Salut mec comment tu vas ?");
        print ("IA : %s\n", response.content);
    }
    catch (Error e) {
        // Gestion des erreurs réseau ou API
        print ("Erreur : %s\n", e.message);
    }
}
```

| Modèles supportés | Fournisseur |
| ----------------- | ----------- |
|      Gemini       |   Google    |
|      OpenAi       |   OpenAI    |
|      Mistral      |   Mistral   |
|      AIGlm        |   Zhipu-AI  |
