import Adw
import Foundation
import Gtk
import LumaCore

@MainActor
enum TracerHookContextMenu {
    struct Actions {
        var toggleEnabled: (() -> Void)?
        var setITraceArming: (ITraceArming?) -> Void
        var itraceCaptured: () -> Int
        var confirmDelete: () -> Void
    }

    static func sections(
        for hook: TracerConfig.Hook,
        anchor: Widget,
        actions: Actions
    ) -> [[ContextMenu.Item]] {
        var sections: [[ContextMenu.Item]] = []

        if let toggleEnabled = actions.toggleEnabled {
            sections.append([
                .init(hook.state == .enabled ? "Disable Hook" : "Enable Hook", handler: toggleEnabled)
            ])
        }

        if hook.kind == .function {
            var itraceItems: [ContextMenu.Item] = []
            let openConfig: () -> Void = {
                presentITraceConfigPopover(anchor: anchor, hook: hook, actions: actions)
            }
            if hook.itraceArming != nil {
                itraceItems.append(.init("Stop Instruction Trace") {
                    actions.setITraceArming(nil)
                })
                itraceItems.append(.init("Edit Instruction Trace\u{2026}", handler: openConfig))
            } else {
                itraceItems.append(.init("Start Instruction Trace\u{2026}", handler: openConfig))
            }
            sections.append(itraceItems)
        }

        sections.append([
            .init("Delete Hook", destructive: true, handler: actions.confirmDelete)
        ])

        return sections
    }

    static func present(
        at anchor: Widget,
        x: Double,
        y: Double,
        hook: TracerConfig.Hook,
        actions: Actions
    ) {
        ContextMenu.present(sections(for: hook, anchor: anchor, actions: actions), at: anchor, x: x, y: y)
    }

    static func makePopover(
        for hook: TracerConfig.Hook,
        anchor: Widget,
        actions: Actions,
        dismiss: @escaping () -> Void
    ) -> Popover {
        let popover = Popover()
        popover.autohide = true

        let menuBox = Box(orientation: .vertical, spacing: 2)
        menuBox.marginStart = 6
        menuBox.marginEnd = 6
        menuBox.marginTop = 6
        menuBox.marginBottom = 6

        let secs = sections(for: hook, anchor: anchor, actions: actions)
        for (idx, section) in secs.enumerated() {
            if idx > 0 {
                menuBox.append(child: Separator(orientation: .horizontal))
            }
            for item in section {
                let button = Button(label: item.label)
                button.add(cssClass: "flat")
                if item.isDestructive {
                    button.add(cssClass: "luma-menu-destructive")
                }
                let handler = item.handler
                button.onClicked { _ in
                    MainActor.assumeIsolated {
                        dismiss()
                        handler()
                    }
                }
                menuBox.append(child: button)
            }
        }
        popover.set(child: menuBox)
        return popover
    }

    static func liveActions(
        hook: TracerConfig.Hook,
        anchor: Widget,
        engine: Engine,
        sessionID: UUID,
        instrumentID: UUID,
        host: InstrumentUIHost
    ) -> Actions {
        Actions(
            toggleEnabled: {
                let newState: TracerConfig.Hook.State = hook.state == .enabled ? .disabled : .enabled
                Task { @MainActor in
                    await engine.updateTracerHook(sessionID: sessionID, hookID: hook.id) { hook in
                        hook.state = newState
                    }
                }
            },
            setITraceArming: { arming in
                Task { @MainActor in
                    await engine.updateTracerHook(sessionID: sessionID, hookID: hook.id) { hook in
                        hook.itraceArming = arming
                    }
                }
            },
            itraceCaptured: {
                let traces = engine.tracesBySession[sessionID] ?? []
                return traces.reduce(into: 0) { count, trace in
                    if case .functionCall(let id, _) = trace.origin, id == hook.id { count += 1 }
                }
            },
            confirmDelete: {
                presentDeleteDialog(anchor: anchor, hook: hook) {
                    let isSelected = host.selectedComponentID(
                        sessionID: sessionID,
                        instrumentID: instrumentID
                    ) == hook.id
                    Task { @MainActor in
                        await engine.removeTracerHook(sessionID: sessionID, hookID: hook.id)
                        if isSelected {
                            host.navigateToInstrument(sessionID: sessionID, instrumentID: instrumentID)
                        }
                    }
                }
            }
        )
    }

    static func presentDeleteDialog(
        anchor: Widget,
        hook: TracerConfig.Hook,
        onConfirm: @escaping () -> Void
    ) {
        let dialog = Adw.AlertDialog(
            heading: "Delete \u{201C}\(hook.displayName)\u{201D}?",
            body: "This will remove the hook from the tracer."
        )
        dialog.addResponse(id: "cancel", label: "_Cancel")
        dialog.addResponse(id: "delete", label: "Delete Hook")
        dialog.setResponseAppearance(response: "delete", appearance: .destructive)
        dialog.setDefault(response: "cancel")
        dialog.setClose(response: "cancel")
        dialog.onResponse { _, responseID in
            MainActor.assumeIsolated {
                guard responseID == "delete" else { return }
                onConfirm()
            }
        }
        dialog.present(parent: WidgetRef(anchor))
    }

