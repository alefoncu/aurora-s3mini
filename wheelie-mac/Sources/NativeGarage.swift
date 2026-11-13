import Cocoa

/// The garage library uses a source-list table, preserving native keyboard
/// selection, accessibility and the user's light/dark appearance.
final class GarageSidebarController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let table = NSTableView()
    private var selectedKind: BikeKind
    private let onSelect: (BikeKind) -> Void
    private let lockText: (BikeKind) -> String?
    private var synchronizing = false

    init(kind: BikeKind, lockText: @escaping (BikeKind) -> String? = { _ in nil }, onSelect: @escaping (BikeKind) -> Void) {
        selectedKind = kind
        self.onSelect = onSelect
        self.lockText = lockText
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let background = NSVisualEffectView()
        background.material = .sidebar
        background.blendingMode = .behindWindow
        background.state = .followsWindowActiveState
        view = background
        let heading = NSTextField(labelWithString: "Vehículos")
        heading.font = .systemFont(ofSize: 13, weight: .semibold)
        heading.textColor = .secondaryLabelColor
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("vehicle"))
        table.addTableColumn(column)
        table.headerView = nil
        table.backgroundColor = .clear
        table.style = .sourceList
        table.rowHeight = 60
        table.intercellSpacing = NSSize(width: 0, height: 3)
        table.allowsEmptySelection = false
        table.allowsMultipleSelection = false
        table.focusRingType = .none
        table.dataSource = self
        table.delegate = self
        table.setAccessibilityLabel("Vehículos del taller")
        scroll.documentView = table
        let footer = NSTextField(wrappingLabelWithString: "Selecciona un vehículo para preparar tu próxima salida.")
        footer.font = .systemFont(ofSize: 11)
        footer.textColor = .tertiaryLabelColor
        for child in [heading, scroll, footer] { child.translatesAutoresizingMaskIntoConstraints = false; background.addSubview(child) }
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 20),
            heading.topAnchor.constraint(equalTo: background.topAnchor, constant: 22),
            heading.trailingAnchor.constraint(lessThanOrEqualTo: background.trailingAnchor, constant: -16),
            scroll.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -8),
            scroll.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -16),
            footer.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 20),
            footer.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -20),
            footer.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -20)
        ])
        // Source-list reloads may auto-select the first row when an empty
        // selection is disallowed. Never publish that transient selection.
        synchronizing = true
        table.reloadData()
        table.selectRowIndexes(IndexSet(integer: BikeKind.allCases.firstIndex(of: selectedKind) ?? 0), byExtendingSelection: false)
        synchronizing = false
    }
    /// Refresh lock labels after coins are spent or earned.
    func reload() {
        guard isViewLoaded else { return }
        synchronizing = true
        table.reloadData()
        table.selectRowIndexes(IndexSet(integer: BikeKind.allCases.firstIndex(of: selectedKind) ?? 0), byExtendingSelection: false)
        synchronizing = false
    }
    func sync(kind: BikeKind) {
        selectedKind = kind
        guard isViewLoaded else { return }
        let index = BikeKind.allCases.firstIndex(of: kind) ?? 0
        guard table.selectedRow != index else { return }
        synchronizing = true
        table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        synchronizing = false
    }
    func numberOfRows(in tableView: NSTableView) -> Int { BikeKind.allCases.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard BikeKind.allCases.indices.contains(row) else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("GarageVehicleCell")
        let cell = (tableView.makeView(withIdentifier: identifier, owner: self) as? GarageVehicleCell) ?? GarageVehicleCell()
        cell.identifier = identifier
        let kind = BikeKind.allCases[row]
        cell.configure(title: kind.title, subtitle: lockText(kind).map { "🔒 " + $0 } ?? kind.subtitle, symbol: kind == .bmx ? "bicycle" : "motorcycle")
        return cell
    }
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !synchronizing, BikeKind.allCases.indices.contains(table.selectedRow) else { return }
        let kind = BikeKind.allCases[table.selectedRow]
        guard selectedKind != kind else { return }
        selectedKind = kind
        onSelect(kind)
    }
}

