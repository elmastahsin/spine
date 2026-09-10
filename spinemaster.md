# Spine v0.1 · Claude Code Implementation Prompt

Aşağıdaki bloğu Claude Code'a olduğu gibi yapıştır. Claude Code'u mevcut Xcode projesinin kök klasöründe (Spine.xcodeproj'un bulunduğu yer) başlat.

---

```
# Görev
Spine adında, macOS menu bar'da çalışan, basit ve open source bir postür uygulaması geliştir.
Uygulama AirPods hareket sensörlerini (CMHeadphoneMotionManager) kullanarak baş eğimini takip eder
ve postür bozulduğunda kulaklığa sesli uyarı verir. Kamera yok, network yok, üçüncü parti bağımlılık yok.

# Mevcut durum
- Bu klasörde çalışan bir Xcode projesi var (SwiftUI, macOS App, target adı: Spine).
- SpineApp.swift içinde çalışan bir prototip var: MenuBarExtra + CMHeadphoneMotionManager + AVSpeechSynthesizer.
  Bunu referans al, sonra aşağıdaki mimariye göre yeniden yapılandır.
- Info.plist ayarları target Info sekmesinde tanımlı ve ÇALIŞIYOR, bunlara dokunma:
  NSMotionUsageDescription (String), LSUIElement = YES.
- Minimum deployment: macOS 14.0.

# Kesin kurallar
- project.pbxproj dosyasını ASLA elle düzenleme. Yeni dosyaları Spine/ klasörüne koy.
  Önce projenin Xcode synchronized folder kullanıp kullanmadığını kontrol et. Kullanmıyorsa dur ve bana
  hangi dosyaları Xcode'da manuel eklemem gerektiğini söyle.
- Üçüncü parti paket yok. Sadece SwiftUI, CoreMotion, AVFoundation, Foundation, Observation.
- Network çağrısı, analytics, telemetry yok. Tüm veri cihazda kalır.
- Kod, yorumlar, README ve commit mesajları İngilizce.
- Kullanıcıya görünen metinler ve sesli mesajlar String Catalog (Localizable.xcstrings) ile
  en ve tr olarak lokalize. Varsayılan dil sistem dili, yoksa en.
- Her fazın sonunda şu komutla build doğrula ve hata varsa düzeltmeden sonraki faza geçme:
  xcodebuild -project Spine.xcodeproj -scheme Spine -configuration Debug build
- Her faz sonunda git commit at (Conventional Commits formatı).

# Mimari
Postür mantığını CoreMotion'dan tamamen ayır, böylece AirPods olmadan unit test yazılabilsin.

Spine/
  App/SpineApp.swift              MenuBarExtra (style: .window), app state injection
  Core/AppState.swift             enum: waitingForAirPods, needsCalibration, calibrating(progress),
                                  monitoring(PostureStatus), paused
  Core/PostureEvaluator.swift     SAF Swift, CoreMotion import etmez. Girdi: pitch (derece) + timestamp.
                                  EMA smoothing, eşik, grace period, hysteresis, cooldown.
                                  Çıktı: PostureStatus (good, drifting, bad) + shouldNudge: Bool
  Core/Calibrator.swift           SAF Swift. Sample toplar, ortalama ve standart sapma hesaplar.
  Services/HeadMotionService.swift CMHeadphoneMotionManager wrapper. Bağlantı durumu + pitch stream.
                                  İlk motion verisi geldiğinde de "connected" kabul et
                                  (delegate connect callback'i her zaman gelmiyor).
  Services/AudioNudger.swift      AVSpeechSynthesizer. Mesaj havuzundan rastgele seçim,
                                  konuşurken yeni mesajı atla, dile göre voice seç.
  Services/SettingsStore.swift    UserDefaults: baseline, sensitivity, cooldown, voiceEnabled
  UI/MenuContentView.swift        State'e göre değişen menü içeriği
  UI/CalibrationView.swift        Kalibrasyon akışı
SpineTests/
  PostureEvaluatorTests.swift
  CalibratorTests.swift

# Kullanıcı akışı
1. İlk açılış, AirPods yok:
   Menü: "AirPods'unu tak" mesajı + kısa açıklama. İkon: "airpods" SF Symbol, soluk.
2. AirPods bağlandı, baseline yok:
   Menü: "Kalibrasyon gerekli" + "Kalibre et" butonu.
3. Kalibrasyon:
   - Kullanıcı butona basınca sesli: "Dik otur ve ekrana bak."
   - 3 saniye geri sayım (UI'da progress göster), bu sürede pitch sample'ları topla.
   - Standart sapma 3 dereceden büyükse kalibrasyonu reddet, sesli ve yazılı:
     "Çok hareket ettin, tekrar dene." ve başa dön.
   - Başarılıysa ortalamayı baseline olarak kaydet, sesli: "Kalibrasyon tamam."
4. Monitoring:
   - Sapma = abs(smoothedPitch - baseline)
   - Sensitivity preset'leri: low = 16°, medium = 12°, high = 8° (varsayılan medium)
   - Hysteresis: bad durumuna eşik aşılınca girer, eşik - 4° altına inince çıkar.
   - Grace period: bad durumu 8 saniye kesintisiz sürmeden uyarı verme
     (kısa süreli klavyeye bakmak uyarı üretmesin).
   - Cooldown: iki uyarı arası en az 90 saniye (ayarlanabilir: 60, 90, 180).
   - Uyarı mesaj havuzu (tr): "Dik dur", "Omuzlarını geri al", "Başını kaldır", "Ekrana gömüldün, dikleş"
     (en): "Sit up straight", "Roll your shoulders back", "Lift your head", "You're sinking into the screen"
   - Menü bar ikonu: good = figure.stand, bad = figure.fall, paused = pause.circle
5. AirPods çıkarılınca: monitoring durur, state waitingForAirPods, baseline korunur.
   Tekrar takılınca doğrudan monitoring'e dön (yeniden kalibrasyon isteme).

# Menü içeriği (monitoring durumunda)
- Durum satırı: "Postür iyi" / "Postür bozuk"
- Canlı sapma değeri (derece, tam sayı)
- Sensitivity picker (Low / Medium / High)
- Cooldown picker
- Sesli uyarı toggle
- "Yeniden kalibre et"
- "Duraklat / Devam et"
- "Çık"

# Testler (PostureEvaluator ve Calibrator için, XCTest veya Swift Testing)
- Eşik altında kalan veri asla nudge üretmez.
- Eşik üstü ama grace period dolmadan nudge yok.
- Grace period dolunca tam 1 nudge, cooldown içinde ikinci nudge yok.
- Hysteresis: eşik ile eşik - 4° arasındaki değerler state'i değiştirmez.
- Calibrator: düşük varyanslı sample'lar başarılı, yüksek varyanslılar reddedilir.
- Zaman için gerçek Date() kullanma, timestamp'i dışarıdan enjekte et.

# Open source dosyaları
- README.md: ne yapar (1 paragraf), gereksinimler (macOS 14+, head tracking destekli AirPods:
  Pro, Max, 3. nesil ve üstü), build adımları, privacy bölümü (veri cihazdan çıkmaz),
  bilinen sınırlamalar (AirPods omurgayı değil baş rotasyonunu ölçer; klavyeye bakmak
  sapma olarak algılanabilir), Türkçe sesli uyarı için sistem sesi indirme notu.
- LICENSE: MIT, copyright sahibi: Tahsin
- .gitignore: Xcode + macOS standart
- CONTRIBUTING.md: kısa, build ve test komutları

# Fazlar
Faz 0: Kodu inceleme ve plan. Hiçbir dosya değiştirmeden önce mevcut yapıyı oku,
       synchronized folder durumunu kontrol et, bana dosya planını göster ve onayımı bekle.
       Onaydan sonra proje kökünde kısa bir CLAUDE.md oluştur (kurallar + mimari + build komutu).
Faz 1: Core (AppState, PostureEvaluator, Calibrator) + testler. Testler geçmeli.
Faz 2: Services (HeadMotionService, AudioNudger, SettingsStore).
Faz 3: UI (MenuContentView, CalibrationView) + SpineApp entegrasyonu. Eski prototip kodunu kaldır.
Faz 4: Lokalizasyon (en, tr).
Faz 5: README, LICENSE, .gitignore, CONTRIBUTING.

# Kapsam dışı (v0.1'de YAPMA)
Yorgunluk/mola bildirimleri, launch at login, istatistik/grafik, onboarding penceresi,
App Store dağıtımı, notarization, kamera modu.

# Done kriteri
- Build hatasız, tüm testler geçiyor.
- AirPods tak → kalibre et → 10 saniye öne eğil → tek sesli uyarı → dik otur → ikon figure.stand'e döner.
- AirPods çıkar/tak döngüsünde crash yok, baseline korunuyor.
- Faz sonunda bana manuel test etmem gereken adımların kısa bir listesini ver.
```

---

## Kullanım notları

1. Claude Code'u plan mode'da başlat (Shift + Tab), Faz 0 çıktısını gör, sonra onay ver.
2. Faz 3 sonrası manuel testi AirPods takılıyken sen yapmalısın; Claude Code motion verisini simüle edemez, bu yüzden logic testleri Core katmanında.
3. Build sırasında imza hatası çıkarsa Xcode'da Signing & Capabilities > Team ayarını kontrol et, prompt'u değiştirme.