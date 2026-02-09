import SwiftUI

struct SuporteScreen: View {
    private let email = "ryan@dmtn.com.br"
    private let phone = "+5521997624873"
    private let whatsapp = "5521997624873"
    private let site = "https://dmtn.com.br"

    @State private var showTicketForm = false
    @State private var ticketSubject = ""
    @State private var ticketDescription = ""
    @State private var ticketCategory = "geral"
    @State private var isSubmitting = false
    @State private var ticketSuccess: String?
    @State private var ticketError: String?
    @State private var recentTickets: [SupportTicket] = []
    private let api = ApiClient.shared

    private let categories = [
        ("geral", "Geral"),
        ("tecnico", "Técnico"),
        ("financeiro", "Financeiro"),
        ("duvida", "Dúvida"),
        ("outro", "Outro"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                // Header
                VStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "headphones.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(AppTheme.primary)
                    Text("Central de Suporte")
                        .font(.system(size: AppTheme.FontSize.title1, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Estamos aqui para ajudar você a aproveitar ao máximo o DMTN Estoque Inteligente")
                        .font(.system(size: AppTheme.FontSize.body))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, AppTheme.Spacing.xl)

                // Abrir chamado
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "ticket.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.primary)
                        Text("Abrir chamado")
                            .font(.system(size: AppTheme.FontSize.title3, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    Text("Abra um chamado para rastrear sua solicitação. Nossa equipe responderá em até 4 horas úteis.")
                        .font(.system(size: AppTheme.FontSize.footnote))
                        .foregroundStyle(AppTheme.textSecondary)
                    Button {
                        ticketSuccess = nil
                        ticketError = nil
                        showTicketForm = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Novo chamado")
                                .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.md)
                        .background(AppTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                    }
                    .sheet(isPresented: $showTicketForm) {
                        TicketFormSheet(
                            subject: $ticketSubject,
                            description: $ticketDescription,
                            category: $ticketCategory,
                            categories: categories,
                            isSubmitting: $isSubmitting,
                            onDismiss: { showTicketForm = false },
                            onSubmit: submitTicket
                        )
                    }
                    if let msg = ticketSuccess {
                        HStack(spacing: AppTheme.Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.success)
                            Text(msg)
                                .font(.system(size: AppTheme.FontSize.footnote))
                                .foregroundStyle(AppTheme.success)
                        }
                        .padding(AppTheme.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.success.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                    }
                    if let msg = ticketError {
                        HStack(spacing: AppTheme.Spacing.xs) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(AppTheme.error)
                            Text(msg)
                                .font(.system(size: AppTheme.FontSize.footnote))
                                .foregroundStyle(AppTheme.error)
                        }
                        .padding(AppTheme.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.error.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                    }
                    if !recentTickets.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text("Seus chamados recentes")
                                .font(.system(size: AppTheme.FontSize.footnote, weight: .semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            ForEach(recentTickets.prefix(5)) { t in
                                HStack {
                                    Text(t.ticketNumber ?? t.id)
                                        .font(.system(size: AppTheme.FontSize.footnote, weight: .medium))
                                        .foregroundStyle(AppTheme.primary)
                                    Text(t.subject ?? "")
                                        .font(.system(size: AppTheme.FontSize.footnote))
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .lineLimit(1)
                                    Spacer()
                                    StatusBadge(status: t.status ?? "aberto")
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
                .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 2)
                .padding(.horizontal)

                // Contato
                VStack(spacing: AppTheme.Spacing.md) {
                    ContactCard(
                        icon: "envelope.fill",
                        title: "Email",
                        subtitle: "Respondemos o mais rápido possível",
                        actionLabel: email
                    ) { UIApplication.shared.open(URL(string: "mailto:\(email)")!) }

                    ContactCard(
                        icon: "phone.fill",
                        title: "Telefone",
                        subtitle: "Fale com nossa equipe",
                        actionLabel: "Ligar"
                    ) { UIApplication.shared.open(URL(string: "tel:\(phone)")!) }

                    ContactCard(
                        icon: "message.fill",
                        title: "WhatsApp",
                        subtitle: "Atendimento rápido",
                        actionLabel: "Abrir WhatsApp"
                    ) { UIApplication.shared.open(URL(string: "https://wa.me/\(whatsapp)")!) }
                }
                .padding(.horizontal)

                // Horário
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "clock.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.primary)
                        Text("Horário de Atendimento")
                            .font(.system(size: AppTheme.FontSize.title3, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    HStack(alignment: .top, spacing: AppTheme.Spacing.lg) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Segunda a Sexta")
                                .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("08:00 às 18:00")
                                .font(.system(size: AppTheme.FontSize.body))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sábado")
                                .font(.system(size: AppTheme.FontSize.callout, weight: .semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("09:00 às 13:00")
                                .font(.system(size: AppTheme.FontSize.body))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppTheme.Spacing.lg)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
                .padding(.horizontal)

                // Compromisso de atendimento (tempo de resposta)
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: "clock.badge.checkmark.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.success)
                        Text("Compromisso de Atendimento")
                            .font(.system(size: AppTheme.FontSize.title3, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    Text("Tempo de resposta: até 4 horas úteis durante o horário comercial. Todos os planos incluem suporte por email, telefone e WhatsApp.")
                        .font(.system(size: AppTheme.FontSize.body))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppTheme.Spacing.lg)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
                .padding(.horizontal)

                // Footer
                VStack(spacing: AppTheme.Spacing.xs) {
                    Text("DMTN DIGITAL TECNOLOGIA E SOLUÇÕES LTDA")
                        .font(.system(size: AppTheme.FontSize.footnote, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("CNPJ: 59.171.428/0001-40")
                        .font(.system(size: AppTheme.FontSize.caption))
                        .foregroundStyle(AppTheme.textTertiary)
                    Text("Rua Visconde de Pirajá, 414, sala 718, Ipanema, Rio de Janeiro - RJ")
                        .font(.system(size: AppTheme.FontSize.caption))
                        .foregroundStyle(AppTheme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, AppTheme.Spacing.xl)
                .padding(.bottom, AppTheme.Spacing.xxl)
            }
        }
        .background(AppTheme.background)
        .navigationTitle("Suporte")
        .task { await loadRecentTickets() }
    }

    private func submitTicket() async {
        let subj = ticketSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = ticketDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard subj.count >= 3 else {
            ticketError = "Assunto deve ter pelo menos 3 caracteres"
            return
        }
        guard desc.count >= 10 else {
            ticketError = "Descrição deve ter pelo menos 10 caracteres"
            return
        }
        isSubmitting = true
        ticketError = nil
        ticketSuccess = nil
        do {
            let res = try await api.createSupportTicket(subject: subj, description: desc, category: ticketCategory)
            ticketSuccess = "Chamado \(res.ticket?.ticketNumber ?? "") aberto! Em breve entraremos em contato."
            ticketSubject = ""
            ticketDescription = ""
            showTicketForm = false
            await loadRecentTickets()
        } catch {
            ticketError = error.localizedDescription
        }
        isSubmitting = false
    }

    private func loadRecentTickets() async {
        do {
            recentTickets = try await api.getSupportTickets()
        } catch {
            recentTickets = []
        }
    }
}

struct TicketFormSheet: View {
    @Binding var subject: String
    @Binding var description: String
    @Binding var category: String
    let categories: [(String, String)]
    @Binding var isSubmitting: Bool
    let onDismiss: () -> Void
    let onSubmit: () async -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Assunto", text: $subject)
                        .autocapitalization(.sentences)
                    Picker("Categoria", selection: $category) {
                        ForEach(categories, id: \.0) { id, label in
                            Text(label).tag(id)
                        }
                    }
                    .pickerStyle(.menu)
                    TextField("Descreva seu problema ou dúvida...", text: $description, axis: .vertical)
                        .lineLimit(4...10)
                        .autocapitalization(.sentences)
                } header: {
                    Text("Detalhes do chamado")
                } footer: {
                    Text("Quanto mais detalhes, mais rápido conseguimos ajudar.")
                }
            }
            .navigationTitle("Abrir chamado")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await onSubmit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Enviar")
                        }
                    }
                    .disabled(isSubmitting || subject.trimmingCharacters(in: .whitespaces).count < 3 || description.trimmingCharacters(in: .whitespaces).count < 10)
                }
            }
        }
    }
}

struct StatusBadge: View {
    let status: String

    private var label: String {
        switch status {
        case "aberto": return "Aberto"
        case "em_andamento": return "Em andamento"
        case "resolvido": return "Resolvido"
        case "fechado": return "Fechado"
        default: return status
        }
    }

    private var color: Color {
        switch status {
        case "aberto": return AppTheme.warning
        case "em_andamento": return AppTheme.primary
        case "resolvido", "fechado": return AppTheme.success
        default: return AppTheme.textSecondary
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

struct ContactCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionLabel: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                        .fill(AppTheme.primary.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(AppTheme.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: AppTheme.FontSize.body, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: AppTheme.FontSize.caption))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Text(actionLabel)
                    .font(.system(size: AppTheme.FontSize.footnote, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
            }
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            .shadow(color: AppTheme.shadow, radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
