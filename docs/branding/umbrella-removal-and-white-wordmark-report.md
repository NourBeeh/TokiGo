# تقرير البراند الأبيض مع استثناء زر Packages

**التاريخ:** 2026-11-27  
**القرار الأساسي:** كلمة `TokiGo` بالأبيض فقط في البراند وشاشات البداية، بدون `Go` الأحمر القديم.  
**استثناء لاحق من المالك (نفس اليوم):** تُعاد المظلة **إلى زر Packages السريع فقط** في Home وOnboarding. كل الأسطح الأخرى تبقى بالاسم الأبيض بدون مظلة.  
**ملاحظة نطاقية:** لم يُضف أي شريط تنقل سفلي. تكبير الأيقونات يخص أزرار Home السريعة فقط، وOnboarding يشارك نفس الـwidgets فحدّث تلقائياً.

## جدول المواضع والإجراء

| السطح | الملف / المسار | ما كان موجوداً | الإجراء النهائي | الحالة |
|---|---|---|---|---|
| أزرار Home السريعة | `lib/app/widgets/home_nav_buttons.dart` | مظلة `parasolAsset`، أيقونات 24dp، فتحة 36dp | `iconSize = 28`، `iconSlotHeight = 42`؛ **المظلة تعود لزر Packages فقط** عبر ملفين مستقلين `assets/icon/packages_parasol*_1024.png`، مع الحفاظ على RTL وعدم الـoverflow | ✅ |
| شاشة Onboarding | `lib/features/profile/presentation/pages/onboarding_page.dart` | يستخدم نفس `HomeActionGlyph` | يرث المقاس الجديد والمظلة المستثناة تلقائياً؛ لا تعديل منفصل | ✅ |
| مساعد AI | `lib/core/widgets/ai_robot_avatar.dart` | تعليقات تصف الأصل بأنه مظلة شفافة | يبقى على العلامة البيضاء `app_icon_adaptive_*`؛ لا مظلة هنا | ✅ |
| كلمة التطبيق داخل التطبيق | `lib/core/ui/app_wordmark.dart` | `Toki` بلون `wordmarkInk` و`Go` بلون `brandRed` | كلا الجزأين بلون نص الثيم (`textPrimary`)؛ لا أحمر في الاسم داخل التطبيق | ✅ |
| ماسترات البراند | `tool/branding/generate_wordmark.py`, `assets/branding/logo_wordmark*.png` | حبر أسود + `Go` أحمر | توليد آلي بالأبيض للجزأين؛ العلامة المضغوطة تكتب فوق أصول الأيقونة القديمة، لكنها **لا تلمس** ملفات المظلة المستقلة | ✅ |
| شاشة الإقلاع (ماسترات) | `tool/branding/generate_splash.py`, `assets/branding/logo_splash*.png`, `logo_branding*.png` | أيقونة مظلة فوق الاسم | الاسم الأبيض وحده على حقل `#111111`، بلا بلاطة أيقونة ولا مظلة ولا أحمر | ✅ |
| الإقلاع الأصلي لكل المنصات | `pubspec.yaml`, `android/app/src/main/res/**`, `ios/Runner/Assets.xcassets/LaunchImage.imageset/**`, `web/splash/**` | أصول قديمة | إعادة توليد عبر `flutter_native_splash:create`؛_light_ و_night_ متطابقان، ولا مظلة في أي مخرج | ✅ |
| أيقونة المشغّل الخارجية | `tool/branding/generate_launcher_wordmark.py`, `generate_app_icon.py`, `assets/icon/*.svg` | مولّد قديم قد يعيد المظلة | المولّد القديم يفوّض إلى مولّد الكلمة البيضاء؛ كل SVGs تشير إلى الـrasters الجديدة | ✅ |
| فصل الأصول | `assets/icon/packages_parasol_1024.png`, `packages_parasol_dark_1024.png`, `pubspec.yaml` | المظلة كانت داخل `app_icon_adaptive_*` المستخدم في الإقلاع/AI | استُخرجت البكسلات الأصلية من `HEAD` إلى ملفين جديدين مُدرجين في `pubspec`؛ لا يمكن لاستثناء Packages أن يعيد المظلة لأي سطح آخر | ✅ |
| التحقق من الأصول | `scripts/verify_brand_assets.py` | يتوقع `Go` أحمر في الماستر | فحص ماستر أبيض بلا أحمر؛ تعداد الأحمر لا يجد `#FF2D2D`/`#FF5C5C` في أصول البراند | ✅ |
| التوثيق | `DESIGN.md`, `lib/core/theme/app_colors.dart` | `Wordmark Red` كلون للشعار | استبداله بـ `Brand White`، وتوثيق استثناء Packages في قسم Navigation | ✅ |
| الاختبارات | `test/{app_wordmark,brand_wordmark,brand_icon_splash,home_action_bar,home_design_spec,onboarding_service_buttons,ai_robot_avatar,theme_token_consistency}_test.dart` | تثبت 24/36 والمظلة والـ`Go` الأحمر | 28/42، أيقونة ستارت أب مفردة 64، أصل المظلة المستقل لـPackages، والعلامة البيضاء لبقية الأسطح؛ فحص بكسل يمنع الأحمر في الإقلاع | ✅ |
| صورة سياحية في دليل الاستكشاف | `assets/explore/manifest.json`, `lib/core/geo/explore_catalog.dart` | صورة «Umbrellas at Caudan Waterfront Mall» كوجهة Port Louis | **تركت كما هي عن قصد**: محتوى سفر مرخّص، وليس هوية البراند | ⏭️ خارج النطاق |

