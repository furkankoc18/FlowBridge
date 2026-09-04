# Pazar ve Rakip Analizi

> Bu belge ürün araştırmasıdır ve gelecek hedefleri içerir. Uygulanmış özellikler için kök `README.md` dosyasına bakın.

## 1. Pazarın özeti

Yazılımsal klavye-video-fare (software KVM) pazarı yeni değil. Bu nedenle fırsat, özelliği ilk kez icat etmekte değil; Mac + Windows kullanımını daha güvenilir, daha güvenli ve daha kolay hâle getirmektedir.

Rakiplerin varlığı aynı zamanda problemin gerçek olduğunu doğrular. Ancak ücretsiz ve açık kaynak çözümler bulunduğu için yalnızca “fareyi diğer bilgisayara geçiriyoruz” vaadi ücretli ürün oluşturmak için yeterli değildir.

## 2. Rakip karşılaştırması

| Ürün | Platform | Klavye/fare | Pano | Dosya aktarımı | Temel boşluk |
|---|---|---:|---:|---:|---|
| Deskflow | macOS, Windows, Linux, BSD | Evet | Evet | Hayır | Teknik kurulum, dosya transferi yok, bazı platform sorunları |
| Synergy | macOS, Windows, Linux | Evet | Evet | Sürüme bağlı | Ticari; bizim sadelik iddiamızla doğrudan rakip |
| Logitech Flow | macOS, Windows | Evet | Evet | Evet | Uyumlu Logitech donanımı gerekir |
| Mouse Without Borders | Windows | Evet | Evet | Sınırlı | Mac/Linux yok; dosya/folder sınırlamaları |
| Hydra | macOS, Windows, Linux | Evet | Evet | macOS + Windows | Yeni rakip; farklı ağ ve dosya transferi iddiası var |
| Input Leap / Barrier | macOS, Windows, Linux | Evet | Evet | Hayır | Bakım ve Wayland geçişi sorunları |

## 3. Deskflow'da gözlenen boşluklar

### macOS kurulum sürtünmesi

Deskflow, macOS'ta Erişilebilirlik ve Input Monitoring izinleri istiyor. Projenin kendi dokümantasyonu, bazı doğrudan indirilen paketlerde notarization eksikliği nedeniyle kullanıcıların `xattr` komutu çalıştırması gerekebildiğini belirtiyor. Bu, teknik olmayan kullanıcı için ciddi aktivasyon kaybıdır.