private final class GarageVehicleCell: NSTableCellView {
    private let subtitle = NSTextField(labelWithString: "")
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let title = NSTextField(labelWithString: "")
        title.font = .systemFont(ofSize: 13, weight: .medium)
        title.lineBreakMode = .byTruncatingTail
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.lineBreakMode = .byTruncatingTail
        let icon = NSImageView()
        icon.imageScaling = .scaleProportionallyDown
        imageView = icon; textField = title
        for child in [icon, title, subtitle] { child.translatesAutoresizingMaskIntoConstraints = false; addSubview(child) }
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 25), icon.heightAnchor.constraint(equalToConstant: 25),
            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 11),
            title.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 3),
            subtitle.trailingAnchor.constraint(equalTo: title.trailingAnchor)
        ])
        updateColors()
    }
    required init?(coder: NSCoder) { nil }
    func configure(title: String, subtitle: String, symbol: String) {
        textField?.stringValue = title
        self.subtitle.stringValue = subtitle
        imageView?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            ?? NSImage(systemSymbolName: "bicycle", accessibilityDescription: title)
        setAccessibilityLabel("\(title), \(subtitle)")
    }
    override var backgroundStyle: NSView.BackgroundStyle { didSet { updateColors() } }
    private func updateColors() {
        let selected = backgroundStyle == .emphasized
        textField?.textColor = selected ? .alternateSelectedControlTextColor : .labelColor
        subtitle.textColor = selected ? NSColor.alternateSelectedControlTextColor.withAlphaComponent(0.78) : .secondaryLabelColor
        imageView?.contentTintColor = selected ? .alternateSelectedControlTextColor : .secondaryLabelColor
    }
}

/// A scrollable, native inspector. Changes flow into RideView's existing model;
/// refresh() only reads it and never calls the change callback.
final class GarageInspectorController: NSViewController {
    private unowned let game: RideView
    private let onPlay: () -> Void
    private let onChange: () -> Void
    private var updating = false
    private var routePopup: NSPopUpButton!
    private var nightSwitch: NSSwitch!
    private var transmissionPopup: NSPopUpButton!
    private var transmissionHint: NSTextField!
    private var stiffnessSlider: NSSlider!, dampingSlider: NSSlider!
    private var stiffnessValue: NSTextField!, dampingValue: NSTextField!
    private var challengePopup: NSPopUpButton!
    private var challengeDetail: NSTextField!
    private var ghostCheckbox: NSButton!
    private var wells: [String: NSColorWell] = [:]
    private var options: [String: NSButton] = [:]
    private var distanceLabel: NSTextField!, wheelieLabel: NSTextField!, stoppieLabel: NSTextField!, scoreLabel: NSTextField!
    private var walletLabel: NSTextField!, unlockButton: NSButton!, unlockHint: NSTextField!
    private var missionLabels: [NSTextField] = []
    private var rivalPopup: NSPopUpButton!, rivalSameCheckbox: NSButton!
    private var difficultyPopup: NSPopUpButton!, difficultyHint: NSTextField!
    private var helmetPopup: NSPopUpButton!, jacketPopup: NSPopUpButton!, liveryPopup: NSPopUpButton!
    private static let routeTitles = ["Valle · asfalto", "Sierra · tierra", "Dunas · atardecer", "Nieve · hielo y pinos", "Ciudad · lluvia"]
    private var playButton: NSButton!
    private var outfitLabel: NSTextField!
    private var editableControls: [NSControl] = []

