pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.modules.osd as Osd

Variants {
    model: Screens.screens

    Scope {
        id: scope

        required property ShellScreen modelData

        Exclusions {
            screen: scope.modelData
            bar: content.bar
        }

        // A separate surface maps directly on Overlay. Moving the already
        // occluded drawers surface between layers stalls on this compositor.
        LazyLoader {
            active: content.hasFullscreen && content.osdPanel.shouldBeActive
            StyledWindow {
                name: "fullscreen-osd"
                screen: scope.modelData
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                anchors.right: true
                margins.right: 12
                implicitWidth: osdContent.implicitWidth + 24
                implicitHeight: osdContent.implicitHeight + 24
                // Indicators pass clicks through to the fullscreen application.
                mask: Region {}
                StyledRect {
                    anchors.fill: parent
                    radius: Tokens.rounding.large
                    color: Colours.palette.m3surfaceContainer
                    Osd.Content {
                        id: osdContent
                        anchors.centerIn: parent
                        monitor: content.osdPanel.monitor
                        screenState: content.screenState
                        volume: content.osdPanel.volume
                        muted: content.osdPanel.muted
                        sourceVolume: content.osdPanel.sourceVolume
                        sourceMuted: content.osdPanel.sourceMuted
                        brightness: content.osdPanel.brightness
                    }
                }
            }
        }
        ContentWindow {
            id: content

            screen: scope.modelData
        }
    }
}
