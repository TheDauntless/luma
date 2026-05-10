import Adw
import CGtk
import Foundation
import Gtk
import LumaCore

@MainActor
final class TracerITracePill {
    let widget: MenuButton

    var onArmingChanged: ((ITraceArming?) -> Void)?

    private let pillIcon: Gtk.Image
    private let pillLabel: Label
    private let popover: Popover
    private let invocationsSpin: SpinButton
    private let bytesStepper: BytesStepper
    private let capturedLabel: Label
    private let disableButton: Button
    private let primaryButton: Button
    private var arming: ITraceArming?
    private var captured: Int = 0

    init() {
        widget = MenuButton()
        pillIcon = Gtk.Image(iconName: "media-playback-start-symbolic")
        pillLabel = Label(str: "ITrace")
        popover = Popover()
        invocationsSpin = SpinButton(range: 1, max: 100, step: 1)
        bytesStepper = BytesStepper(
            value: ITraceArming.defaultMaxBytesPerInvocation,
            lowerBound: 256 * 1024,
            upperBound: 64 * 1024 * 1024,
            step: 256 * 1024
        )
        capturedLabel = Label(str: "")
        disableButton = Button(label: "Disable")
        primaryButton = Button(label: "Enable")

        installPillContent()
        installPopover()
        wireSignals()
        refresh()
    }

    func update(arming: ITraceArming?, captured: Int) {
        self.arming = arming
        self.captured = captured
        if !popover.visible {
            let seed = arming ?? ITraceArming()
            invocationsSpin.value = Double(seed.maxInvocations)
            bytesStepper.setValue(seed.maxBytesPerInvocation)
        }
        refresh()
    }

    private func installPillContent() {
        let content = Box(orientation: .horizontal, spacing: 4)
        pillIcon.pixelSize = 12
        content.append(child: pillIcon)
        pillLabel.add(cssClass: "caption")
        content.append(child: pillLabel)
        widget.set(child: content)
        widget.add(cssClass: "luma-itrace-pill")
        widget.add(cssClass: "flat")
        widget.set(popover: popover)
        widget.tooltipText = "Instruction trace caps"
    }

    private func installPopover() {
        let body = Box(orientation: .vertical, spacing: 12)
        body.marginStart = 14
        body.marginEnd = 14
        body.marginTop = 12
        body.marginBottom = 12

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

        capturedLabel.halign = .start
        capturedLabel.add(cssClass: "dim-label")
        capturedLabel.add(cssClass: "caption")
        body.append(child: capturedLabel)

        let actions = Box(orientation: .horizontal, spacing: 6)
        disableButton.add(cssClass: "destructive-action")
        disableButton.add(cssClass: "flat")
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
        invocationsSpin.onValueChanged { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshCapturedLabel() }
        }
        primaryButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated { self?.commitDrafts() }
        }
        disableButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated { self?.disable() }
        }
    }

    private func refresh() {
        let isOn = arming != nil
        if isOn {
            pillLabel.label = "ITrace \(captured) / \(arming!.maxInvocations)"
            widget.add(cssClass: "luma-itrace-pill-on")
            pillIcon.set(name: "media-record-symbolic")
            pillIcon.add(cssClass: "accent")
        } else {
            pillLabel.label = "ITrace"
            widget.remove(cssClass: "luma-itrace-pill-on")
            pillIcon.set(name: "media-playback-start-symbolic")
            pillIcon.remove(cssClass: "accent")
        }
        disableButton.visible = isOn
        primaryButton.label = isOn ? "Save caps" : "Enable"
        refreshCapturedLabel()
    }

    private func refreshCapturedLabel() {
        guard arming != nil else {
            capturedLabel.visible = false
            return
        }
        let limit = Int(invocationsSpin.value)
        capturedLabel.label = "\(captured) of \(limit) captured"
        capturedLabel.visible = true
    }

    private func commitDrafts() {
        let next = ITraceArming(
            maxInvocations: Int(invocationsSpin.value),
            maxBytesPerInvocation: bytesStepper.value
        )
        arming = next
        onArmingChanged?(next)
        popover.popdown()
    }

    private func disable() {
        arming = nil
        onArmingChanged?(nil)
        popover.popdown()
    }
}

@MainActor
final class BytesStepper {
    let widget: Box

    private(set) var value: Int
    private let lowerBound: Int
    private let upperBound: Int
    private let step: Int

    private let valueLabel: Label
    private let decreaseButton: Button
    private let increaseButton: Button

    init(value: Int, lowerBound: Int, upperBound: Int, step: Int) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.step = step
        self.value = clampToRange(value, lowerBound: lowerBound, upperBound: upperBound)

        widget = Box(orientation: .horizontal, spacing: 0)
        widget.add(cssClass: "linked")

        decreaseButton = Button()
        decreaseButton.set(iconName: "list-remove-symbolic")
        widget.append(child: decreaseButton)

        valueLabel = Label(str: "")
        valueLabel.add(cssClass: "monospace")
        valueLabel.add(cssClass: "numeric")
        valueLabel.setSizeRequest(width: 84, height: -1)
        let valueWrap = Box(orientation: .horizontal, spacing: 0)
        valueWrap.add(cssClass: "card")
        valueWrap.append(child: valueLabel)
        widget.append(child: valueWrap)

        increaseButton = Button()
        increaseButton.set(iconName: "list-add-symbolic")
        widget.append(child: increaseButton)

        decreaseButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated { self?.adjust(by: -1) }
        }
        increaseButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated { self?.adjust(by: 1) }
        }

        refresh()
    }

    func setValue(_ newValue: Int) {
        let clamped = clampToRange(newValue, lowerBound: lowerBound, upperBound: upperBound)
        guard clamped != value else { return }
        value = clamped
        refresh()
    }

    private func adjust(by direction: Int) {
        setValue(value + direction * step)
    }

    private func refresh() {
        valueLabel.label = ByteCountFormatter.string(
            fromByteCount: Int64(value),
            countStyle: .memory
        )
        decreaseButton.sensitive = value > lowerBound
        increaseButton.sensitive = value < upperBound
    }
}

private func clampToRange(_ value: Int, lowerBound: Int, upperBound: Int) -> Int {
    if value < lowerBound { return lowerBound }
    if value > upperBound { return upperBound }
    return value
}