    private static func presentITraceConfigPopover(
        anchor: Widget,
        hook: TracerConfig.Hook,
        actions: Actions
    ) {
        let popover = ITraceConfigPopover(
            hook: hook,
            captured: actions.itraceCaptured(),
            onApply: actions.setITraceArming
        )
        popover.present(anchor: anchor)
    }
}

@MainActor
final class ITraceConfigPopover {
    private static var active: ITraceConfigPopover?

    private let popover: Popover
    private let invocationsSpin: SpinButton
    private let bytesStepper: BytesStepper
    private let primaryButton: Button
    private let disableButton: Button
    private let isOn: Bool
    private let onApply: (ITraceArming?) -> Void

    init(hook: TracerConfig.Hook, captured: Int, onApply: @escaping (ITraceArming?) -> Void) {
        self.onApply = onApply
        isOn = hook.itraceArming != nil

        popover = Popover()
        popover.autohide = true
        popover.position = .right
        popover.onClosed { _ in
            MainActor.assumeIsolated {
                ITraceConfigPopover.active = nil
            }
        }

        invocationsSpin = SpinButton(range: 1, max: 100, step: 1)
        bytesStepper = BytesStepper(
            value: hook.itraceArming?.maxBytesPerInvocation ?? ITraceArming.defaultMaxBytesPerInvocation,
            lowerBound: 256 * 1024,
            upperBound: 64 * 1024 * 1024,
            step: 256 * 1024
        )
        invocationsSpin.value = Double(hook.itraceArming?.maxInvocations ?? ITraceArming.defaultMaxInvocations)

        disableButton = Button(label: "Disable")
        primaryButton = Button(label: isOn ? "Save caps" : "Enable")

        installLayout(captured: captured)
        wireSignals()
    }

    func present(anchor: Widget) {
        ITraceConfigPopover.active = self
        popover.set(parent: WidgetRef(anchor))
        popover.popup()
    }

    private func installLayout(captured: Int) {
        let body = Box(orientation: .vertical, spacing: 12)
        body.marginStart = 14
        body.marginEnd = 14
        body.marginTop = 12
        body.marginBottom = 12
        body.setSizeRequest(width: 280, height: -1)

        let title = Label(str: "Instruction trace")
        title.halign = .start
        title.add(cssClass: "heading")
        body.append(child: title)

        let hint = Label(str: "Capture every call up to the caps below.")
        hint.halign = .start
        hint.add(cssClass: "dim-label")
        hint.add(cssClass: "caption")
        hint.wrap = true
        hint.xalign = 0
        body.append(child: hint)

        let invocationsRow = Box(orientation: .horizontal, spacing: 8)
        let invocationsLabel = Label(str: "Max calls")
        invocationsLabel.halign = .start
        invocationsLabel.hexpand = true
        invocationsRow.append(child: invocationsLabel)
        invocationsSpin.halign = .end
        invocationsRow.append(child: invocationsSpin)
        body.append(child: invocationsRow)

        let bytesRow = Box(orientation: .horizontal, spacing: 8)
        let bytesLabel = Label(str: "Max per call")
        bytesLabel.halign = .start
        bytesLabel.hexpand = true
        bytesRow.append(child: bytesLabel)
        bytesStepper.widget.halign = .end
        bytesRow.append(child: bytesStepper.widget)
        body.append(child: bytesRow)

        if isOn {
            let capturedLabel = Label(str: "\(captured) of \(Int(invocationsSpin.value)) captured")
            capturedLabel.halign = .start
            capturedLabel.add(cssClass: "dim-label")
            capturedLabel.add(cssClass: "caption")
            body.append(child: capturedLabel)
        }

        let actions = Box(orientation: .horizontal, spacing: 6)
        disableButton.add(cssClass: "destructive-action")
        disableButton.add(cssClass: "flat")
        disableButton.visible = isOn
        actions.append(child: disableButton)
        let spacer = Label(str: "")
        spacer.hexpand = true
        actions.append(child: spacer)
        primaryButton.add(cssClass: "suggested-action")
        actions.append(child: primaryButton)
        body.append(child: actions)

        popover.set(child: body)
    }

    private func wireSignals() {
        primaryButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated { self?.commit() }
        }
        disableButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated { self?.disable() }
        }
    }

    private func commit() {
        let arming = ITraceArming(
            maxInvocations: Int(invocationsSpin.value),
            maxBytesPerInvocation: bytesStepper.value
        )
        onApply(arming)
        dismiss()
    }

    private func disable() {
        onApply(nil)
        dismiss()
    }

    private func dismiss() {
        popover.popdown()
        popover.unparent()
    }
}
