import Foundation
import Combine

@MainActor
final class OSViewModel: ObservableObject {
    // MARK: - Published State

    @Published private(set) var ordens: [OrdemServico] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var selectedOrdem: OrdemServico?

    // MARK: - Dependencies

    private let api = ApiClient.shared

    // MARK: - Actions

    func loadOrdens() async {
        isLoading = true
        errorMessage = nil
        do {
            let list = try await api.getServiceOrders()
            ordens = list.map { mapServiceOrderToOrdemServico($0) }
        } catch {
            errorMessage = error.localizedDescription
            ordens = []
        }
        isLoading = false
    }

    func loadOrdemDetail(id: String) async -> OrdemServico? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let detail = try await api.getServiceOrder(id: id)
            let ordem = mapServiceOrderDetailToOrdemServico(detail)
            if let index = ordens.firstIndex(where: { $0.id == id }) {
                ordens[index] = ordem
            }
            selectedOrdem = ordem
            return ordem
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func criarOrdem(customerName: String, vehicleInfo: String?, licensePlate: String?, description: String?) async -> OrdemServico? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await api.createServiceOrder(
                customerName: customerName,
                vehicleInfo: vehicleInfo,
                licensePlate: licensePlate,
                description: description,
                items: []
            )
            await loadOrdens()
            if let created = ordens.first(where: { $0.id == result.id }) {
                return created
            }
            return OrdemServico(
                id: result.id,
                number: result.number,
                customerName: customerName,
                vehicleInfo: vehicleInfo,
                licensePlate: licensePlate,
                description: description,
                status: .aberta,
                createdAt: nil,
                items: [],
                mechanics: [],
                subtotal: 0,
                discount: 0,
                total: 0
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func adicionarItem(to ordemId: String, product: Product, quantity: Double = 1, readViaRfid: Bool = false) async {
        guard let index = ordens.firstIndex(where: { $0.id == ordemId }) else { return }
        let ordem = ordens[index]
        let unitPrice = product.price ?? 0

        var items = ordem.items
        if let existingIndex = items.firstIndex(where: { $0.productId == product.id }) {
            items[existingIndex].quantity += quantity
            if readViaRfid {
                items[existingIndex].readViaRfid = true
            }
        } else {
            let item = ItemServico(
                id: UUID().uuidString,
                productId: product.id,
                productName: product.name,
                quantity: quantity,
                unitPrice: unitPrice,
                readViaRfid: readViaRfid
            )
            items.append(item)
        }

        var updated = ordem
        updated.items = items
        updated.total = updated.calculatedTotal
        ordens[index] = updated
        selectedOrdem = updated

        await updateOrdemOnServer(updated)
    }

    func marcarItemComoLidoRfid(ordemId: String, productId: String) {
        guard let index = ordens.firstIndex(where: { $0.id == ordemId }) else { return }
        var ordem = ordens[index]
        if let itemIndex = ordem.items.firstIndex(where: { $0.productId == productId }) {
            ordem.items[itemIndex].readViaRfid = true
            ordens[index] = ordem
            selectedOrdem = ordem
        }
    }

    func simularEscanearRfid(ordemId: String, product: Product) async {
        await adicionarItem(to: ordemId, product: product, quantity: 1, readViaRfid: true)
    }

    func calcularTotal(ordem: OrdemServico) -> Double {
        ordem.calculatedTotal
    }

    func fecharOS(ordemId: String) async -> (Bool, String) {
        guard let ordem = ordens.first(where: { $0.id == ordemId }) else {
            return (false, "Ordem não encontrada")
        }
        guard ordem.status == .aberta || ordem.status == .emAndamento else {
            return (false, "Ordem já está \(ordem.status.label.lowercased())")
        }
        guard !ordem.items.isEmpty else {
            return (false, "Adicione pelo menos um item à ordem")
        }
        if !ordem.allItemsRfidVerified {
            return (false, "Todos os itens devem ser escaneados via RFID antes de finalizar")
        }
        return (true, "Ordem pronta para converter em venda")
    }

    func converterEmVenda(ordemId: String) async -> (Bool, String) {
        let (valid, msg) = await fecharOS(ordemId: ordemId)
        guard valid else { return (false, msg) }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await api.convertServiceOrderToSale(serviceOrderId: ordemId)
            await loadOrdens()
            return (true, "Ordem convertida em venda com sucesso")
        } catch {
            errorMessage = error.localizedDescription
            return (false, error.localizedDescription)
        }
    }

    func clearError() { errorMessage = nil }

    // MARK: - Private Helpers

    private func mapServiceOrderToOrdemServico(_ so: ServiceOrder) -> OrdemServico {
        let status = OSStatus(rawValue: so.status ?? "open") ?? .aberta
        return OrdemServico(
            id: so.id,
            number: so.number,
            customerName: so.customerName ?? "Cliente não informado",
            vehicleInfo: nil,
            licensePlate: nil,
            description: nil,
            status: status,
            createdAt: so.createdAt,
            items: [],
            mechanics: [],
            subtotal: so.total,
            discount: 0,
            total: so.total
        )
    }

    private func mapServiceOrderDetailToOrdemServico(_ detail: ServiceOrderDetail) -> OrdemServico {
        let status = OSStatus(rawValue: detail.status ?? "open") ?? .aberta
        let items = (detail.items ?? []).map { item in
            ItemServico(
                id: item.id,
                productId: item.productId ?? "",
                productName: item.productName ?? "Produto",
                quantity: item.quantity ?? 0,
                unitPrice: item.unitPrice ?? 0,
                readViaRfid: false
            )
        }
        let mechanics = (detail.mechanics ?? []).map { m in
            MecanicoOS(
                id: m.id,
                mechanicId: m.mechanicId ?? "",
                mechanicName: m.mechanicName ?? "Mecânico",
                functionDescription: m.functionDescription ?? "",
                value: m.value ?? 0
            )
        }
        return OrdemServico(
            id: detail.id,
            number: detail.number,
            customerName: detail.customerName ?? "Cliente não informado",
            vehicleInfo: detail.vehicleInfo,
            licensePlate: detail.licensePlate,
            description: detail.description,
            status: status,
            createdAt: detail.createdAt,
            items: items,
            mechanics: mechanics,
            subtotal: detail.subtotal,
            discount: detail.discount,
            total: detail.total
        )
    }

    private func updateOrdemOnServer(_ ordem: OrdemServico) async {
        do {
            _ = try await api.updateServiceOrder(
                id: ordem.id,
                customerName: ordem.customerName,
                vehicleInfo: ordem.vehicleInfo,
                licensePlate: ordem.licensePlate,
                description: ordem.description,
                items: ordem.items.map { item in
                    ServiceOrderItemPayload(
                        productId: item.productId,
                        quantity: item.quantity,
                        unitPrice: item.unitPrice,
                        subtotal: item.subtotal
                    )
                },
                mechanics: ordem.mechanics.map { m in
                    ServiceOrderMechanicPayload(
                        mechanicId: m.mechanicId,
                        functionDescription: m.functionDescription,
                        value: m.value
                    )
                }
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
