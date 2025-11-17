# 🖥 Chrome & Chromedriver with VNC

A ready-to-use Docker image for running **Google Chrome + Chromedriver + VNC**, fully compatible with **Selenoid**.

---

## 📦 Docker Hub

### VNC Chrome  
[![Docker Pulls](https://img.shields.io/docker/pulls/lafisteri/vnc_chrome.svg?label=vnc_chrome%20pulls&logo=docker)](https://hub.docker.com/r/lafisteri/vnc_chrome)

Docker Hub:  
👉 https://hub.docker.com/repository/docker/lafisteri/vnc_chrome/general

Download the latest image:
```bash
docker pull lafisteri/vnc_chrome:latest
```

---

## 🧩 Example Selenoid configuration (`browsers.json`)

Add browser configuration by specifying the built image tag:

```json
{
  "chrome": {
    "default": "142.0",
    "versions": {
      "142.0": {
        "image": "lafisteri/vnc_chrome:142.0",
        "port": "4444",
        "path": "/"
      }
    }
  }
}
```

---

## 🚀 Local image build

The `./images` script automates the build and accepts the following arguments:

| Argument     | Description                      |
|--------------|-------------------------------|
| `-b`         | Chrome `.deb` version         |
| `-d`         | Chromedriver version          |
| `-t`         | final Docker image tag.       |
| `vnc_chrome` | enables the VNC stack         |

Build example:
```bash
./images chrome -b 142.0.7444.61-1 -d 142.0.7444.61 -t my/vnc_chrome:142.0 vnc_chrome
```
