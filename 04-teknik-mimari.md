# Teknik Mimari

> Bu belge hedef mimariyi de içerir. Çalışan `0.4.0` protokolü için `docs/ARCHITECTURE.md` dosyasına bakın.

## 1. Mimari hedefler

- Düşük giriş gecikmesi
- Ağ değişikliklerinden sonra hızlı toparlanma
- Ortak iş mantığı ile platforma özel güvenli giriş API'lerini ayırma
- Her bağlantıda kimlik doğrulama ve şifreleme
- Dosya aktarımını giriş olaylarından izole etme
- Sorunları gözlemlenebilir fakat kişisel veriyi kaydetmeyen loglama

## 2. Önerilen teknoloji seçimi

### Ortak çekirdek: Rust

Sorumlulukları:

- Cihaz kimliği ve eşleştirme
- Ağ keşfi
- Bağlantı durumu makinesi
- Giriş olaylarının seri hâle getirilmesi
- Dosya transfer protokolü
- Şifreleme ve sertifika yönetimi
- Telemetri olaylarının kişisel veriden arındırılması

Neden Rust:

- Bellek güvenliği
- Windows ve macOS için ortak çekirdek üretebilme
- Ağ ve eşzamanlılık işlerinde güçlü ekosistem
- Native arayüzlere C ABI veya UniFFI benzeri köprülerle bağlanabilme

### macOS uygulaması: Swift + SwiftUI

- Menü çubuğu uygulaması
- Accessibility ve Input Monitoring izin yönetimi
- Quartz Event Services / CGEvent tabanlı giriş yakalama ve üretme
- Keychain içinde cihaz özel anahtarı saklama
- Network.framework ile ağ değişikliği gözlemi
- Sparkle veya uygun imzalı güncelleme sistemi değerlendirmesi

### Windows uygulaması: C# + WinUI 3 veya native Windows katmanı

- Sistem tepsisi ve ayar arayüzü
- Raw Input / düşük seviyeli hook ile yerel giriş yakalama
- SendInput ile hedef giriş üretme
- Windows Credential Manager/DPAPI ile anahtar koruma
- Windows Firewall entegrasyonu
- MSIX veya imzalı installer

Rust çekirdeğiyle köprü maliyeti prototipte ölçülmelidir. Köprü karmaşıklığı gecikme veya hata riskini artırırsa Windows platform katmanı Rust ile daha fazla birleştirilebilir.

## 3. Bileşenler

```text
┌─────────────────────────────────────────────────────────┐
│                    Native Kullanıcı Arayüzü             │
│   Kurulum · İzinler · Cihaz düzeni · Transfer · Teşhis  │
└──────────────────────────┬──────────────────────────────┘
                           │ FFI / IPC
┌──────────────────────────▼──────────────────────────────┐
│                     FlowBridge Core                     │
│ Discovery │ Pairing │ Session │ Input │ Clipboard │ File│
└──────────────┬──────────────────────────────┬────────────┘
               │                              │
┌──────────────▼────────────┐   ┌─────────────▼────────────┐
│ Platform Input Adapter   │   │ Secure Transport         │
│ macOS / Windows          │   │ TLS 1.3 + TCP/QUIC       │
└──────────────────────────┘   └──────────────────────────┘
```

## 4. Ağ protokolü

### Keşif

- mDNS/DNS-SD servis ilanı
- İlanda yalnızca uygulama sürümü, geçici cihaz tanıtıcısı ve desteklenen protokol sürümü
- Kullanıcı adı, pano veya dosya bilgisi yayınlanmamalı

### Eşleştirme

1. Cihazlar geçici anahtar değişimi başlatır.
2. İki ekranda aynı kısa doğrulama kodu gösterilir.
3. Kullanıcı iki tarafta onaylar.
4. Cihaz kimlik anahtarları güvenli depoya yazılır.
5. Sonraki bağlantılarda karşılıklı kimlik doğrulama yapılır.

Kısa kod tek başına ağ anahtarı olarak kullanılmamalı; PAKE veya modern anahtar doğrulama yöntemi kullanılmalıdır. Kriptografik tasarım uygulama öncesinde ayrıca incelenmelidir.

