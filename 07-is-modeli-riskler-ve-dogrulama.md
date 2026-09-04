# İş Modeli, Riskler ve Doğrulama

> Bu belge ürün araştırmasıdır ve açık kaynak lisans kararından önce hazırlanmıştır. Güncel lisans ve sürüm kapsamı için kök `README.md` dosyasına bakın.

## 1. İş modeli hipotezi

Ücretsiz rakipler nedeniyle temel fare/klavye paylaşımını yüksek abonelikle satmak zor olacaktır. İlk öneri freemium veya tek seferlik kişisel lisans modelidir.

### Free

- İki cihaz
- Yerel ağ
- Klavye ve fare paylaşımı
- Metin panosu
- Temel dosya aktarımı

### Pro — hipotez

- Üç veya daha fazla cihaz
- Klasör ve büyük dosya transferinde gelişmiş özellikler
- Pano geçmişi ve gizlilik kuralları
- Ağ profilleri
- Özel tuş eşleme
- Öncelikli destek

### Teams — daha sonra

- Merkezi dağıtım
- Cihaz politikaları
- SSO
- Denetim kayıtları
- Çevrimdışı lisanslama

Fiyat belirlenmemiştir. Fiyat, landing page ve ödeme niyeti testlerinden sonra seçilmelidir. Kullanıcı görüşmesinde doğrudan “kaç dolar verirsin?” sorusu güvenilir veri üretmez.

## 2. Dağıtım

### macOS

- Developer ID ile imzalı ve Apple notarization işleminden geçmiş DMG/PKG
- Daha sonra Homebrew cask
- Gerekli giriş izinleri nedeniyle Mac App Store sandbox kuralları ayrıca doğrulanmalı; mağaza dışı dağıtım ana kanal kabul edilmeli

### Windows

- Kod imzalı installer veya MSIX
- SmartScreen itibarının zamanla oluşacağı hesaba katılmalı
- Winget paketi daha sonraki kanal olabilir

### Maliyet kalemleri

- Apple Developer Program
- Windows kod imzalama sertifikası
- Crash reporting ve isteğe bağlı telemetri
- Web sitesi, güncelleme manifestosu ve indirme CDN'i
- Çoklu test cihazları
- Güvenlik incelemesi
- Destek operasyonu

## 3. En büyük riskler

| Risk | Olasılık | Etki | Azaltma |
|---|---:|---:|---|
| Fare/klavye gecikmesi | Orta | Çok yüksek | Önce teknik prototip, trafik önceliği, uzun süreli test |
| macOS izin sorunları | Yüksek | Yüksek | Native onboarding, izin sağlık kontrolü, imzalı/noter onaylı paket |
| İşletim sistemi güncellemesi | Yüksek | Yüksek | Beta kanal testleri, adaptör mimarisi, hızlı güncelleme |
| Ücretsiz rakip baskısı | Yüksek | Orta | Sadelik, güvenilirlik ve destek üzerinden farklılaşma |
| Güvenlik açığı | Orta | Çok yüksek | Tehdit modeli, fuzzing, haricî inceleme, güvenli varsayılanlar |
| İsim çakışması | Yüksek | Orta | FlowBridge'i kod adı tutmak, erken marka araştırması |
| Dosya kaybı/bozulma | Orta | Çok yüksek | Parçalı aktarım, geçici dosya, hash doğrulaması |
| Çok geniş platform kapsamı | Yüksek | Yüksek | İlk sürümü Mac + Windows ve iki cihazla sınırlamak |

## 4. Doğrulanması gereken hipotezler

1. Mac + Windows kullanıcıları bu sorunu haftada birkaç kez yaşıyor.
2. Mevcut çözümleri kurulum veya güvenilirlik nedeniyle bırakıyorlar.
3. Dosya ve klasör aktarımı satın alma kararını etkiliyor.
4. Kullanıcılar hesap açmadan çalışan yerel çözümü tercih ediyor.
5. İmzalı, anlaşılır ve desteklenen uygulama için ücretsiz alternatife rağmen ödeme yapıyorlar.

## 5. Kullanıcı görüşmesi soruları

- Aynı anda kaç bilgisayar kullanıyorsunuz?
- Son kez iki cihaz arasında metin veya dosya taşırken ne yaptınız?
- Şu anda hangi klavye/fare paylaşım çözümünü kullanıyorsunuz?
- Kurarken veya kullanırken nerede zorlandınız?
- Bağlantı koptuğunda ne yapıyorsunuz?
- Dosya aktarımı için hangi aracı kullanıyorsunuz?
- Güvenlik veya pano paylaşımı konusunda sizi ne endişelendirir?
- Bu sorunu çözmek için son altı ayda para veya donanım harcadınız mı?

Görüşmede ürün anlatılmadan önce geçmişte yaşanmış somut davranışlar sorulmalıdır.

## 6. Landing page deneyi

İki mesaj A/B test edilebilir:

### Mesaj A — Kesintisiz çalışma

> Mac ve Windows'un tek bilgisayar gibi çalışsın.

### Mesaj B — Donanımsız çözüm

> KVM satın almadan tek klavye ve fareyle iki bilgisayarı kontrol et.

Ölçümler:

- Ziyaretçi → beta başvurusu dönüşümü
- Hangi işletim sistemi çiftinin kullanıldığı
- En çok istenen özellik
- Mevcut çözüm
- Beta kurulumunu gerçekten tamamlama oranı

## 7. Devam / durdur karar kapıları

### Devam et

- Görüşmelerde problem sık ve güncelse
- En az beş kişi kendi bilgisayarında alpha testine giriyorsa
- Teknik prototipte fare gecikmesi kabul edilebilirse
- Kullanıcılar kurulum akışını yardım almadan tamamlayabiliyorsa

### Kapsamı değiştir

- Fare paylaşımı yeterince güvenilir değil fakat dosya aktarımı ilgi görüyorsa, ürün yerel AirDrop alternatifi olarak yeniden konumlandırılabilir.
- Tüketici ödeme isteği düşük fakat ekiplerin merkezi yönetim ihtiyacı güçlüyse B2B yönü denenebilir.

### Durdur

- Görüşülen kullanıcılar mevcut ücretsiz çözümlerden memnunsa
- Teknik prototip farklı donanımlarda kararlı giriş sağlayamıyorsa
- macOS izinleri kabul edilebilir onboarding ile çözülemiyorsa

## 8. Araştırma kaynakları

- [Deskflow](https://github.com/deskflow/deskflow)
- [Deskflow bilinen sorunlar](https://github.com/deskflow/deskflow/wiki/Known-Issues)
- [Deskflow dosya panosu issue'su](https://github.com/deskflow/deskflow/issues/8399)
- [Deskflow ağ keşfi issue'su](https://github.com/deskflow/deskflow/issues/9627)
- [Synergy özellikleri](https://symless.com/synergy/features)
- [Microsoft Mouse Without Borders](https://learn.microsoft.com/en-us/windows/powertoys/mouse-without-borders)
- [Logitech Flow](https://www.logitech.com/en-gb/software/flow)
- [Hydra](https://github.com/PacAnimal/hydra)
