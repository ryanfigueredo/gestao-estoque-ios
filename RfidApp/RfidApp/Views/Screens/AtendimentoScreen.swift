import SwiftUI

struct AtendimentoScreen: View {
    @State private var tab: AtendimentoTab = .conversas
    @State private var conversations: [BotConversation] = []
    @State private var orders: [BotOrder] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    private let api = ApiClient.shared

    enum AtendimentoTab: String, CaseIterable {
        case conversas = "Conversas"
        case pedidos = "Pedidos"
    }

    var body: some View {
        VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(AtendimentoTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(AppTheme.Spacing.md)

                if let msg = errorMessage {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.error)
                        Text(msg)
                            .font(.system(size: AppTheme.FontSize.caption))
                            .foregroundStyle(AppTheme.error)
                    }
                    .padding(AppTheme.Spacing.md)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.error.opacity(0.1))
                }

                switch tab {
                case .conversas:
                    ConversationListView(
                        conversations: conversations,
                        onRefresh: { Task { await loadConversations() } }
                    )
                case .pedidos:
                    PedidosListView(
                        orders: orders,
                        onRefresh: { Task { await loadOrders() } },
                        onStatusChange: { id, status in
                            Task {
                                try? await api.updateOrderStatus(orderId: id, status: status)
                                await loadOrders()
                            }
                        }
                    )
                }
            }
            .navigationTitle("Atendimento")
            .task {
                await loadConversations()
                await loadOrders()
            }
    }

    private func loadConversations() async {
        isLoading = true
        errorMessage = nil
        do {
            let list = try await api.getBotConversations()
            await MainActor.run {
                conversations = list
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                conversations = []
            }
        }
        await MainActor.run { isLoading = false }
    }

    private func loadOrders() async {
        do {
            orders = try await api.getBotOrders()
        } catch {
            orders = []
        }
    }
}

// MARK: - Conversation List
struct ConversationListView: View {
    let conversations: [BotConversation]
    let onRefresh: () async -> Void

    private var pendentes: [BotConversation] {
        conversations.filter { $0.isPaused == true }
    }
    private var concluidos: [BotConversation] {
        conversations.filter { ($0.isPaused ?? false) == false }
    }

