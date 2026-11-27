# تقرير البراند الأبيض مع استثناء زر Packages

**التاريخ:** 2026-11-27

**القرار الأساسي:** كلمة `TokiGo` بالأبيض فقط في البراند وشاشات البداية، بدون `Go` الأحمر القديم.

**استثناء لاحق من المالك (نفس اليوم):** تُعاد المظلة **إلى زر Packages السريع في Home فقط**. صفحة Onboarding القديمة ما زالت تشارك نفس الـwidget، لكنها لم تعد مسار إقلاع.

**قرار إقلاع نهائي (نفس اليوم):** أُلغي الستارت أب/Onboarding بالكامل؛ التطبيق يفتح مباشرة على Home. أُزيلت طبقة الـbranding المكررة في Android 12، وضُبطت شاشة iOS على الحقل الداكن نفسه.

**ملاحظة نطاقية:** لم يُضف أي شريط تنقل سفلي. تكبير الأيقونات يخص أزرار Home السريعة الأربعة فقط.

## جدول المواضع والإجراء

| السطح | الملف / المسار | ما كان موجوداً | الإجراء النهائي | الحالة |
|---|---|---|---|---|
| أزرار Home السريعة | `lib/app/widgets/home_nav_buttons.dart` | مظلة `parasolAsset`، أيقونات 24dp، فتحة 36dp | `iconSize = 28`، `iconSlotHeight = 42`؛ **المظلة تعود لزر Packages فقط** عبر ملفين مستقلين `assets/icon/packages_parasol*_1024.png`. الأيقونة المرئية والنص في وسط كل زر، مع الحفاظ على RTL وعدم الـoverflow | ✅ |
| مسار الإقلاع | `lib/app/router/go_router_config.dart` | redirect إلى `/onboarding` وRoute مسجل للصفحة الأولى | أُزيل الـwatch والـredirect و`/onboarding`؛ `initialLocation` هو Home مباشرة | ✅ |
| صفحة Onboarding القديمة | `lib/features/profile/presentation/pages/onboarding_page.dart` | يستخدم نفس `HomeActionGlyph` كصفحة أولى | تبقى ملفاً غير موصول بالإقلاع، وتشارك المقاس الجديد والمظلة المستثناة؛ لا تعديل واجهة منفصل | ✅ |
| مساعد AI | `lib/core/widgets/ai_robot_avatar.dart` | تعليقات تصف الأصل بأنه مظلة شفافة | يبقى على العلامة البيضاء `app_icon_adaptive_*`؛ لا مظلة هنا | ✅ |
| كلمة التطبيق داخل التطبيق | `lib/core/ui/app_wordmark.dart` | `Toki` بلون `wordmarkInk` و`Go` بلون `brandRed` | كلا الجزأين بلون نص الثيم (`textPrimary`)؛ لا أحمر في الاسم داخل التطبيق | ✅ |
| ماسترات البراند | `tool/branding/generate_wordmark.py`, `assets/branding/logo_wordmark*.png` | حبر أسود + `Go` أحمر | توليد آلي بالأبيض للجزأين؛ العلامة المضغوطة تكتب فوق أصول الأيقونة القديمة، لكنها **لا تلمس** ملفات المظلة المستقلة | ✅ |
| شاشة الإقلاع (ماسترات) | `tool/branding/generate_splash.py`, `assets/branding/logo_splash*.png` | أيقونة مظلة فوق الاسم | الاسم الأبيض وحده على حقل `#111111`، بلا بلاطة أيقونة ولا مظلة ولا أحمر؛ لم تعد طبقة `logo_branding*.png` تُستخدم في Android 12 | ✅ |
| الإقلاع الأصلي لكل المنصات | `pubspec.yaml`, `android/app/src/main/res/**`, `ios/Runner/Assets.xcassets/LaunchImage.imageset/**`, `ios/Runner/Base.lproj/LaunchScreen.storyboard`, `web/splash/**` | أصول قديمة + طبقة branding ثانية + storyboard أبيض | إعادة توليد عبر `flutter_native_splash:create` ثم `python scripts/normalize_ios_launch_screen.py`؛ Light وDark متطابقان، ولا مظلة ولا أحمر في أي مخرج | ✅ |
| أيقونة المشغّل الخارجية | `tool/branding/generate_launcher_wordmark.py`, `generate_app_icon.py`, `assets/icon/*.svg` | مولّد قديم قد يعيد المظلة | المولّد القديم يفوّض إلى مولّد الكلمة البيضاء؛ كل SVGs تشير إلى الـrasters الجديدة | ✅ |
| فصل الأصول | `assets/icon/packages_parasol_1024.png`, `packages_parasol_dark_1024.png`, `pubspec.yaml` | المظلة كانت داخل `app_icon_adaptive_*` المستخدم في الإقلاع/AI | استُخرجت البكسلات الأصلية من `HEAD` إلى ملفين جديدين مُدرجين في `pubspec`؛ لا يمكن لاستثناء Packages أن يعيد المظلة لأي سطح آخر | ✅ |
| التحقق من الأصول | `scripts/verify_brand_assets.py` | يتوقع `Go` أحمر في الماستر | فحص ماستر أبيض بلا أحمر؛ تعداد الأحمر لا يجد `#FF2D2D`/`#FF5C5C` في أصول البراند أو الإقلاع | ✅ |
| التوثيق | `DESIGN.md`, `lib/core/theme/app_colors.dart` | `Wordmark Red` كلون للشعار | استبداله بـ `Brand White`، وتوثيق استثناء Packages في قسم Navigation | ✅ |
| الاختبارات | `test/{app_wordmark,brand_wordmark,brand_icon_splash,home_action_bar,home_design_spec,no_startup_native_splash,onboarding_service_buttons,ai_robot_avatar,theme_token_consistency}_test.dart` | تثبت 24/36 والمظلة والـ`Go` الأحمر | 28/42، توسيط مجموعة الأيقونة+النص، إقلاع مباشر بلا gate، أيقونة splash مفردة، أصل المظلة المستقل لـPackages، والعلامة البيضاء لبقية الأسطح؛ فحص بكسل يمنع الأحمر في الإقلاع | ✅ |
| صورة سياحية في دليل الاستكشاف | `assets/explore/manifest.json`, `lib/core/geo/explore_catalog.dart` | صورة «Umbrellas at Caudan Waterfront Mall» كوجهة Port Louis | **تركت كما هي عن قصد**: محتوى سفر مرخّص، وليس هوية البراند | ⏭️ خارج النطاق |