### Taşıma katmanı

İlk prototip için TLS 1.3 üzerinde TCP daha basit olabilir. Ürün aşamasında giriş olaylarının gecikmesini dosya aktarımından ayırmak için QUIC akışları değerlendirilebilir.

Önerilen mantıksal kanallar:

- Kontrol/heartbeat
- Fare hareketleri
- Klavye olayları
- Pano meta verisi ve içeriği
- Dosya manifestosu
- Dosya parçaları

Dosya aktarımının yoğunluğu fare olaylarını bekletmemelidir. Trafik önceliği uygulanmalıdır.

## 5. Giriş olay modeli

Ham fiziksel keycode yerine iki katman tutulmalıdır:

- Fiziksel tuş konumu
- Kullanıcının üretmek istediği mantıksal karakter/komut

Bu sayede:

- `Command+C` → `Ctrl+C` gibi kısayollar çevrilebilir.
- Türkçe Q, İngilizce US ve diğer düzenlerde karakter kayması azaltılabilir.
- Oyun veya geliştirme araçlarında fiziksel tuş modu ayrıca sunulabilir.

İlk MVP yalnızca yaygın Türkçe Q ve US düzenleriyle sertifikalandırılmalı; diğer düzenler “deneysel” olarak işaretlenmelidir.

## 6. Fare koordinatları

Her ekran için:

- Fiziksel çözünürlük
- Mantıksal çözünürlük
- Ölçek/DPI
- Ekran konumu
- Aktif kenarlar

tutulmalıdır. Kenar geçişinde mutlak koordinat taşımak yerine normalize edilmiş 0–1 aralığı kullanılabilir. Böylece 5K Mac ekranından 1080p Windows ekranına geçerken imleç konumu oransal korunur.

## 7. Dosya aktarım protokolü

- Manifesto: ad, göreli yol, boyut, değiştirme zamanı, hash
- Parçalı aktarım: örneğin 4–16 MiB bloklar
- Her blok için bütünlük kontrolü
- Son dosya için SHA-256
- Geçici `.partial` dosyası
- Atomik tamamlanma/yeniden adlandırma
- Klasörlerde path traversal koruması
- Sembolik bağlantıların ilk sürümde reddedilmesi
- Maksimum dosya, klasör ve toplam boyut politikası

## 8. Durum makineleri

### Bağlantı durumu

```text
Discovered → Pairing → Trusted → Connecting → Connected
                                      ↑           │
                                      └─ Backoff ─┘
```

### Giriş sahipliği

```text
Local → EdgePending → Remote → Returning → Local
                         │
                    ConnectionLost
                         │
                         └────────────→ Local
```

Giriş sahipliği durum makinesi güvenlik açısından kritik olmalı; bağlantı kaybında hiçbir koşulda yerel kontrol kilitli kalmamalıdır.

## 9. Önerilen depo yapısı

```text
FlowBridge/
├── apps/
│   ├── macos/
│   └── windows/
├── crates/
│   ├── flowbridge-core/
│   ├── flowbridge-protocol/
│   ├── flowbridge-discovery/
│   ├── flowbridge-crypto/
│   └── flowbridge-transfer/
├── platform/
│   ├── macos-input/
│   └── windows-input/
├── tests/
│   ├── interoperability/
│   ├── network-chaos/
│   └── protocol-vectors/
└── docs/
```

## 10. Lisans yaklaşımı

Deskflow GPL-2.0 lisanslıdır. Kodunun türevi dağıtılırsa GPL yükümlülükleri doğar. Kapalı kaynak ticari ürün hedefleniyorsa Deskflow kodu kopyalanmadan bağımsız uygulama geliştirilmelidir.

Protokol uyumluluğu istenirse yalnızca açık teknik dokümantasyon temelinde temiz uygulama yaklaşımı değerlendirilmeli ve yayın öncesinde lisans uzmanından görüş alınmalıdır. Bu belge hukuki görüş değildir.
