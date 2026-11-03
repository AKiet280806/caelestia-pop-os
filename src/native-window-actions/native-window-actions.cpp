// Native window actions for the exact installed Hyprland 0.57 ABI.
// Preserve independent maximized floating windows and forward missing minimize requests.
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/view/window/WindowBackend.hpp>
#include <hyprland/src/desktop/view/window/WindowFullscreenPolicy.hpp>
#include <hyprland/src/config/shared/actions/ConfigActions.hpp>
#include <hyprland/src/managers/fullscreen/FullscreenController.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/protocols/core/Compositor.hpp>
#include <hyprland/src/protocols/XDGShell.hpp>
#include <unordered_map>
#include <memory>
#include <optional>
#include <stdexcept>

namespace {
struct WindowActions {
    PHLWINDOWREF window;
    CHyprSignalListener request;
    bool originalMaximizeSuppression = false;
    bool originalFullscreenSuppression = false;
    bool initialMaximize = false;
    bool initialFullscreen = false;
    bool expectMaximizeEcho = false;
    std::optional<Fullscreen::SFullscreenMode> beforeFullscreen;
};
static std::unordered_map<void*, std::unique_ptr<WindowActions>> requests;
static CHyprSignalListener early, opened, closed, floating, rules, reloaded;

static void maximize(PHLWINDOW window, bool enabled) {
    if (!window || !window->mapped() || !window->isFloating()) return;
    const auto mode = Fullscreen::controller()->getFullscreenModes(window);
    const auto desired = enabled ? Fullscreen::FSMODE_MAXIMIZED : Fullscreen::FSMODE_NONE;
    if (!enabled && mode.client != Fullscreen::FSMODE_MAXIMIZED) return;
    if (mode.internal == desired && mode.client == desired) return;
    const bool wasActive = Desktop::focusState()->window() == window;
    Config::Actions::fullscreenWindow(desired, desired, true, window);
    if (wasActive) {
        Config::Actions::focus(window);
        Config::Actions::alterZOrder("top", window);
    }
}
static void updatePolicy(WindowActions& entry) {
    const auto window = entry.window.lock();
    if (!window) return;
    auto policy = window->fullscreenPolicy().requestSuppression();
    policy.maximize = entry.originalMaximizeSuppression || window->isFloating() || entry.expectMaximizeEcho;
    policy.fullscreen = true; // Own fullscreen transitions for both floating and tiled windows.
    window->fullscreenPolicy().setRequestSuppression(policy);
}
static void fullscreen(PHLWINDOW window, bool enabled) {
    if (!window || !window->mapped()) return;
    auto it = requests.find(window.get());
    if (it == requests.end()) return;
    auto& entry = *it->second;
    const auto current = Fullscreen::controller()->getFullscreenModes(window);
    Fullscreen::SFullscreenMode desired;
    if (enabled) {
        if (current.internal == Fullscreen::FSMODE_FULLSCREEN) return;
        entry.beforeFullscreen = current;
        desired = {Fullscreen::FSMODE_FULLSCREEN, Fullscreen::FSMODE_FULLSCREEN};
    } else {
        if (current.internal != Fullscreen::FSMODE_FULLSCREEN && current.client != Fullscreen::FSMODE_FULLSCREEN) return;
        desired = entry.beforeFullscreen.value_or(Fullscreen::SFullscreenMode{});
        entry.expectMaximizeEcho = desired.internal == Fullscreen::FSMODE_MAXIMIZED;
        entry.beforeFullscreen.reset();
    }
    updatePolicy(entry);
    const bool wasActive = Desktop::focusState()->window() == window;
    if (window->isFloating())
        Config::Actions::fullscreenWindow(desired.internal, desired.client, true, window);
    else
        Fullscreen::controller()->setFullscreenMode(window, desired.internal, desired.client, true);
    if (wasActive) {
        Config::Actions::focus(window);
        Config::Actions::alterZOrder("top", window);
    }
}
static void attach(PHLWINDOW window, bool mapping = false) {
    if (!window || requests.contains(window.get())) return;
    auto entry = std::make_unique<WindowActions>();
    entry->window = window;
    entry->originalMaximizeSuppression = window->fullscreenPolicy().requestSuppression().maximize;
    entry->originalFullscreenSuppression = window->fullscreenPolicy().requestSuppression().fullscreen;
    entry->initialMaximize = mapping && !entry->originalMaximizeSuppression && window->fullscreenPolicy().pendingClientRequest().mode == Fullscreen::FSMODE_MAXIMIZED;
    entry->initialFullscreen = mapping && !entry->originalFullscreenSuppression && window->fullscreenPolicy().pendingClientRequest().mode == Fullscreen::FSMODE_FULLSCREEN;
    updatePolicy(*entry);
    PHLWINDOWREF weak = window;
    const bool originalMaximizeSuppression = entry->originalMaximizeSuppression;
    const bool originalFullscreenSuppression = entry->originalFullscreenSuppression;
    entry->request = window->backend().m_events.stateRequest.listen(
        [weak, originalMaximizeSuppression, originalFullscreenSuppression](const Desktop::View::SBackendStateRequest& request) {
            const auto window = weak.lock();
            if (!window || !window->mapped()) return;
            if (request.minimized.has_value())
                Event::bus()->m_events.window.minimize.emit(window, *request.minimized);
            if (request.fullscreen.has_value() && !originalFullscreenSuppression) fullscreen(window, *request.fullscreen);
            if (request.maximized.has_value() && !originalMaximizeSuppression) {
                auto& entry = *requests.at(window.get());
                bool echo = false;
                // 0.57 converts every xdg maximize request into an internal-state
                // toggle. Chromium reasserts set_maximized after fullscreen exit;
                // distinguish that protocol echo from a real unset_maximized.
                if (entry.expectMaximizeEcho && !window->backend().isX11()) {
                    const auto surface = window->backend().surface();
                    if (surface && surface->m_role && surface->m_role->role() == SURFACE_ROLE_XDG_SHELL) {
                        const auto role = static_cast<CXDGSurfaceRole*>(surface->m_role.get());
                        const auto xdg = role->m_xdgSurface.lock();
                        const auto top = xdg ? xdg->m_toplevel.lock() : nullptr;
                        echo = top && top->m_state.requestsMaximize.value_or(false);
                    }
                }
                entry.expectMaximizeEcho = false;
                if (!echo) {
                    if (window->isFloating()) maximize(window, *request.maximized);
                    else {
                        const auto mode = Fullscreen::controller()->getFullscreenModes(window);
                        if (*request.maximized || mode.client == Fullscreen::FSMODE_MAXIMIZED)
                            Fullscreen::controller()->setFullscreenMode(window, std::nullopt,
                                *request.maximized ? Fullscreen::FSMODE_MAXIMIZED : Fullscreen::FSMODE_NONE);
                    }
                }
                updatePolicy(entry);
            }
        });
    requests.emplace(window.get(), std::move(entry));
}
} // namespace

