import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 260)
        } detail: {
            detail
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $model.pairingRequest) { request in
            PairingSheet(request: request)
                .environmentObject(model)
        }
        .alert(
            "Eşleştirme tamamlanamadı",
            isPresented: Binding(
                get: { model.pairingError != nil },
                set: { if !$0 { model.clearPairingError() } }
            )
        ) {
            Button("Tamam") { model.clearPairingError() }
        } message: {
            Text(model.pairingError ?? "Bilinmeyen eşleştirme hatası")
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(
                            LinearGradient(
                                colors: [Color.indigo, Color.cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "rectangle.2.swap")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text("FlowBridge")
                        .font(.headline)
                    Text("macOS + Windows")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)

            List(SidebarSection.allCases, selection: $model.selectedSection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
                    .padding(.vertical, 3)
            }
            .listStyle(.sidebar)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(model.discoveryStatus.title)
                        .font(.caption.weight(.medium))
                }
                Text(model.deviceName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selectedSection {
        case .overview: OverviewView()
        case .devices: DevicesView()
        case .privacy: PrivacyView()
        case .diagnostics: DiagnosticsView()
        }
    }

    private var statusColor: Color {
        switch model.discoveryStatus {
        case .ready: .green
        case .starting: .orange
        case .failed: .red
        case .stopped: .secondary
        }
    }
}

private struct OverviewView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                HStack(spacing: 14) {
                    MetricCard(
                        title: "Yakındaki cihaz",
                        value: "\(model.peers.count)",
                        icon: "laptopcomputer.and.desktop",
                        color: .indigo
                    )
                    MetricCard(
                        title: "Sistem izinleri",
                        value: "\(model.readyPermissionCount)/2",
                        icon: "checkmark.shield.fill",
                        color: model.readyPermissionCount == 2 ? .green : .orange
                    )
                    MetricCard(
                        title: "Güvenli bağlantı",
                        value: "AES-GCM",
                        icon: "lock.fill",
                        color: .cyan
                    )
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(
                        title: "Kurulumu tamamla",
                        subtitle: "Fareyi paylaşmak için iki sistem izni gerekiyor."
                    )
                    PermissionRow(
                        title: "Erişilebilirlik",
                        detail: "Uzak cihazdan gelen fare olaylarını uygulamak için.",
                        state: model.accessibility,
                        action: model.requestAccessibility
                    )
                    PermissionRow(
                        title: "Giriş İzleme",
                        detail: "Bu Mac'teki girişleri bağlı bilgisayara iletmek için.",
                        state: model.inputMonitoring,
                        action: model.requestInputMonitoring
                    )
                }
                .cardStyle()

                HStack(spacing: 12) {
                    Image(systemName: model.isRunning ? "wave.3.right.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(model.isRunning ? .green : .secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.isRunning ? "FlowBridge aktif" : "FlowBridge duraklatıldı")
                            .font(.headline)
                        Text("Bu Mac yerel ağda kimlik bilgisi paylaşmadan diğer cihazları arıyor.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { model.isRunning },
                        set: { _ in model.toggleRunning() }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .padding(18)
                .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 14) {
                    Image(systemName: model.mouseSharingActive ? "cursorarrow.motionlines" : "computermouse.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(model.mouseSharingActive ? .green : .indigo)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.mouseSharingActive ? "Fare uzak cihazda" : "Ortak fare")
                            .font(.headline)
                        Text(mouseSharingDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { model.mouseSharingEnabled },
                        set: { _ in model.toggleMouseSharing() }
                    ))
                    .labelsHidden()
                }
                .cardStyle()
            }
            .padding(30)
        }
    }

    private var mouseSharingDetail: String {
        if let target = model.mouseTargetName, let edge = model.mouseExitEdgeTitle {
            return "Bu Mac'in \(edge) kenarından \(target) cihazına geç. Geldiğin kenara dön veya Esc'ye bas."
        }
        return "Kullanmak için diğer FlowBridge cihazını güvenli biçimde eşleştir ve iki izni ver."
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tek masa. İki bilgisayar.")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text("İki Mac'i, iki Windows PC'yi veya Mac ile Windows'u güvenli yerel bağlantıda tek fareyle kullan.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DevicesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionHeader(
                title: "Cihazlar",
                subtitle: "Aynı yerel ağdaki FlowBridge cihazları otomatik görünür."
            )

            LocalDeviceCard()

            Text("YAKINDAKİ CİHAZLAR")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if model.peers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.router")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Henüz başka cihaz yok")
                        .font(.headline)
                    Text("FlowBridge'i Windows veya başka bir Mac'te aç. Cihaz birkaç saniye içinde burada görünecek.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(model.peers) { peer in
                            PeerRow(peer: peer)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(30)
    }
}

private struct LocalDeviceCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "macbook")
                .font(.system(size: 30))
                .foregroundStyle(.indigo)
                .frame(width: 52, height: 52)
                .background(.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text(model.deviceName)
                    .font(.headline)
                Text("Bu Mac · Kimlik \(model.shortDeviceID)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label("Bu cihaz", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
        }
        .cardStyle()
    }
}

