// sway.go - Sway/wlroots WindowManager implementation via swaymsg IPC.
//
// Copied into the upstream tree at build time (see default.nix) in place of
// hyprland.go's HyprlandManager, which this package's main() constructs by
// default. Implements the same WindowManager interface main.go already
// depends on — main.go's toggleWindow()/ensureSpotifyVisible() logic is
// otherwise compositor-agnostic and needs no changes beyond the one-line
// NewHyprlandManager() -> NewSwayManager() swap.
//
// main.go prefixes addresses with "address:" (Hyprland's own selector
// syntax) before calling MoveWindow/FocusWindow/CloseWindow, so every method
// here strips that prefix before using the bare sway con_id.

package main

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

// Must match main.go's specialWorkspace constant — that's the only value
// toggleWindow() checks for via strings.HasPrefix(..., "special") to decide
// whether the window is currently hidden.
const swaySpecialWorkspace = "special:spotify"

type SwayManager struct{}

func NewSwayManager() *SwayManager {
	return &SwayManager{}
}

type swayNode struct {
	ID              int        `json:"id"`
	AppID           string     `json:"app_id"`
	Name            string     `json:"name"`
	Visible         bool       `json:"visible"`
	ScratchpadState string     `json:"scratchpad_state"`
	Nodes           []swayNode `json:"nodes"`
	FloatingNodes   []swayNode `json:"floating_nodes"`
}

func getTree() (*swayNode, error) {
	out, err := exec.Command("swaymsg", "-t", "get_tree").Output()
	if err != nil {
		return nil, fmt.Errorf("failed to get tree: %w", err)
	}
	var root swayNode
	if err := json.Unmarshal(out, &root); err != nil {
		return nil, fmt.Errorf("failed to parse tree: %w", err)
	}
	return &root, nil
}

func walkNodes(n *swayNode, fn func(*swayNode)) {
	fn(n)
	for i := range n.Nodes {
		walkNodes(&n.Nodes[i], fn)
	}
	for i := range n.FloatingNodes {
		walkNodes(&n.FloatingNodes[i], fn)
	}
}

func (s *SwayManager) GetClients() ([]HyprlandClient, error) {
	root, err := getTree()
	if err != nil {
		return nil, err
	}
	var clients []HyprlandClient
	walkNodes(root, func(n *swayNode) {
		if n.AppID == "" {
			return
		}
		ws := ""
		if n.ScratchpadState != "none" && !n.Visible {
			ws = swaySpecialWorkspace
		}
		clients = append(clients, HyprlandClient{
			Address: strconv.Itoa(n.ID),
			Class:   n.AppID,
			Title:   n.Name,
			Workspace: struct {
				ID   int
				Name string
			}{Name: ws},
		})
	})
	return clients, nil
}

func (s *SwayManager) FindSpotify() (HyprlandClient, bool) {
	clients, err := s.GetClients()
	if err != nil {
		return HyprlandClient{}, false
	}
	for _, c := range clients {
		if c.Class == "spotify" {
			return c, true
		}
	}
	return HyprlandClient{}, false
}

// conID strips main.go's "address:" prefix and validates what remains is a
// plain sway con_id (digits only) before it's interpolated into a swaymsg
// criteria string.
func conID(address string) (string, error) {
	id := strings.TrimPrefix(address, "address:")
	if id == "" {
		return "", fmt.Errorf("empty address")
	}
	if _, err := strconv.Atoi(id); err != nil {
		return "", fmt.Errorf("invalid con_id in address %q: %w", address, err)
	}
	return id, nil
}

func runSwaymsg(cmd string) error {
	out, err := exec.Command("swaymsg", cmd).CombinedOutput()
	if err != nil {
		return fmt.Errorf("swaymsg %q failed: %w (%s)", cmd, err, strings.TrimSpace(string(out)))
	}
	return nil
}

func (s *SwayManager) MoveWindow(address, workspace string) error {
	id, err := conID(address)
	if err != nil {
		return err
	}
	criteria := fmt.Sprintf("[con_id=%s]", id)

	if workspace == swaySpecialWorkspace {
		return runSwaymsg(criteria + " move to scratchpad")
	}

	// Showing: the window can exist in get_tree slightly before its surface
	// is actually ready to be shown, so `scratchpad show` fired immediately
	// after launch can silently no-op (same race the $mod+s keybind script
	// hit — see modules/home/linux/media/spotify.nix). A short buffer here
	// covers both the fresh-launch and the already-settled-window case.
	time.Sleep(400 * time.Millisecond)
	return runSwaymsg(criteria + " scratchpad show")
}

func (s *SwayManager) FocusWindow(address string) error {
	id, err := conID(address)
	if err != nil {
		return err
	}
	return runSwaymsg(fmt.Sprintf("[con_id=%s] focus", id))
}

func (s *SwayManager) CloseWindow(class string) error {
	return runSwaymsg(fmt.Sprintf("[app_id=%q] kill", class))
}

func (s *SwayManager) LaunchSpotify() error {
	cmd := exec.Command("spotify")
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to launch spotify: %w", err)
	}
	go func() { _ = cmd.Wait() }()
	return nil
}