    init(game: RideView, onPlay: @escaping () -> Void, onChange: @escaping () -> Void) {
        self.game = game; self.onPlay = onPlay; self.onChange = onChange
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { nil }
    override func loadView() {
        let background = NSVisualEffectView()
        background.material = .underWindowBackground
        background.blendingMode = .withinWindow
        background.state = .followsWindowActiveState
        view = background
        let heading = NSTextField(labelWithString: "Ajustes de salida")
        heading.font = .systemFont(ofSize: 15, weight: .semibold)
        let separator = NSBox(); separator.boxType = .separator
        let scroll = NSScrollView(); scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        let document = FlippedGarageDocumentView()
        scroll.documentView = document
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        document.addSubview(stack); stack.translatesAutoresizingMaskIntoConstraints = false
        document.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -22)
        ])
        addSection("MONEDAS", to: stack)
        walletLabel = metricLabel()
        addFullWidth(labeledRow("Saldo", control: walletLabel), to: stack)
        unlockButton = NSButton(title: "Desbloquear", target: self, action: #selector(unlockSelection))
        unlockButton.bezelStyle = .rounded; unlockButton.bezelColor = .controlAccentColor
        addFullWidth(unlockButton, to: stack)
        unlockHint = NSTextField(wrappingLabelWithString: "")
        unlockHint.font = .systemFont(ofSize: 11); unlockHint.textColor = .secondaryLabelColor
        addFullWidth(unlockHint, to: stack)
        addDivider(to: stack)
        addSection("MISIONES", to: stack)
        for _ in 0..<4 {
            let label = NSTextField(wrappingLabelWithString: "")
            label.font = .systemFont(ofSize: 11); label.textColor = .labelColor
            missionLabels.append(label); addFullWidth(label, to: stack)
        }
        let statsButton = NSButton(title: "Estadísticas y logros…", target: self, action: #selector(showStats))
        statsButton.bezelStyle = .rounded; addFullWidth(statsButton, to: stack)
        addDivider(to: stack)
        addSection("RUTA", to: stack)
        routePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        routePopup.addItems(withTitles: Self.routeTitles)
        let progression = NSTextField(wrappingLabelWithString: "1.200 m · cuatro tramos de dificultad creciente. El relieve se vuelve más exigente cada 300 m; los conos opcionales aparecen con mayor frecuencia.")
        progression.font = .systemFont(ofSize: 11); progression.textColor = .secondaryLabelColor
        addFullWidth(progression, to: stack)
        routePopup.target = self; routePopup.action = #selector(routeChanged(_:)); routePopup.setAccessibilityLabel("Ruta")
        editableControls.append(routePopup); addFullWidth(routePopup, to: stack)
        nightSwitch = NSSwitch(); nightSwitch.target = self; nightSwitch.action = #selector(nightChanged(_:)); nightSwitch.setAccessibilityLabel("Noche")
        editableControls.append(nightSwitch); addFullWidth(labeledRow("Noche", control: nightSwitch), to: stack)
        addDivider(to: stack)
        addSection("CONDUCCIÓN", to: stack)
        transmissionPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        transmissionPopup.addItems(withTitles: ["Cambio automático", "Cambio manual"])
        transmissionPopup.target = self; transmissionPopup.action = #selector(transmissionChanged(_:))
        transmissionPopup.setAccessibilityLabel("Cambio de marchas")
        editableControls.append(transmissionPopup); addFullWidth(transmissionPopup, to: stack)
        transmissionHint = NSTextField(wrappingLabelWithString: "")
        transmissionHint.font = .systemFont(ofSize: 11); transmissionHint.textColor = .secondaryLabelColor
        addFullWidth(transmissionHint, to: stack)
        difficultyPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        difficultyPopup.addItems(withTitles: BikePhysics.Assist.allCases.map { "Dificultad: " + $0.title })
        difficultyPopup.target = self; difficultyPopup.action = #selector(difficultyChanged(_:)); difficultyPopup.setAccessibilityLabel("Dificultad")
        editableControls.append(difficultyPopup); addFullWidth(difficultyPopup, to: stack)
        difficultyHint = NSTextField(wrappingLabelWithString: "")
        difficultyHint.font = .systemFont(ofSize: 11); difficultyHint.textColor = .secondaryLabelColor
        addFullWidth(difficultyHint, to: stack)
        stiffnessSlider = NSSlider(value: 1, minValue: 0.65, maxValue: 1.45, target: self, action: #selector(suspensionChanged(_:)))
        dampingSlider = NSSlider(value: 1, minValue: 0.6, maxValue: 1.6, target: self, action: #selector(suspensionChanged(_:)))
        stiffnessValue = metricLabel(); dampingValue = metricLabel()
        for (title, slider, value) in [("Dureza", stiffnessSlider!, stiffnessValue!), ("Amortiguación", dampingSlider!, dampingValue!)] {
            slider.isContinuous = true; slider.setAccessibilityLabel(title + " de suspensión")
            editableControls.append(slider)
            addFullWidth(labeledRow(title, control: value), to: stack)
            addFullWidth(slider, to: stack)
        }
        let restore = NSButton(title: "Restaurar suspensión", target: self, action: #selector(restoreSuspension))
        restore.bezelStyle = .rounded; editableControls.append(restore); addFullWidth(restore, to: stack)
        let suspensionHint = NSTextField(wrappingLabelWithString: "Ajustes propios de cada vehículo. Una suspensión blanda absorbe mejor los baches; una dura reduce el hundimiento. La amortiguación controla el rebote.")
        suspensionHint.font = .systemFont(ofSize: 11); suspensionHint.textColor = .secondaryLabelColor
        addFullWidth(suspensionHint, to: stack)
        addDivider(to: stack)
        addSection("RETO", to: stack)
        challengePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        challengePopup.addItems(withTitles: RideChallengeKind.allCases.map(\.title))
        challengePopup.target = self; challengePopup.action = #selector(challengeChanged(_:))
        challengePopup.setAccessibilityLabel("Reto de la partida")
        editableControls.append(challengePopup); addFullWidth(challengePopup, to: stack)
        challengeDetail = NSTextField(wrappingLabelWithString: "")
        challengeDetail.font = .systemFont(ofSize: 11); challengeDetail.textColor = .secondaryLabelColor
        addFullWidth(challengeDetail, to: stack)
        rivalPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        rivalPopup.addItems(withTitles: RivalLevel.allCases.map(\.title))
        rivalPopup.target = self; rivalPopup.action = #selector(rivalLevelChanged(_:)); rivalPopup.setAccessibilityLabel("Nivel del rival")
        editableControls.append(rivalPopup); addFullWidth(rivalPopup, to: stack)
        rivalSameCheckbox = NSButton(checkboxWithTitle: "El rival usa mi mismo vehículo", target: self, action: #selector(rivalSameChanged(_:)))
        editableControls.append(rivalSameCheckbox); addFullWidth(rivalSameCheckbox, to: stack)
        ghostCheckbox = NSButton(checkboxWithTitle: "Mostrar mi mejor recorrido", target: self, action: #selector(ghostChanged(_:)))
        ghostCheckbox.setAccessibilityHelp("El fantasma aparece después de completar una ruta; compites contra tu mejor tiempo con estos ajustes.")
        editableControls.append(ghostCheckbox); addFullWidth(ghostCheckbox, to: stack)
        addDivider(to: stack)
        addSection("APARIENCIA", to: stack)
        for (title, key) in [("Moto", "body"), ("Chaqueta", "jacket"), ("Casco", "helmetColor"), ("Piel", "skin")] {
            let well = NSColorWell(frame: .zero)
            well.target = self; well.action = #selector(colorChanged(_:)); well.identifier = NSUserInterfaceItemIdentifier(key)
            well.controlSize = .small; well.setAccessibilityLabel("Color de \(title.lowercased())")
            well.widthAnchor.constraint(equalToConstant: 50).isActive = true; well.heightAnchor.constraint(equalToConstant: 23).isActive = true
            wells[key] = well; editableControls.append(well)
            addFullWidth(labeledRow(title, control: well), to: stack)
        }
        addDivider(to: stack)
        addSection("ESTILO (CON MONEDAS)", to: stack)
        helmetPopup = NSPopUpButton(frame: .zero, pullsDown: false); helmetPopup.addItems(withTitles: HelmetStyle.allCases.map(\.title))
        jacketPopup = NSPopUpButton(frame: .zero, pullsDown: false); jacketPopup.addItems(withTitles: JacketStyle.allCases.map(\.title))
        liveryPopup = NSPopUpButton(frame: .zero, pullsDown: false); liveryPopup.addItems(withTitles: Livery.allCases.map(\.title))
        for (title, popup, action) in [("Casco", helmetPopup!, #selector(helmetChanged(_:))), ("Chaqueta", jacketPopup!, #selector(jacketChanged(_:))), ("Moto", liveryPopup!, #selector(liveryChanged(_:)))] {
            popup.target = self; popup.action = action; popup.setAccessibilityLabel("Estilo de \(title.lowercased())")
            editableControls.append(popup); addFullWidth(labeledRow(title, control: popup), to: stack)
        }
        let styleHint = NSTextField(wrappingLabelWithString: "Los colores base son gratis. Los estilos extra se compran con monedas y se ven en la vista previa; para rodar tienes que tener el estilo elegido.")
        styleHint.font = .systemFont(ofSize: 11); styleHint.textColor = .secondaryLabelColor
        addFullWidth(styleHint, to: stack)
        addDivider(to: stack)
        addSection("PILOTO Y CIRCUITO", to: stack)
        outfitLabel = NSTextField(wrappingLabelWithString: game.bike.kind.outfitDescription)
        outfitLabel.font = .systemFont(ofSize: 11)
        outfitLabel.textColor = .secondaryLabelColor
        addFullWidth(outfitLabel, to: stack)
        for (title, key) in [("Usar casco", "helmet"), ("Llevar acompañante", "passenger"), ("Obstáculos y charcos", "obstacles"), ("Frenos ABS", "abs")] {
            let checkbox = NSButton(checkboxWithTitle: title, target: self, action: #selector(optionChanged(_:)))
            checkbox.font = .systemFont(ofSize: 12); checkbox.identifier = NSUserInterfaceItemIdentifier(key)
            options[key] = checkbox; editableControls.append(checkbox); addFullWidth(checkbox, to: stack)
        }
        addDivider(to: stack)
        addSection("RÉCORD EN ESTA RUTA", to: stack)
        distanceLabel = metricLabel(); wheelieLabel = metricLabel(); stoppieLabel = metricLabel(); scoreLabel = metricLabel()
        addFullWidth(labeledRow("Distancia", control: distanceLabel), to: stack)
        addFullWidth(labeledRow("Caballito", control: wheelieLabel), to: stack)
        addFullWidth(labeledRow("Invertido", control: stoppieLabel), to: stack)
        addFullWidth(labeledRow("Puntos", control: scoreLabel), to: stack)
        let hint = NSTextField(wrappingLabelWithString: "Los ajustes se guardan automáticamente.")
        hint.font = .systemFont(ofSize: 11); hint.textColor = .tertiaryLabelColor
        addFullWidth(hint, to: stack)
        playButton = NSButton(title: "Rodar", target: self, action: #selector(play))
        playButton.bezelStyle = .rounded; playButton.controlSize = .large; playButton.keyEquivalent = "\r"
        playButton.bezelColor = .controlAccentColor
        playButton.setAccessibilityHelp("Comenzar con el vehículo y la ruta seleccionados")
        for child in [heading, separator, scroll, playButton!] { child.translatesAutoresizingMaskIntoConstraints = false; background.addSubview(child) }
        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: background.topAnchor, constant: 22),
            heading.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 18),
            heading.trailingAnchor.constraint(lessThanOrEqualTo: background.trailingAnchor, constant: -18),
            separator.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 18),
            separator.leadingAnchor.constraint(equalTo: background.leadingAnchor), separator.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 1),
            scroll.leadingAnchor.constraint(equalTo: background.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: playButton.topAnchor, constant: -16),
            playButton.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 18),
            playButton.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -18),
            playButton.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -18),
            playButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ])
        refresh()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        refresh()
    }
    private func metricLabel() -> NSTextField {
        let field = NSTextField(labelWithString: "—")
        field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        field.alignment = .right
        return field
    }
    private func addSection(_ title: String, to stack: NSStackView) {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 10, weight: .semibold); label.textColor = .secondaryLabelColor
        addFullWidth(label, to: stack)
    }
    private func addDivider(to stack: NSStackView) {
        let divider = NSBox(); divider.boxType = .separator
        addFullWidth(divider, to: stack)
    }
    private func addFullWidth(_ child: NSView, to stack: NSStackView) {
        child.translatesAutoresizingMaskIntoConstraints = false; stack.addArrangedSubview(child)
        child.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }
    private func labeledRow(_ title: String, control: NSView) -> NSView {
        let row = NSView(); let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false; control.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(label); row.addSubview(control)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor), label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            control.trailingAnchor.constraint(equalTo: row.trailingAnchor), control.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: control.leadingAnchor, constant: -10),
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 25),
            row.heightAnchor.constraint(greaterThanOrEqualTo: control.heightAnchor)
        ])
        control.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return row
    }
    func endEditing() {
        wells.values.forEach { $0.deactivate() }
        NSColorPanel.shared.orderOut(nil)
    }
    func refresh() {
        guard isViewLoaded else { return }
        updating = true
        defer { updating = false }
        for (i, title) in Self.routeTitles.enumerated() {
            let item = RideUnlock.route(i)
            routePopup.item(at: i)?.title = game.progress.isUnlocked(item) ? title : "\(title) · 🔒 \(item.cost)"
        }
        routePopup.selectItem(at: max(0, min(BikePhysics.routeCount - 1, game.bike.route)))
        func lockText(_ item: RideUnlock, _ title: String) -> String { game.progress.isUnlocked(item) ? title : "\(title) · 🔒 \(item.cost)" }
        for (i, style) in HelmetStyle.allCases.enumerated() { helmetPopup.item(at: i)?.title = lockText(.helmet(style), style.title) }
        for (i, style) in JacketStyle.allCases.enumerated() { jacketPopup.item(at: i)?.title = lockText(.jacket(style), style.title) }
        for (i, style) in Livery.allCases.enumerated() { liveryPopup.item(at: i)?.title = lockText(.livery(style), style.title) }
        helmetPopup.selectItem(at: game.art.helmetStyle.rawValue); jacketPopup.selectItem(at: game.art.jacketStyle.rawValue); liveryPopup.selectItem(at: game.art.livery.rawValue)
        let locked = lockedItems()
        walletLabel.stringValue = "\(game.progress.wallet) monedas"
        unlockButton.isHidden = locked.isEmpty; unlockHint.isHidden = locked.isEmpty
        if !locked.isEmpty {
            let cost = locked.reduce(0) { $0 + $1.cost }
            unlockButton.title = "Desbloquear \(locked.map(\.title).joined(separator: " y ")) · \(cost)"
            unlockButton.isEnabled = game.mode == .garage && game.progress.wallet >= cost
            unlockHint.stringValue = game.progress.wallet >= cost ? "Gasta monedas para usar esta selección." : "Te faltan \(cost - game.progress.wallet) monedas. Se ganan al rodar: 1 cada 80 m y 1 por cada 200 puntos."
        }
        nightSwitch.state = game.night ? .on : .off
        transmissionPopup.selectItem(at: game.bike.transmission.automatic ? 0 : 1)
        transmissionHint.stringValue = game.bike.kind == .bmx ? "La BMX conserva su desarrollo fijo y rueda libre." : game.bike.kind == .scooter ? "El scooter ajusta su transmisión automáticamente." : "Manual: Q baja marcha y F sube marcha. También puedes usar la Touch Bar."
        stiffnessSlider.doubleValue = game.bike.suspensionStiffness
        dampingSlider.doubleValue = game.bike.suspensionDamping
        stiffnessValue.stringValue = "\(Int((game.bike.suspensionStiffness * 100).rounded())) %"
        dampingValue.stringValue = "\(Int((game.bike.suspensionDamping * 100).rounded())) %"
        challengePopup.selectItem(at: RideChallengeKind.allCases.firstIndex(of: game.challengeKind) ?? 0)
        challengeDetail.stringValue = game.challengeKind.detail
        ghostCheckbox.state = game.ghostEnabled ? .on : .off
        rivalPopup.selectItem(at: game.rivalLevel.rawValue)
        difficultyPopup.selectItem(at: game.difficulty.rawValue); difficultyHint.stringValue = game.difficulty.detail
        rivalSameCheckbox.state = game.rivalSameVehicle ? .on : .off
        game.missions.refresh()
        for (i, mission) in game.missions.daily.enumerated() {
            let done = game.missions.isDone(daily: i)
            missionLabels[i].stringValue = "\(done ? "✓" : "○") \(mission.title) · \(min(Int(game.missions.progress(daily: i)), mission.target))/\(mission.target) · +\(mission.reward)"
        }
        let week = game.missions.weekly
        missionLabels[3].stringValue = "\(game.missions.weeklyDone ? "✓" : "★") Semanal: \(week.title) · \(min(Int(game.missions.weeklyProgress), week.target))/\(week.target) · +\(week.reward)"
        wells["body"]?.color = game.art.body; wells["jacket"]?.color = game.art.jacket
        wells["helmetColor"]?.color = game.art.helmet; wells["skin"]?.color = game.art.skin
        outfitLabel.stringValue = game.bike.kind.outfitDescription
        options["helmet"]?.state = game.art.helmetOn ? .on : .off
        options["passenger"]?.state = game.art.passenger ? .on : .off
        options["obstacles"]?.state = game.obstacles ? .on : .off
        options["abs"]?.state = game.absOn ? .on : .off
        scoreLabel.stringValue = "\(Int(game.bestScore))"
        distanceLabel.stringValue = "\(Int(game.record)) m"; wheelieLabel.stringValue = "\(Int(game.best)) m"; stoppieLabel.stringValue = String(format:"%.1f m",game.bestStoppie)
        let canEdit = game.mode == .garage
        editableControls.forEach { $0.isEnabled = canEdit }
        rivalPopup.isEnabled = canEdit && game.challengeKind == .race
        rivalSameCheckbox.isEnabled = canEdit && game.challengeKind == .race
        transmissionPopup.isEnabled = canEdit && game.bike.kind != .bmx && game.bike.kind != .scooter
        options["passenger"]?.isEnabled = canEdit && game.bike.kind.supportsPassenger
        playButton.isEnabled = canEdit && locked.isEmpty
    }
    // Hooks that drive the real controls (popups, checkboxes, buttons) for the automated UI flow test.
    func uiSelectRoute(_ index: Int) { routePopup.selectItem(at: index); routeChanged(routePopup) }
    func uiSelectChallenge(_ kind: RideChallengeKind) { challengePopup.selectItem(at: RideChallengeKind.allCases.firstIndex(of: kind) ?? 0); challengeChanged(challengePopup) }
    func uiSelectRival(_ level: RivalLevel) { rivalPopup.selectItem(at: level.rawValue); rivalLevelChanged(rivalPopup) }
    func uiToggle(_ key: String) { guard let b = options[key] else { return }; b.state = b.state == .on ? .off : .on; optionChanged(b) }
    func uiToggleRivalVehicle() { rivalSameCheckbox.state = rivalSameCheckbox.state == .on ? .off : .on; rivalSameChanged(rivalSameCheckbox) }
    func uiUnlock() { unlockSelection() }
    func uiPlay() { play() }
    var uiPlayEnabled: Bool { playButton.isEnabled }
    var uiUnlockVisible: Bool { !unlockButton.isHidden }
    var uiUnlockEnabled: Bool { unlockButton.isEnabled }
    var uiUnlockTitle: String { unlockButton.title }
    var uiWalletText: String { walletLabel.stringValue }
    var uiMissionTexts: [String] { missionLabels.map(\.stringValue) }
    var uiRivalEnabled: Bool { rivalPopup.isEnabled && rivalSameCheckbox.isEnabled }
    private func lockedItems() -> [RideUnlock] {
        ([RideUnlock.vehicle(game.bike.kind), RideUnlock.route(game.bike.route)] + game.cosmeticItems).filter { !game.progress.isUnlocked($0) }
    }
    @objc private func unlockSelection() {
        guard game.mode == .garage else { return }
        let items = lockedItems(), cost = items.reduce(0) { $0 + $1.cost }
        guard game.progress.wallet >= cost else { game.audio.play(.denied); NSSound.beep(); return }
        items.forEach { game.progress.unlock($0) }
        game.audio.play(.coin)
        onChange()
    }
    @objc private func transmissionChanged(_ sender: NSPopUpButton) {
        guard !updating, game.mode == .garage, game.bike.kind != .bmx, game.bike.kind != .scooter else { return }
        game.bike.transmission.automatic = sender.indexOfSelectedItem == 0
        game.prefs.set(game.bike.transmission.automatic, forKey: "automatic")
        game.bike.reset(); game.needsDisplay = true; onChange()
    }
    @objc private func suspensionChanged(_ sender: NSSlider) {
        guard !updating, game.mode == .garage else { return }
        game.bike.suspensionStiffness = stiffnessSlider.doubleValue
        game.bike.suspensionDamping = dampingSlider.doubleValue
        persistSuspension()
    }
    @objc private func restoreSuspension() {
        guard !updating, game.mode == .garage else { return }
        game.bike.suspensionStiffness = 1; game.bike.suspensionDamping = 1
        persistSuspension()
    }
    private func persistSuspension() {
        let prefix = "suspension." + game.bike.kind.rawValue
        game.prefs.set(game.bike.suspensionStiffness, forKey: prefix + ".stiffness")
        game.prefs.set(game.bike.suspensionDamping, forKey: prefix + ".damping")
        game.bike.reset(); game.needsDisplay = true; onChange()
    }
    @objc private func challengeChanged(_ sender: NSPopUpButton) {
        guard !updating, game.mode == .garage, RideChallengeKind.allCases.indices.contains(sender.indexOfSelectedItem) else { return }
        game.challengeKind = RideChallengeKind.allCases[sender.indexOfSelectedItem]
        game.prefs.set(game.challengeKind.rawValue, forKey: "challenge"); onChange()
    }
    @objc private func ghostChanged(_ sender: NSButton) {
        guard !updating, game.mode == .garage else { return }
        game.ghostEnabled = sender.state == .on
        game.prefs.set(game.ghostEnabled, forKey: "ghost"); onChange()
    }
    @objc private func helmetChanged(_ sender: NSPopUpButton) {
        guard !updating, game.mode == .garage, let style = HelmetStyle(rawValue: sender.indexOfSelectedItem) else { return }
        game.art.helmetStyle = style; game.prefs.set(style.rawValue, forKey: "helmetStyle"); onChange()
    }
    @objc private func jacketChanged(_ sender: NSPopUpButton) {
        guard !updating, game.mode == .garage, let style = JacketStyle(rawValue: sender.indexOfSelectedItem) else { return }
        game.art.jacketStyle = style; game.prefs.set(style.rawValue, forKey: "jacketStyle"); onChange()
    }
    @objc private func liveryChanged(_ sender: NSPopUpButton) {
        guard !updating, game.mode == .garage, let style = Livery(rawValue: sender.indexOfSelectedItem) else { return }
        game.art.livery = style; game.prefs.set(style.rawValue, forKey: "livery"); onChange()
    }
    func uiSelectHelmet(_ style: HelmetStyle) { helmetPopup.selectItem(at: style.rawValue); helmetChanged(helmetPopup) }
    func uiSelectJacket(_ style: JacketStyle) { jacketPopup.selectItem(at: style.rawValue); jacketChanged(jacketPopup) }
    func uiSelectLivery(_ style: Livery) { liveryPopup.selectItem(at: style.rawValue); liveryChanged(liveryPopup) }
    @objc private func difficultyChanged(_ sender: NSPopUpButton) {
        guard !updating, game.mode == .garage, let level = BikePhysics.Assist(rawValue: sender.indexOfSelectedItem) else { return }
        game.difficulty = level; game.prefs.set(level.rawValue, forKey: "difficulty"); game.bike.assist = level; game.loadRecords(); onChange()
    }
    func uiSelectDifficulty(_ level: BikePhysics.Assist) { difficultyPopup.selectItem(at: level.rawValue); difficultyChanged(difficultyPopup) }
    @objc private func rivalLevelChanged(_ sender: NSPopUpButton) {
        guard !updating, game.mode == .garage, let level = RivalLevel(rawValue: sender.indexOfSelectedItem) else { return }
        game.rivalLevel = level; game.prefs.set(level.rawValue, forKey: "rivalLevel"); onChange()
    }
    @objc private func rivalSameChanged(_ sender: NSButton) {
        guard !updating, game.mode == .garage else { return }
        game.rivalSameVehicle = sender.state == .on; game.prefs.set(game.rivalSameVehicle, forKey: "rivalSame"); onChange()
    }
    /// Lifetime statistics and the achievement list, shown as a sheet.
    var statsText: String {
        let earned = game.stats.earned
        let lines = RideAchievement.all.map { "\(earned.contains($0.id) ? "✓" : "○") \($0.title) — \($0.detail)" }
        return (game.stats.summary + ["", "LOGROS (\(earned.count)/\(RideAchievement.all.count))"] + lines).joined(separator: "\n")
    }
    @objc private func showStats() {
        guard let window = view.window, window.attachedSheet == nil else { return }
        let alert = NSAlert()
        alert.messageText = "Estadísticas y logros"; alert.informativeText = statsText
        alert.addButton(withTitle: "Cerrar")
        alert.beginSheetModal(for: window) { _ in }
    }
    @objc private func play() { guard game.mode == .garage else { return }; onPlay() }
    @objc private func routeChanged(_ sender: NSPopUpButton) {
        guard !updating, game.mode == .garage else { return }
        game.bike.route = max(0, min(BikePhysics.routeCount - 1, sender.indexOfSelectedItem))
        game.prefs.set(game.bike.route, forKey: "route"); game.cameraY = 0; game.loadRecords(); onChange()
    }
    @objc private func nightChanged(_ sender: NSSwitch) {
        guard !updating, game.mode == .garage else { return }
        game.night = sender.state == .on; game.prefs.set(game.night, forKey: "night"); onChange()
    }
    @objc private func colorChanged(_ sender: NSColorWell) {
        guard !updating, game.mode == .garage, let key = sender.identifier?.rawValue else { return }
        switch key {
        case "jacket": game.art.jacket = sender.color
        case "helmetColor": game.art.helmet = sender.color
        case "skin": game.art.skin = sender.color
        default: game.art.body = sender.color
        }
        game.saveColor(sender.color, key); onChange()
    }
    @objc private func optionChanged(_ sender: NSButton) {
        guard !updating, game.mode == .garage, let key = sender.identifier?.rawValue else { return }
        let value = sender.state == .on
        switch key { case "helmet": game.art.helmetOn = value; case "passenger": game.art.passenger = value; case "abs": game.absOn = value; game.loadRecords(); default: game.obstacles = value }
        game.prefs.set(value, forKey: key); onChange()
    }
}

private final class FlippedGarageDocumentView: NSView {
    override var isFlipped: Bool { true }
}