private struct PeerRow: View {
    @EnvironmentObject private var model: AppModel
    let peer: PeerDevice

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 24))
                .frame(width: 46, height: 46)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(peer.name).font(.headline)
                Text(peer.isTrusted
                    ? "İki cihazda eşleşti"
                    : peer.isPairingPending
                        ? "Karşı cihazın onayı bekleniyor"
                        : "Yeni cihaz · \(peer.platform)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if peer.isTrusted {
                Button("Eşleşmeyi Kaldır", role: .destructive) {
                    model.removeTrust(from: peer)
                }
            } else if peer.isPairingPending {
                Button("Onay bekleniyor") {}
                    .disabled(true)
            } else {
                Button("Eşleştir") { model.beginPairing(with: peer) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .cardStyle()
    }
}

private struct PrivacyView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionHeader(
                title: "Gizlilik",
                subtitle: "Paylaşım denetimi sende kalır; giriş verisi buluta gönderilmez."
            )

            VStack(spacing: 0) {
                SettingsRow(
                    icon: "doc.on.clipboard",
                    title: "Pano paylaşımı",
                    detail: "Gelecek sürüm için planlandı; bu sürümde veri iletilmez."
                ) {
                    Toggle("", isOn: .constant(false))
                        .labelsHidden()
                        .disabled(true)
                }
                Divider().padding(.leading, 56)
                SettingsRow(
                    icon: "timer",
                    title: "Geçici olarak durdur",
                    detail: "Pano paylaşımı kullanılabilir olduğunda burada yönetilecek."
                ) {
                    Text("Yakında").foregroundStyle(.secondary)
                }
            }
            .cardStyle(padding: 0)

            Label(
                "FlowBridge bulut hesabı kullanmaz. Keşif, eşleştirme ve veri aktarımı yerel ağda kalır.",
                systemImage: "lock.shield.fill"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(16)
            .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            Spacer()
        }
        .padding(30)
    }
}

private struct DiagnosticsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionHeader(
                title: "Teşhis",
                subtitle: "Bağlantı sorunlarını kişisel veri toplamadan kontrol et."
            )

            VStack(spacing: 0) {
                DiagnosticRow(
                    title: "Yerel ağ keşfi",
                    value: model.discoveryStatus.title,
                    healthy: model.discoveryStatus == .ready
                )
                Divider().padding(.leading, 20)
                DiagnosticRow(
                    title: "Erişilebilirlik izni",
                    value: model.accessibility.title,
                    healthy: model.accessibility == .granted
                )
                Divider().padding(.leading, 20)
                DiagnosticRow(
                    title: "Giriş İzleme izni",
                    value: model.inputMonitoring.title,
                    healthy: model.inputMonitoring == .granted
                )
                Divider().padding(.leading, 20)
                DiagnosticRow(title: "Fare taşıma güvenliği", value: "AES-256-GCM + HMAC", healthy: true)
            }
            .cardStyle(padding: 0)

            if let detail = model.discoveryStatus.detail {
                Label(detail, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            Button("Kontrolleri Yenile") { model.refreshPermissions() }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding(30)
    }
}

private struct PairingSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let request: PairingRequest

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "lock.laptopcomputer")
                .font(.system(size: 42))
                .foregroundStyle(.indigo)
            VStack(spacing: 7) {
                Text("\(request.peer.name) ile eşleştir")
                    .font(.title2.bold())
                Text(request.isIncoming
                    ? "Diğer cihaz eşleştirme istedi. İki ekrandaki kodu karşılaştır."
                    : "Onayladığında kod diğer cihazda otomatik açılacak.")
                    .foregroundStyle(.secondary)
            }
            Text(request.code)
                .font(.system(size: 38, weight: .bold, design: .monospaced))
                .tracking(5)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(.indigo.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            Text("Kod eşleşmiyorsa onaylama. Eşleştirme tamamlanmadan cihaz güvenilir sayılmaz.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            HStack {
                Button("İptal") {
                    model.cancelPairing(request)
                    dismiss()
                }
                    .keyboardShortcut(.cancelAction)
                Button("Kod Eşleşiyor") {
                    model.approvePairing()
                }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(width: 470)
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let state: PermissionState
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: state == .granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.title2)
                .foregroundStyle(state == .granted ? .green : .orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if state == .granted {
                Text("Hazır").font(.caption.weight(.semibold)).foregroundStyle(.green)
            } else {
                Button("İzin Ver", action: action).buttonStyle(.bordered)
            }
        }
    }
}

private struct SettingsRow<Trailing: View>: View {
    let icon: String
    let title: String
    let detail: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.indigo)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            trailing
        }
        .padding(16)
    }
}

private struct DiagnosticRow: View {
    let title: String
    let value: String
    let healthy: Bool

    var body: some View {
        HStack {
            Circle()
                .fill(healthy ? .green : .orange)
                .frame(width: 9, height: 9)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 27, weight: .bold, design: .rounded))
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
    }
}

private extension View {
    func cardStyle(padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
            )
    }
}
