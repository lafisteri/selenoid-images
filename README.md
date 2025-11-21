# 🖥 Chrome & Chromedriver with VNC

A ready-to-use Docker image for running **Google Chrome + Chromedriver + VNC**, fully compatible with **Selenoid**.

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
