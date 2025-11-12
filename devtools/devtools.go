package main

import (
	"context"
	"errors"
	"fmt"
	"github.com/mafredri/cdp/devtool"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

const (
	devtoolsBaseDir = "/tmp"
	slash           = "/"
)

var (
	defaultDevtoolsHost = "127.0.0.1:9222"
	android             bool
)

func main() {
	listen := ":7070"
	for i := 0; i < len(os.Args); i++ {
		if os.Args[i] == "-listen" && i+1 < len(os.Args) {
			listen = os.Args[i+1]
		}
		if os.Args[i] == "-android" {
			android = true
		}
	}
	log.Printf("[INIT] [Listening on %s]", listen)
	log.Fatal(http.ListenAndServe(listen, root()))
}

func root() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/browser", browser)
	mux.HandleFunc("/json/protocol", protocol)
	mux.HandleFunc("/page", page)
	mux.HandleFunc("/page/", page)
	mux.HandleFunc("/", browser)
	return mux
}

func browser(w http.ResponseWriter, r *http.Request) {
	u, err := getBrowserWebSocketUrl()
	if err != nil {
		log.Printf("[BROWSER_URL_ERROR] [%v]", err)
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	log.Printf("[BROWSER] [%s]", u.String())
	proxyWebSocket(w, r, u)
}

func page(w http.ResponseWriter, r *http.Request) {
	fragments := strings.Split(r.URL.Path, slash)
	targetId := ""
	if len(fragments) == 3 {
		targetId = fragments[2]
	}
	u, err := getPageWebSocketUrl(targetId)
	if err != nil {
		log.Printf("[PAGE_URL_ERROR] [%v]", err)
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	log.Printf("[PAGE] [%s]", u.String())
	proxyWebSocket(w, r, u)
}

func protocol(w http.ResponseWriter, r *http.Request) {
	h, err := devtoolsHost()
	if err != nil {
		log.Printf("[DEVTOOLS_HOST_ERROR] [%v]", err)
		http.Error(w, fmt.Sprintf("Failed to detect devtools host: %v", err), http.StatusInternalServerError)
		return
	}
	u := &url.URL{Host: h, Scheme: "http", Path: "/json/protocol"}
	log.Printf("[PROTOCOL] [%s]", u.String())
	(&httputil.ReverseProxy{
		Director: func(r *http.Request) {
			r.Host = "localhost"
			r.URL = u
		},
	}).ServeHTTP(w, r)
}

func proxyWebSocket(w http.ResponseWriter, r *http.Request, u *url.URL) {
	u.Scheme = "http"
	(&httputil.ReverseProxy{
		Director: func(r *http.Request) {
			r.Host = "localhost"
			r.URL = u
		},
	}).ServeHTTP(w, r)
}

func getBrowserWebSocketUrl() (*url.URL, error) {
	ctx := context.Background()
	h, err := devtoolsHost()
	if err != nil {
		return nil, fmt.Errorf("failed to detect devtools port: %v", err)
	}
	dt := devtool.New(fmt.Sprintf("http://%s", h))
	ver, err := dt.Version(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get browser websocket url: %v", err)
	}
	wsUrl, err := url.Parse(ver.WebSocketDebuggerURL)
	if err == nil {
		return wsUrl, nil
	}
	return nil, errors.New("browser websocket URL information not found")
}

func getPageWebSocketUrl(targetId string) (*url.URL, error) {
	ctx := context.Background()
	h, err := devtoolsHost()
	if err != nil {
		return nil, fmt.Errorf("failed to detect devtools port: %v", err)
	}
	dt := devtool.New(fmt.Sprintf("http://%s", h))
	targets, err := dt.List(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to list targets: %v", err)
	}
	for _, t := range targets {
		if (targetId == "" && t.Type == devtool.Page) || targetId == t.ID {
			wsUrl, err := url.Parse(t.WebSocketDebuggerURL)
			if err != nil {
				return nil, fmt.Errorf("invalid websocket URL for matched target %s: %v", t.ID, err)
			}
			return wsUrl, nil
		}
	}
	return nil, errors.New("no matching target found")
}

func devtoolsHost() (string, error) {
	if android {
		return androidDevtoolsHost()
	}
	return detectDevtoolsHost(devtoolsBaseDir), nil
}

func androidDevtoolsHost() (string, error) {
	const androidDevtoolsPort = 9333
	cmd := exec.Command("adb", "forward",
		fmt.Sprintf("tcp:%d", androidDevtoolsPort),
		"localabstract:chrome_devtools_remote")
	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("failed to forward devtools port: %v", err)
	}
	return fmt.Sprintf("localhost:%d", androidDevtoolsPort), nil
}

func detectDevtoolsHost(baseDir string) string {
	var candidates []string
	if pd, ok := os.LookupEnv("BROWSER_PROFILE_DIR"); ok {
		candidates = append(candidates, pd)
	} else {
		for _, glob := range []string{".com.google.Chrome*", ".org.chromium.Chromium*"} {
			if cds, err := filepath.Glob(filepath.Join(baseDir, glob)); err == nil {
				candidates = append(candidates, cds...)
			}
		}
	}
	for _, c := range candidates {
		fi, err := os.Stat(c)
		if err != nil || !fi.IsDir() {
			continue
		}
		data, err := os.ReadFile(filepath.Join(c, "DevToolsActivePort"))
		if err != nil {
			continue
		}
		lines := strings.Split(string(data), "\n")
		if len(lines) == 0 {
			continue
		}
		if port, err := strconv.Atoi(lines[0]); err == nil {
			return fmt.Sprintf("127.0.0.1:%d", port)
		}
	}
	return defaultDevtoolsHost
}
