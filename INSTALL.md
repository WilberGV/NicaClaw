# NicaClaw-lite Installation Guide

NicaClaw-lite is an ultra-efficient AI Assistant designed to run with minimal resources. Follow the guide below for your specific platform.

---

## 🖥 Windows

1. **Download**: Obtain the latest `nicaclaw-lite.exe` from the [Releases](https://github.com/WilberGV/nicaclaw-lite/releases) page.
2. **Initialize**: Open a terminal (PowerShell or Command Prompt) and run:
   ```powershell
   .\nicaclaw-lite.exe onboard
   ```
3. **Configure**: Set your API keys in `~/.nicaclaw-lite/config.json`.
4. **Run**:
   ```powershell
   .\nicaclaw-lite.exe agent --message "Hello"
   ```

---

## 🐧 Linux (Desktop & Server)

Works on major distros like **Ubuntu, Debian, Fedora, Arch, and Centos**.

1. **Download**:
   ```bash
   wget https://github.com/WilberGV/nicaclaw-lite/releases/latest/download/nicaclaw-lite-linux-amd64
   chmod +x nicaclaw-lite-linux-amd64
   sudo mv nicaclaw-lite-linux-amd64 /usr/local/bin/nicaclaw-lite
   ```
2. **Onboard**:
   ```bash
   nicaclaw-lite onboard
   ```
3. **Configure**: Edit `~/.nicaclaw-lite/config.json` to add your LLM API keys.

---

## 📱 Android (Termux)

Turn your old phone into an AI assistant.

1. **Install Termux**: Download from F-Droid or GitHub.
2. **Setup Environment**:
   ```bash
   pkg update && pkg upgrade
   pkg install wget proot
   ```
3. **Download & Run**:
   ```bash
   wget https://github.com/WilberGV/nicaclaw-lite/releases/latest/download/nicaclaw-lite-linux-arm64
   chmod +x nicaclaw-lite-linux-arm64
   termux-chroot ./nicaclaw-lite-linux-arm64 onboard
   ```

---

## 🛠 Build from Source

For developers who want the latest features.

1. **Prerequisites**: [Go 1.21+](https://go.dev/dl/) installed.
2. **Clone & Build**:
   ```bash
   git clone https://github.com/WilberGV/nicaclaw-lite.git
   cd nicaclaw-lite
   make build
   ```
3. **Install**:
   ```bash
   make install
   ```

---

## 🚀 Quick Start Configuration

Set your API key in `~/.nicaclaw-lite/config.json`:

```json
{
  "model_list": [
    {
      "model_name": "gemini-flash",
      "model": "google/models/gemini-flash-latest",
      "api_key": "YOUR_GEMINI_API_KEY"
    },
    {
      "model_name": "gpt-4o",
      "model": "openai/gpt-4o",
      "api_key": "YOUR_OPENAI_API_KEY"
    }
  ]
}
```

Get keys from: [OpenRouter](https://openrouter.ai/keys), [Google AI Studio](https://aistudio.google.com/app/apikey), or [OpenAI](https://platform.openai.com/api-keys).