APICALL EXPORT std::string PLUGIN_API_VERSION() { return HYPRLAND_API_VERSION; }
APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE) {
    if (std::string(__hyprland_api_get_hash()) != std::string(__hyprland_api_get_client_hash()))
        throw std::runtime_error("native-minimize: Hyprland headers/runtime version mismatch");
    early = Event::bus()->m_events.window.openEarly.listen([](PHLWINDOW window) { attach(window, true); });
    opened = Event::bus()->m_events.window.openLate.listen([](PHLWINDOW window) {
        attach(window);
        auto& entry = *requests.at(window.get());
        // Static map rules run after openEarly and replace suppression fields.
        updatePolicy(entry);
        if (entry.initialMaximize) { entry.initialMaximize = false; maximize(window, true); }
        if (entry.initialFullscreen) { entry.initialFullscreen = false; fullscreen(window, true); }
    });
    closed = Event::bus()->m_events.window.close.listen([](PHLWINDOW window) { requests.erase(window.get()); });
    floating = Event::bus()->m_events.window.floating.listen([](PHLWINDOW window) {
        if (auto it = requests.find(window.get()); it != requests.end()) updatePolicy(*it->second);
    });
    rules = Event::bus()->m_events.window.updateRules.listen([](PHLWINDOW window) {
        if (auto it = requests.find(window.get()); it != requests.end()) updatePolicy(*it->second);
    });
    reloaded = Event::bus()->m_events.config.reloaded.listen([] {
        for (const auto& [_, entry] : requests) updatePolicy(*entry);
    });
    for (const auto& window : Desktop::windowState()->windows())
        if (window->mapped()) attach(window);
    return {"native-minimize", "Preserve native floating maximize and forward minimize requests", "Local Caelestia integration", "0.5"};
}
APICALL EXPORT void PLUGIN_EXIT() {
    early.reset(); opened.reset(); closed.reset(); floating.reset(); rules.reset(); reloaded.reset();
    for (const auto& [_, entry] : requests) {
        if (const auto window = entry->window.lock()) {
            auto policy = window->fullscreenPolicy().requestSuppression();
            policy.maximize = entry->originalMaximizeSuppression;
            policy.fullscreen = entry->originalFullscreenSuppression;
            window->fullscreenPolicy().setRequestSuppression(policy);
        }
    }
    requests.clear();
}