## لماذا ملف منفصل للمظلة؟

لو أعدنا كتابة `assets/icon/app_icon_adaptive_*_1024.png` بالمظلة لعادت المظلة تلقائياً إلى Android 12 splash ومساعد AI لأنهما يستخدمان نفس المسار. لذلك:

- `app_icon_adaptive_*` يبقى علامة `TokiGo` بيضاء.
- `packages_parasol_*` يحمل المظلة الأصلية، ويُستخدم من `HomeActionGlyph` فقط (وبالتالي صفحة Onboarding القديمة غير الموصولة بالإقلاع).
- المولّدات تعيد كتابة الأول فقط، فأي إعادة توليد روتينية لا تلمس الاستثناء.

## تحديثات الواجهة اللاحقة (2026-11-27)

- الإقلاع المباشر: أُزيل redirect إلى `/onboarding` والـRoute المسجل؛ لا توجد شاشة ستارت أب Flutter قبل Home.
- أُزيل `windowSplashScreenBrandingImage` من Android 12 ( light و night ) مع حذف راسترات `android12branding.png`؛ تبقى أيقونة splash واحدة بالاسم الأبيض على `#111111`.
- شاشة iOS: `contentMode="scaleAspectFit"` والحقل الثابت `#111111` في `LaunchScreen.storyboard`، مع سكربت إعادة ضبط بعد كل توليد حتى لا يعيد المولّد الخلفية البيضاء.
- أيقونات Home السريعة: صندوق `28dp` داخل فتحة `42dp`؛ بكسلات المظلة المرئية `24dp` لمطابقة الوزن البصري لأيقونات Material التي تحتفظ بحاشية داخلية. الأيقونة والنص متوسطان في كل زر.
- صفحة Onboarding القديمة (غير موصولة بالإقلاع): ترث `28/42` والأيقونة المفردة `64dp` داخل بلاطة `128dp`.
- حالة فشل تحميل الإقامات القريبة: العنوان **“Could not load”** والنص تحته **“Please check your connection.”** (والعربية: «تعذر التحميل» / «يرجى التحقق من اتصالك بالإنترنت.»).
- أُزيل الشريط العلوي العام **“You are offline”** من `lib/app/app.dart`؛ تبقى حالات الخطأ/الكاش داخل الصفحات نفسها.
- **تحصين فحص الأصول:** `scripts/verify_brand_assets.py` صار يفحص كل صور الإقلاع على كل المنصات وكل الكثافات (Android mdpi→xxxhdpi مع night وv31، iOS 1x/2x/3x فاتح وداكن، Web 1x→4x) ويرفض أي أحمر مشبع أو صورة إقلاع بلا اسم أبيض — 36 صورة بعد حذف طبقة branding المكررة.
- **iOS والسلاش الأحمر:** الأصول المصدرية على `Main` خالية من الأحمر تماماً (فحص بكسل + `Assets.car` غير متاح من Windows). صورة سبلاش أرسلها المالك من workflow iOS أظهرت 2983 بكسل أحمر في نطاق `(430,842)–(550,911)` مع مظلة فوق الاسم، أي أن التطبيق المثبّت يستخدم أصولاً قديمة؛ لا يوجد أصل بهذه الألوان في المستودع الحالي، وصور الإقلاع المولّدة مطابقة للماستر الجديد. العلاج على Mac: حذف التطبيق من المحاكي/الجهاز، `flutter clean`، `flutter pub get`، `cd ios && pod install --repo-update`، حذف `DerivedData`، إعادة تشغيل المحاكي، ثم بناء وتثبيت جديد. إن بقي بعد ذلك، افحص `Runner.app/LaunchImage*.png` داخل الحزمة المبنية نفسها.

