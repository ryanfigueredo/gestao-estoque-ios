import SwiftUI

struct ProductScanScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var bt = RfidBluetoothManager.shared
    @State private var scanInput = ""
    @State private var scannedItems: [ScannedItem] = []
    @State private var showDeviceList = false
    @FocusState private var scanFieldFocused: Bool
    private let api = ApiClient.shared

    struct ScannedItem: Identifiable {
        let id = UUID()
        let tag: String
        let product: Product?
        let scannedAt: Date
    }

    var foundCount: Int { scannedItems.filter { $0.product != nil }.count }
    var unknownCount: Int { scannedItems.filter { $0.product == nil }.count }

    var body: some View {
        VStack(spacing: 0) {
            // Status da conexão Bluetooth
            connectionCard

            // Instruções
            VStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.primary)
                Text("Auditoria RFID")
                    .font(.system(size: AppTheme.FontSize.title2, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(bt.isConnected
                     ? "Aponte o leitor para as tags. As leituras aparecem automaticamente."
                     : "Conecte o leitor acima ou use o campo abaixo (leitor em modo teclado).")
                    .font(.system(size: AppTheme.FontSize.caption))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(AppTheme.Spacing.lg)
            .frame(maxWidth: .infinity)
            .background(AppTheme.surface)

            // Digitar/colar EPC manualmente ou leitor em modo teclado
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Digitar ou colar código")
                    .font(.system(size: AppTheme.FontSize.footnote, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Digite/cole o EPC e toque em \"Ler\" para consultar. Ou use leitor em modo teclado (ele digita aqui e envia Enter).")
                    .font(.system(size: AppTheme.FontSize.caption))
                    .foregroundStyle(AppTheme.textTertiary)
                HStack(spacing: AppTheme.Spacing.sm) {
                    TextField("Ex: E20012345678901234567890", text: $scanInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .focused($scanFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { didTapLer() }
                    Button { didTapLer() } label: {
                        Text("Ler")
                            .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 56, minHeight: 44)
                            .background(scanInput.trimmingCharacters(in: .whitespaces).isEmpty ? AppTheme.textTertiary : AppTheme.primary)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                    }
                    .disabled(scanInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    .animation(.easeInOut(duration: 0.2), value: scanInput.isEmpty)
                }
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.surface)

            // Resumo
            HStack(spacing: AppTheme.Spacing.lg) {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.success)
                    Text("\(foundCount) encontrados")
                        .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                HStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.error)
                    Text("\(unknownCount) invasores")
                        .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(AppTheme.surfaceSecondary)

            // Lista do que foi escaneado
            List {
                ForEach(scannedItems.reversed()) { item in
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: item.product != nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundStyle(item.product != nil ? AppTheme.success : AppTheme.error)
                        VStack(alignment: .leading, spacing: 2) {
                            if let p = item.product {
                                Text(p.name)
                                    .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                if let sku = p.sku { Text("SKU: \(sku)").font(.caption).foregroundStyle(AppTheme.textSecondary) }
                            } else {
                                Text("Invasor – tag não cadastrada")
                                    .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                                    .foregroundStyle(AppTheme.error)
                                Text(item.tag)
                                    .font(.system(size: AppTheme.FontSize.caption, design: .monospaced))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .listRowBackground(item.product == nil ? AppTheme.error.opacity(0.12) : nil)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
            .listStyle(.plain)
        }
        .background(AppTheme.background)
        .navigationTitle("Escanear RFID")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fechar") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Limpar") {
                    scannedItems.removeAll()
                    scanInput = ""
                }
            }
        }
        .sheet(isPresented: $showDeviceList) {
            DeviceListSheet(bt: bt, isPresented: $showDeviceList)
        }
        .onAppear {
            bt.onTagRead = { tag in
                processTag(tag)
            }
        }
        .onDisappear {
            bt.onTagRead = nil
        }
    }

    private var connectionCard: some View {
        Group {
            switch bt.state {
            case .disconnected:
                Button {
                    showDeviceList = true
                    bt.startScanning()
                } label: {
                    HStack(spacing: AppTheme.Spacing.md) {
                        Image(systemName: "antenna.radiowaves.left.and.right.circle")
                            .font(.system(size: 28))
                            .foregroundStyle(AppTheme.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Conectar ao leitor RFID")
                                .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Toque para buscar dispositivos Bluetooth")
                                .font(.system(size: AppTheme.FontSize.caption))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, AppTheme.Spacing.sm)

            case .scanning:
                HStack(spacing: AppTheme.Spacing.md) {
                    ProgressView()
                    Text("Buscando dispositivos...")
                        .font(.system(size: AppTheme.FontSize.body))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.surfaceSecondary)
                .padding(.horizontal)
                .padding(.vertical, AppTheme.Spacing.sm)

            case .connecting(let name):
                HStack(spacing: AppTheme.Spacing.md) {
                    ProgressView()
                    Text("Conectando a \(name)...")
                        .font(.system(size: AppTheme.FontSize.body))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.primary.opacity(0.15))
                .padding(.horizontal)
                .padding(.vertical, AppTheme.Spacing.sm)

            case .connected(let name):
                HStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(AppTheme.success)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Conectado")
                            .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(name)
                            .font(.system(size: AppTheme.FontSize.caption))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Text("Sempre conectado")
                        .font(.system(size: AppTheme.FontSize.footnote))
                        .foregroundStyle(AppTheme.success)
                    Button("Desconectar") {
                        bt.disconnect()
                    }
                    .font(.system(size: AppTheme.FontSize.footnote, weight: .medium))
                    .foregroundStyle(AppTheme.error)
                }
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.success.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                .padding(.horizontal)
                .padding(.vertical, AppTheme.Spacing.sm)

            case .error(let msg):
                HStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AppTheme.error)
                    Text(msg)
                        .font(.system(size: AppTheme.FontSize.caption))
                        .foregroundStyle(AppTheme.error)
                }
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.error.opacity(0.1))
                .padding(.horizontal)
                .padding(.vertical, AppTheme.Spacing.sm)
            }
        }
    }

    private func didTapLer() {
        let t = scanInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        scanInput = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        processTag(t)
    }

    private func processTag(_ tag: String) {
        let t = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Task {
            let product = try? await api.getProductByRfid(tag: t)
            await MainActor.run {
                scannedItems.append(ScannedItem(tag: t, product: product, scannedAt: Date()))
            }
        }
    }
}

// MARK: - Device List Sheet
struct DeviceListSheet: View {
    @ObservedObject var bt: RfidBluetoothManager
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                if bt.discoveredDevices.isEmpty {
                    HStack {
                        Spacer()
                        if case .scanning = bt.state {
                            ProgressView()
                            Text("Buscando...")
                                .font(.system(size: AppTheme.FontSize.body))
                                .foregroundStyle(AppTheme.textSecondary)
                        } else {
                            Text("Nenhum dispositivo encontrado")
                                .font(.system(size: AppTheme.FontSize.body))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                ForEach(bt.discoveredDevices) { device in
                    Button {
                        bt.connect(to: device)
                        isPresented = false
                    } label: {
                        HStack(spacing: AppTheme.Spacing.md) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.title2)
                                .foregroundStyle(AppTheme.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.name ?? "Dispositivo")
                                    .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(device.id.uuidString)
                                    .font(.system(size: AppTheme.FontSize.caption, design: .monospaced))
                                    .foregroundStyle(AppTheme.textTertiary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        .padding(.vertical, AppTheme.Spacing.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Selecionar leitor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        bt.stopScanning()
                        isPresented = false
                    }
                }
            }
        }
    }
}
