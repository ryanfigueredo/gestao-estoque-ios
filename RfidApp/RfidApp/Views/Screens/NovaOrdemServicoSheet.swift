import SwiftUI

struct NovaOrdemServicoSheet: View {
    @ObservedObject var viewModel: OSViewModel
    let onDismiss: () -> Void

    @State private var customerName = ""
    @State private var vehicleInfo = ""
    @State private var licensePlate = ""
    @State private var description = ""
    @State private var isCreating = false

    private var canCreate: Bool {
        !customerName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome do cliente", text: $customerName)
                        .textContentType(.name)
                    TextField("Veículo / Equipamento", text: $vehicleInfo, prompt: Text("Ex: Fiat Uno 1.0, Máquina X"))
                        .textContentType(.none)
                    TextField("Placa", text: $licensePlate, prompt: Text("ABC-1234 ou ABC1D23"))
                        .textContentType(.none)
                        .textInputAutocapitalization(.characters)
                } header: {
                    Text("Dados do cliente")
                }

                Section {
                    TextField("Observações", text: $description, prompt: Text("Descrição do serviço, observações..."), axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Observações")
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Nova Ordem de Serviço")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Criar") {
                        createOrdem()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canCreate || isCreating)
                }
            }
            .overlay {
                if isCreating {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(AppTheme.primary)
                }
            }
        }
    }

    private func createOrdem() {
        guard canCreate else { return }
        isCreating = true
        Task {
            let vInfo = vehicleInfo.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : vehicleInfo.trimmingCharacters(in: .whitespaces)
            let placa = licensePlate.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : licensePlate.trimmingCharacters(in: .whitespaces).uppercased()
            let desc = description.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : description.trimmingCharacters(in: .whitespaces)

            if let created = await viewModel.criarOrdem(
                customerName: customerName.trimmingCharacters(in: .whitespaces),
                vehicleInfo: vInfo,
                licensePlate: placa,
                description: desc
            ) {
                viewModel.selectedOrdem = created
                onDismiss()
            }
            isCreating = false
        }
    }
}