## نتائج التحقق الفعليّة

- `python tool/branding/generate_wordmark.py --check` → نجح (الماسترات مطابقة للمواصفة).
- `python scripts/verify_brand_assets.py` → `all brand asset checks passed`؛ لا أحمر مشبع في أصول البراند أو الإقلاع (36 صورة).
- `dart run flutter_native_splash:create` ثم `python scripts/normalize_ios_launch_screen.py` → نجحا، وحدّثا Android / Android 12+ / iOS / Web وأبقيا iOS على `#111111` / `scaleAspectFit`.
- `dart format --output=none --set-exit-if-changed` على ملفات Dart المعدّلة → `0 changed`.
- `flutter analyze` → لا `error`، و478 ملاحظة/تحذيراً متبقية من قبل (deprecations وunused imports في ملفات أخرى)؛ لا ملاحظة جديدة في الملفات المعدّلة. خرج التحليل برمز 1 بسبب هذه التحذيرات القديمة.
- `flutter test` → **686 اختباراً ناجحاً**، صفر فشل (بما فيها اختبار الإقلاع بلا Onboarding، وتوسيط المجموعة، والحجم البصري `24dp` للمظلة).
- `.github/workflows/ios-clean-splash.yml` → بناء نظيف على `macos-15` من `Main` (لأن `macos-14` أُعزل في 2026-11-02)، تثبيت على محاكي بـ`xcrun simctl io ... screenshot` (متوافق مع Xcode الحديث)، التقاط 3 صور، فحص **الإطار الأول فقط** لأن الإطارات التالية قد تكون واجهة التطبيق؛ أي بكسل أحمر قديم في الإطار الأول يُفشل الـjob، والصور تُرفع كـartifact حتى عند الفشل. جرّب الفاحص على صورة المالك فأبلغ `2983 retired red pixels`.
- `git diff --check` → نظيف (أُزيلت مسافات زائدة أنشأها مولّد الويب في `web/index.html` عبر سكربت التطبيع).

التحقق بصري مباشر على جهاز فعلي **لم يُجرَ**؛ حلّلت صورة أرسلها المالك بكسلياً، وبقية الفحوص بكسلية وعبر widget tests فقط. إن ظهر السبلاش القديم على جهاز موجود، يلزم إعادة تثبيت نظيفة (Uninstall ثم Install) قبل الحكم على النتيجة.

## الضوابط

- لم يُنفّذ `git add` / `commit` / `push`، ولم تُقرأ `.env`.
- لم يُجرَ أي حجز أو دفع أو تشغيل Sandbox/Production.
- لم يُحذف أي ملف مصدر؛ أُزيلت فقط راسترات `android12branding.png` المولّدة لأنها لم تعد مستخدمة.
- التغييرات كلها محلية في مساحة العمل، وجاهزة للمراجعة قبل أي خطوة تالية من خارطة التطوير.