    var body: some View {
        List {
            if !pendentes.isEmpty {
                Section("Pendentes") {
                    ForEach(pendentes) { c in
                        conversationRow(c)
                    }
                }
            }
            if !concluidos.isEmpty {
                Section("Concluídos") {
                    ForEach(concluidos) { c in
                        conversationRow(c)
                    }
                }
            }
            if pendentes.isEmpty && concluidos.isEmpty {
                Text("Nenhuma conversa")
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .listStyle(.plain)
        .refreshable { await onRefresh() }
        .onAppear { Task { await onRefresh() } }
    }

    private func conversationRow(_ c: BotConversation) -> some View {
        NavigationLink {
            ConversationChatScreen(phone: c.customerPhone, customerName: c.customerName, onConcluir: { await onRefresh() })
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "message.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Text(formatPhone(c.customerPhone))
                            .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        if let name = c.customerName, !name.isEmpty {
                            Text("• \(name)")
                                .font(.system(size: AppTheme.FontSize.caption))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    if let last = c.lastMessage, !last.isEmpty {
                                Text(last)
                                    .font(.system(size: AppTheme.FontSize.caption))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(2)
                            }
                    if let date = c.lastMessageAt {
                        Text(formatDate(date))
                            .font(.system(size: AppTheme.FontSize.footnote))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                }
                Spacer()
                if (c.messageCount ?? 0) > 0 {
                    Text("\(c.messageCount ?? 0)")
                        .font(.system(size: AppTheme.FontSize.caption, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(AppTheme.primary)
                        .clipShape(Circle())
                }
            }
            .padding(.vertical, AppTheme.Spacing.xs)
        }
    }

    private func formatPhone(_ s: String) -> String {
        var digits = s.filter { $0.isNumber }
        if digits.hasPrefix("55") && digits.count > 11 { digits = String(digits.dropFirst(2)) }
        if digits.count == 11 { return "(\(digits.prefix(2))) \(digits.dropFirst(2).prefix(5))-\(digits.suffix(4))" }
        if digits.count == 10 { return "(\(digits.prefix(2))) \(digits.dropFirst(2).prefix(4))-\(digits.suffix(4))" }
        return s
    }

    private func formatDate(_ s: String) -> String {
        guard let d = parseISO8601(s) else { return String(s.prefix(16)) }
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy HH:mm"
        f.locale = Locale(identifier: "pt_BR")
        f.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        return f.string(from: d)
    }
}

// MARK: - Pedidos List
struct PedidosListView: View {
    let orders: [BotOrder]
    let onRefresh: () async -> Void
    let onStatusChange: (String, String) -> Void

    private let statusOptions = [
        ("em_preparacao", "Em preparação"),
        ("saiu_entrega", "Saiu para entrega"),
        ("entregue", "Entregue"),
        ("cancelado", "Cancelado"),
    ]

    var body: some View {
        List {
            ForEach(orders) { o in
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    HStack {
                        Text(o.orderNumber ?? "—")
                            .font(.system(size: AppTheme.FontSize.body, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text(formatDate(o.createdAt ?? ""))
                            .font(.system(size: AppTheme.FontSize.caption))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    if let name = o.customerName, !name.isEmpty {
                        Text(name)
                            .font(.system(size: AppTheme.FontSize.callout))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Text(formatPhone(o.customerPhone ?? ""))
                        .font(.system(size: AppTheme.FontSize.footnote))
                        .foregroundStyle(AppTheme.primary)
                    if let items = o.items, !items.isEmpty {
                        Text(items)
                            .font(.system(size: AppTheme.FontSize.caption))
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(3)
                    }
                    Menu {
                        ForEach(statusOptions, id: \.0) { value, label in
                            Button(label) { onStatusChange(o.id, value) }
                        }
                    } label: {
                        HStack(spacing: AppTheme.Spacing.xs) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(o.statusLabel ?? o.status ?? "Alterar status")
                                .font(.system(size: AppTheme.FontSize.footnote, weight: .medium))
                        }
                        .foregroundStyle(statusColor(o.status ?? ""))
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, AppTheme.Spacing.xs)
                        .background(statusColor(o.status ?? "").opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                    }
                }
                .padding(.vertical, AppTheme.Spacing.xs)
            }
        }
        .listStyle(.plain)
        .refreshable { await onRefresh() }
    }

    private func statusColor(_ s: String) -> Color {
        switch s {
        case "entregue": return AppTheme.success
        case "saiu_entrega": return AppTheme.primary
        case "cancelado": return AppTheme.textTertiary
        default: return AppTheme.warning
        }
    }

    private func formatPhone(_ s: String) -> String {
        var digits = s.filter { $0.isNumber }
        if digits.hasPrefix("55") && digits.count > 11 { digits = String(digits.dropFirst(2)) }
        if digits.count == 11 { return "(\(digits.prefix(2))) \(digits.dropFirst(2).prefix(5))-\(digits.suffix(4))" }
        if digits.count == 10 { return "(\(digits.prefix(2))) \(digits.dropFirst(2).prefix(4))-\(digits.suffix(4))" }
        return s
    }

    private func formatDate(_ s: String) -> String {
        guard let d = parseISO8601(s) else { return String(s.prefix(16)) }
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy HH:mm"
        f.locale = Locale(identifier: "pt_BR")
        f.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        return f.string(from: d)
    }
}

// MARK: - Conversation Chat
struct ConversationChatScreen: View {
    let phone: String
    var customerName: String?
    var onConcluir: (() async -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [BotMessage] = []
    @State private var inputText = ""
    @AppStorage("atendimento_display_name") private var displayName = ""
    @State private var sending = false
    @State private var chatError: String?
    @State private var orders: [BotOrder] = []
    @State private var showOrdersSheet = false
    @State private var showCreateOrderSheet = false
    @State private var createOrderItems = ""
    @State private var createOrderName = ""
    @State private var createOrderNotes = ""
    @State private var creatingOrder = false
    @State private var createOrderError: String?
    private let api = ApiClient.shared

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        ForEach(messages) { m in
                            MessageBubble(
                                message: m,
                                formatMessageTime: formatMessageTime,
                                onCriarPedido: { text in
                                    createOrderItems = text
                                    showOrdersSheet = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showCreateOrderSheet = true
                                    }
                                }
                            )
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                    .id("bottom")
                }
                .onChange(of: messages.count) {
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            if let msg = chatError {
                Text(msg)
                    .font(.system(size: AppTheme.FontSize.caption))
                    .foregroundStyle(AppTheme.error)
                    .padding(.horizontal)
            }

            Text(displayName.isEmpty ? "Nome: defina em Mais" : "Cliente vê: \(displayName)")
                .font(.system(size: AppTheme.FontSize.footnote))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, 4)

            HStack(spacing: AppTheme.Spacing.sm) {
                TextField("Mensagem", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(AppTheme.primary)
                }
                .disabled(sending || inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.surface)

            Button {
                Task { await concluir() }
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Concluir atendimento")
                        .font(.system(size: AppTheme.FontSize.callout, weight: .medium))
                }
                .foregroundStyle(AppTheme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.sm)
            }
            .disabled(sending)
            .background(AppTheme.surface)
        }
        .navigationTitle(customerName?.isEmpty == false ? (customerName ?? formatPhone(phone)) : formatPhone(phone))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showOrdersSheet = true
                } label: {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 20))
                }
            }
        }
        .sheet(isPresented: $showOrdersSheet) {
            ordersSheetContent
        }
        .sheet(isPresented: $showCreateOrderSheet) {
            createOrderSheetContent
        }
        .task {
            await loadMessages()
            await loadOrdersForCustomer()
        }
        .refreshable {
            await loadMessages()
            await loadOrdersForCustomer()
        }
    }

    @ViewBuilder
    private var ordersSheetContent: some View {
        NavigationStack {
            List {
                Button {
                    showOrdersSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showCreateOrderSheet = true }
                } label: {
                    Label("Criar pedido", systemImage: "plus.circle.fill")
                        .font(.system(size: AppTheme.FontSize.body, weight: .medium))
                }
                Section("Pedidos deste cliente") {
                    if orders.isEmpty {
                        Text("Nenhum pedido")
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        ForEach(orders) { o in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(o.orderNumber ?? "—")
                                        .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                                    Spacer()
                                    Text(o.statusLabel ?? o.status ?? "")
                                        .font(.system(size: AppTheme.FontSize.caption))
                                        .foregroundStyle(AppTheme.textTertiary)
                                }
                                if let items = o.items, !items.isEmpty {
                                    Text(items)
                                        .font(.system(size: AppTheme.FontSize.caption))
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .lineLimit(2)
                                }
                                Menu {
                                    Button("Em preparação") { updateStatus(o.id, "em_preparacao"); showOrdersSheet = false }
                                    Button("Saiu para entrega") { updateStatus(o.id, "saiu_entrega"); showOrdersSheet = false }
                                    Button("Entregue") { updateStatus(o.id, "entregue"); showOrdersSheet = false }
                                    Button("Cancelado") { updateStatus(o.id, "cancelado"); showOrdersSheet = false }
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                        Text("Alterar status")
                                    }
                                    .font(.system(size: AppTheme.FontSize.caption))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Pedidos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { showOrdersSheet = false }
                }
            }
        }
        .onAppear {
            createOrderName = customerName ?? ""
        }
    }

    @ViewBuilder
    private var createOrderSheetContent: some View {
        NavigationStack {
            Form {
                Section("Itens do pedido") {
                    TextField("Lista de itens (ex: 3 sacos cimento, 10m telha)", text: $createOrderItems, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Cliente") {
                    TextField("Nome do cliente", text: $createOrderName)
                }
                Section("Observações") {
                    TextField("Observações (opcional)", text: $createOrderNotes, axis: .vertical)
                        .lineLimit(2...4)
                }
                if let err = createOrderError {
                    Section {
                        Text(err)
                            .foregroundStyle(AppTheme.error)
                    }
                }
            }
            .navigationTitle("Novo pedido")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        showCreateOrderSheet = false
                        createOrderItems = ""
                        createOrderNotes = ""
                        createOrderError = nil
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Criar") {
                        Task { await submitCreateOrder() }
                    }
                    .disabled(creatingOrder || createOrderItems.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            createOrderName = customerName ?? ""
        }
    }

    private func submitCreateOrder() async {
        let items = createOrderItems.trimmingCharacters(in: .whitespaces)
        guard !items.isEmpty else { return }
        creatingOrder = true
        createOrderError = nil
        do {
            _ = try await api.createBotOrder(
                customerPhone: phone,
                items: items,
                customerName: createOrderName.isEmpty ? nil : createOrderName,
                notes: createOrderNotes.isEmpty ? nil : createOrderNotes,
                sendWhatsApp: true
            )
            showCreateOrderSheet = false
            createOrderItems = ""
            createOrderNotes = ""
            await loadOrdersForCustomer()
        } catch {
            createOrderError = error.localizedDescription
        }
        creatingOrder = false
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        if displayName.trimmingCharacters(in: .whitespaces).isEmpty {
            chatError = "Defina seu nome em Mais para enviar"
            return
        }
        sending = true
        chatError = nil
        inputText = ""
        Task {
            do {
                try await api.sendBotMessage(phone: phone, body: text, attendantName: displayName)
                await loadMessages()
            } catch {
                chatError = error.localizedDescription
            }
            sending = false
        }
    }

    private func concluir() async {
        sending = true
        chatError = nil
        do {
            try await api.concluirAtendimento(phone: phone)
            await onConcluir?()
            await MainActor.run {
                sending = false
                dismiss()
            }
        } catch {
            await MainActor.run {
                chatError = error.localizedDescription
                sending = false
            }
        }
    }

    private func updateStatus(_ orderId: String, _ status: String) {
        Task {
            try? await api.updateOrderStatus(orderId: orderId, status: status)
            await loadOrdersForCustomer()
        }
    }

    private func loadMessages() async {
        do {
            messages = try await api.getBotMessages(phone: phone)
        } catch {
            messages = []
        }
    }

    private func loadOrdersForCustomer() async {
        do {
            let all = try await api.getBotOrders()
            let digits = phone.filter { $0.isNumber }
            orders = all.filter {
                ($0.customerPhone ?? "").filter { $0.isNumber }.hasSuffix(digits) ||
                digits.hasSuffix(($0.customerPhone ?? "").filter { $0.isNumber })
            }
        } catch {
            orders = []
        }
    }

    private func formatPhone(_ s: String) -> String {
        var digits = s.filter { $0.isNumber }
        if digits.hasPrefix("55") && digits.count > 11 { digits = String(digits.dropFirst(2)) }
        if digits.count == 11 { return "(\(digits.prefix(2))) \(digits.dropFirst(2).prefix(5))-\(digits.suffix(4))" }
        if digits.count == 10 { return "(\(digits.prefix(2))) \(digits.dropFirst(2).prefix(4))-\(digits.suffix(4))" }
        return s
    }

    private func formatMessageTime(createdAt: String, isIncoming: Bool) -> String {
        guard let d = parseISO8601(createdAt) ?? parsePostgresDate(createdAt) else {
            return createdAt.isEmpty ? "" : String(createdAt.prefix(16))
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        let now = Date()
        let sameDay = Calendar.current.isDate(d, inSameDayAs: now)
        f.dateFormat = sameDay ? "HH:mm" : "dd/MM HH:mm"
        let timeStr = f.string(from: d)
        return isIncoming ? "Recebida \(timeStr)" : "Enviada \(timeStr)"
    }
}

private func parsePostgresDate(_ s: String) -> Date? {
    let trimmed = s.trimmingCharacters(in: .whitespaces)
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    if let d = formatter.date(from: trimmed) { return d }
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    if let d = formatter.date(from: trimmed) { return d }
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter.date(from: String(trimmed.prefix(19)))
}

// MARK: - Atendimento Nome (config em Mais)
struct AtendimentoNomeScreen: View {
    private let key = "atendimento_display_name"
    @State private var displayName: String = UserDefaults.standard.string(forKey: "atendimento_display_name") ?? ""

    var body: some View {
        Form {
            Section {
                TextField("Nome que o cliente verá", text: $displayName)
                    .textContentType(.name)
                Text("Este nome aparece nas mensagens enviadas pelo atendente para o cliente.")
                    .font(.system(size: AppTheme.FontSize.caption))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .navigationTitle("Nome do atendente")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: displayName) { _, newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            UserDefaults.standard.set(trimmed.isEmpty ? nil : trimmed, forKey: key)
        }
    }
}

private func parseISO8601(_ s: String) -> Date? {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = iso.date(from: s) { return d }
    iso.formatOptions = [.withInternetDateTime]
    return iso.date(from: s) ?? iso.date(from: s.replacingOccurrences(of: "Z", with: "+00:00"))
}

struct MessageBubble: View {
    let message: BotMessage
    let formatMessageTime: (String, Bool) -> String
    var onCriarPedido: ((String) -> Void)?

    var body: some View {
        let isIn = (message.direction ?? "in") == "in"
        HStack {
            if !isIn { Spacer(minLength: 60) }
            VStack(alignment: isIn ? .leading : .trailing, spacing: 2) {
                messageContent(isIn: isIn)
                    .textSelection(.enabled)
                    .contextMenu {
                        if isIn, let body = message.body, !body.isEmpty {
                            Button {
                                UIPasteboard.general.string = body
                            } label: {
                                Label("Copiar", systemImage: "doc.on.doc")
                            }
                            Button {
                                onCriarPedido?(body)
                            } label: {
                                Label("Criar pedido com esta lista", systemImage: "shippingbox")
                            }
                        }
                    }
                Text(formatMessageTime(message.createdAt ?? "", isIn))
                    .font(.system(size: AppTheme.FontSize.footnote))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            if isIn { Spacer(minLength: 60) }
        }
    }

    @ViewBuilder
    private func messageContent(isIn: Bool) -> some View {
        if message.mediaType == "image", message.mediaId != nil {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                AsyncMediaImage(messageId: message.id)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                if let body = message.body, !body.isEmpty, body != "🖼️ Imagem" {
                    Text(body)
                        .font(.system(size: AppTheme.FontSize.footnote))
                        .foregroundStyle(isIn ? AppTheme.textPrimary : .white)
                }
            }
            .padding(AppTheme.Spacing.sm)
            .background(isIn ? AppTheme.surfaceSecondary : AppTheme.primary)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        } else {
            Text(message.body ?? "")
                .font(.system(size: AppTheme.FontSize.body))
                .foregroundStyle(isIn ? AppTheme.textPrimary : .white)
                .padding(AppTheme.Spacing.sm)
                .background(isIn ? AppTheme.surfaceSecondary : AppTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        }
    }
}

struct AsyncMediaImage: View {
    let messageId: String
    @State private var imageData: Data?
    @State private var loading = true

    var body: some View {
        Group {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 240, maxHeight: 280)
            } else if loading {
                ProgressView()
                    .frame(width: 120, height: 120)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.textTertiary)
                    .frame(width: 120, height: 120)
            }
        }
        .task {
            guard imageData == nil else { return }
            loading = true
            do {
                let data = try await ApiClient.shared.getBotMedia(messageId: messageId)
                imageData = data
            } catch {
                imageData = nil
            }
            loading = false
        }
    }
}