## لماذا ملف منفصل للمظلة؟

لو أعدنا كتابة `assets/icon/app_icon_adaptive_*_1024.png` بالمظلة لعادت المظلة تلقائياً إلى Android 12 splash ومساعد AI لأنهما يستخدمان نفس المسار. لذلك:

- `app_icon_adaptive_*` يبقى علامة `TokiGo` بيضاء.
- `packages_parasol_*` يحمل المظلة الأصلية، ويُستخدم من `HomeActionGlyph` فقط (وبالتالي Onboarding).
- المولّدات تعيد كتابة الأول فقط، فأي إعادة توليد روتينية لا تلمس الاستثناء.

## تحديثات الواجهة اللاحقة (2026-11-27)

- أيقونات Home السريعة: `28dp` داخل فتحة `42dp` (كانت `26/39`).
- أيقونات صفحات الستارت أب: four-up يرث `28/42`، والأيقونة المفردة الكبيرة أصبحت `64dp` داخل بلاطة `128dp` بدلاً من `56dp` المحبوسة داخل فتحة `39dp`.
- حالة فشل تحميل الإقامات القريبة: العنوان أصبح **“Could not load”** والنص تحته **“Please check your connection.”** (والعربية: «تعذر التحميل» / «يرجى التحقق من اتصالك بالإنترنت.»).
- أُزيل الشريط العلوي العام **“You are offline”** من `lib/app/app.dart`؛ تبقى حالات الخطأ/الكاش داخل الصفحات نفسها.
- **تحصين فحص الأصول:** `scripts/verify_brand_assets.py` صار يفحص كل صور الإقلاع على كل المنصات وكل الكثافات (Android mdpi→xxxhdpi مع night وv31، iOS 1x/2x/3x فاتح وداكن، Web 1x→4x) ويرفض أي أحمر مشبع أو صورة إقلاع بلا اسم أبيض — 46 صورة.
- **iOS والسلاش الأحمر:** الأصول المصدرية على `Main` خالية من الأحمر تماماً (فحص بكسل + `Assets.car` غير متاح من Windows). الظهور على iPhone سببه الأرجح launch snapshot/بناء قديم محفوظ على الجهاز. خطوات التحقق على Mac: حذف التطبيق، `flutter clean`، `flutter pub get`، `pod install` عند الحاجة، إعادة تشغيل المحاكي/الجهاز، ثم `flutter run`. إن بقي الأحمر بعد بناء نظيف فالمشكلة في `Assets.car` داخل الحزمة ويلزم فحص الحزمة المبنية.

## نتائج التحقق الفعليّة

- `python tool/branding/generate_wordmark.py --check` → نجح (الماسترات مطابقة للمواصفة).
- `python scripts/verify_brand_assets.py` → `all brand asset checks passed`؛ لا أحمر مشبع في أصول البراند أو الإقلاع.
- `dart run flutter_native_splash:create` → نجح، وحدّث Android / Android 12+ / iOS / Web.
- `dart format --output=none --set-exit-if-changed` على ملفات Dart المعدّلة → `0 changed`.
- `flutter analyze` → لا `error`، و478 ملاحظة/تحذيراً متبقية من قبل (deprecations وunused imports في ملفات أخرى)؛ لا ملاحظة جديدة في الملفات المعدّلة. خرج التحليل برمز 1 بسبب هذه التحذيرات القديمة.
- `flutter test` → **680 اختباراً ناجحاً**، صفر فشل (بعد تحديث اختبارات المقاسات وإضافة اختبار إزالة شريط الأوفلاين).
- `git diff --check` → نظيف (أُزيلت مسافات زائدة أنشأها مولّد الويب في `web/index.html`).

التحقق بصري على جهاز فعلي **لم يُجرَ**؛ الفحوص بكسلية وعبر widget tests فقط.

## الضوابط

- لم يُنفّذ `git add` / `commit` / `push`، ولم تُقرأ `.env`.
- لم يُجرَ أي حجز أو دفع أو تشغيل Sandbox/Production.
- التغييرات كلها محلية في مساحة العمل، وجاهزة للمراجعة قبل أي خطوة تالية من خارطة التطوير.