Kaynak: [Deskflow GitHub README](https://github.com/deskflow/deskflow)

### Dosya ve klasör aktarımı yok

Deskflow panosu metin ve görsel için kullanılabilse de Finder/Explorer dosyalarını karşı bilgisayara yapıştırmak desteklenmiyor.

Kaynak: [Deskflow issue #8399](https://github.com/deskflow/deskflow/issues/8399)

### Ağ değişiminde yeniden bağlantı

IP değişimi, farklı ağa geçiş veya uyku/uyanma sonrası keşif ve yeniden bağlantı kullanıcıların sorun bildirdiği alanlardan biri.

Kaynak: [Deskflow issue #9627](https://github.com/deskflow/deskflow/issues/9627)

### Wayland ve platform tutarsızlıkları

Deskflow Wayland desteğine sahip ancak proje bazı özelliklerin eksik veya sorunlu olabileceğini açıkça belirtiyor. FlowBridge ilk aşamada Linux'u kapsam dışı bırakarak kalite riskini azaltacaktır.

Kaynak: [Deskflow bilinen sorunlar](https://github.com/deskflow/deskflow/wiki/Known-Issues)

## 4. Diğer rakiplerden öğrenilenler

Microsoft Mouse Without Borders'ın resmî belgelerinde dosya kopyalamanın tek dosya ve 100 MB ile sınırlı olduğu, klasör veya çoklu dosyanın doğrudan desteklenmediği belirtiliyor. Bu durum güvenilir klasör aktarımının gerçek bir farklılaştırıcı olabileceğini gösteriyor.

Kaynak: [Microsoft Mouse Without Borders belgeleri](https://learn.microsoft.com/en-us/windows/powertoys/mouse-without-borders)

Logitech Flow, işletim sistemleri arasında imleç ve dosya paylaşımını ürünleştirmiş durumda; ancak çözüm Logitech ekosistemine bağlı.

Kaynak: [Logitech Flow](https://www.logitech.com/en-gb/software/flow)

Hydra; dosya transferi, çevrim içi relay ve klavye düzeni dönüşümü gibi özelliklerle bizim düşündüğümüz boşlukların bir bölümüne girmiş durumda. FlowBridge'in savunulabilir farkı yalnızca özellik listesi değil, kurulumu ve bağlantı iyileştirmeyi otomatikleştiren kullanıcı deneyimi olmalıdır.

Kaynak: [Hydra GitHub deposu](https://github.com/PacAnimal/hydra)

## 5. Konumlandırma

### Kategori

Cross-device workspace / software KVM

### Ana mesaj

> Mac ve Windows'un tek bilgisayar gibi çalışsın.

### Destek mesajı

> Her marka klavye ve fareyle çalışır; teknik ağ ayarı gerektirmez.

### Rakibe göre farklılaşma

- Deskflow'a karşı: Daha kolay kurulum, dosya/klasör aktarımı, otomatik teşhis
- Logitech Flow'a karşı: Donanım bağımsızlığı
- Mouse Without Borders'a karşı: Gerçek Mac + Windows desteği
- Synergy'ye karşı: Yerel öncelikli, sade ve modern Mac + Windows uzmanlığı
- Hydra'ya karşı: İmzalı dağıtım, kurumsal seviyede onboarding ve bağlantı iyileştirme

## 6. SWOT

### Güçlü yönler

- Net ve kolay gösterilebilir kullanım senaryosu
- Günlük kullanım alışkanlığı oluşturma potansiyeli
- Donanım satın alma ihtiyacını azaltması
- Mac + Windows kullanıcı segmentinde açık değer önerisi

### Zayıf yönler

- İşletim sistemi seviyesinde karmaşık ve hassas geliştirme
- Ücretsiz/açık kaynak rakiplerin bulunması
- Küçük bir gecikmenin bile kullanıcı deneyimini bozması
- Geniş donanım ve ağ test matrisi

### Fırsatlar

- Hibrit çalışma ve çok cihazlı masa düzenleri
- Donanımdan bağımsız AirDrop benzeri deneyim
- Teknik ekipler için yönetim ve teşhis özellikleri
- Daha sonra Linux, Android tablet veya güvenli relay desteği

### Tehditler

- Apple veya Microsoft'un işletim sistemi güncellemeleriyle giriş API'lerini değiştirmesi
- Synergy, Hydra veya Logitech'in kurulum deneyimini iyileştirmesi
- macOS güvenlik izinlerinin kullanıcı güvenini azaltması
- İsim ve marka çakışmaları

## 7. İsim riski

“FlowBridge” adı hâlihazırda VPN istemcisi, e-ticaret entegrasyonu ve AI otomasyon platformu dahil farklı yazılımlar tarafından kullanılıyor. `flowbridge.com`, `flowbridge.io` ve `flowbridge.app` alanlarında aktif ürünler bulunuyor. Bu nedenle FlowBridge şimdilik yalnızca proje klasörü ve kod adı olmalıdır.

Ürün yayınlanmadan önce:

- Türkiye, AB, Birleşik Krallık ve ABD marka veri tabanları aranmalı.
- App Store, Microsoft Store, GitHub ve alan adı kullanılabilirliği incelenmeli.
- Benzer sınıftaki yazılımlarla karışmayacak yeni bir isim seçilmeli.

Bu doküman hukuki görüş değildir.
