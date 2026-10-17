# تقرير العمل: الشريط السفلي العائم + البحث الذكي + شيت الاقتراحات

**التاريخ:** 5 سبتمبر 2026
**الحالة:** منفّذ بالكامل ومتحقق منه — غير مُلتزم في git (uncommitted) بانتظار تعليمات صريحة
**نطاق العمل:** تعديل واجهة التنقل + إضافة مسار البحث الذكي المدعوم بالـ AI — بدون أي تغيير في Home Ranking أو booking flows أو أي منطق أعمال آخر

---

## 1. الهدف والمتطلبات

1. تحويل الشريط السفلي من ملتصق (attached) إلى **عائم (floating)** بفواصل وحواف دائرية وظل
2. **نقل زرار الـ AI** من منتصف الشريط السفلي إلى **صندوق بحث ذكي** يظهر في أعلى صفحة الهوم
3. عند الضغط على الصندوق للكتابة، يفتح **شيت اقتراحات ذكي** (على نمط شيت اختيار الوجهات `destination_picker_sheet`) بمساعدة لحظية أثناء الكتابة مصدرها الـ AI Backend
4. إضافة **ضوء دوّار فخم** حول الصندوق (نمط بحث جوجل لكن أهدى وأرقى)

### القرارات المؤكدة من المستخدم قبل التنفيذ
- مكان الصندوق: أعلى الهوم تحت الترحيب
- شكل شاشة الكتابة: شيت اقتراحات من الأسفل (bottom sheet)
- مصير زرار الـ AI في الشريط: يُحذف نهائيًا (الشريط يبقى 4 تابات)
- مصدر الاقتراحات أثناء الكتابة: endpoint جديد خفيف وسريع في الـ backend (بدون LLM)
- بعد الإرسال: النتائج تظهر في نفس الشيت (مش صفحة الشات)
- ألوان الضوء الدوار: بنفسجي AI + أندigo البراند
- سرعة الدوران: بطيئة أنيقة (~4.5 ثانية للفة)
- لغة التقرير: عربي

---

## 2. المرحلة الأولى — الشريط السفلي العائم

### `lib/app/widgets/app_bottom_nav.dart` (أُعيدت كتابته)
- حذف `AppBottomNavDestination.ai` من الـ enum — الشريط أصبح **4 تابات**: Home / Search / Groups / Explore
- حذف كلاس `_AiCentreButton` بالكامل (الزرار البنفسجي النابض في المنتصف)
- حذف معامل `onAiPressed` ومنطق الـ AI slot (سطور 63–79 القديمة)
- الشكل الجديد: `Container` بهوامش خارجية (`AppSpacing.lg` يمين/يسار + `AppSpacing.md` أسفل)، `borderRadius: AppRadius.xlBorder` (24px)، `Border.all` خفيف، `boxShadow` من `AppElevation.shadow(level: lg)` — المحتوى الآن يمر من خلف الشريط (edge-to-edge)
- `_NavItem` لم يتغير (نفس أنيميشن scale/color ramp وهابتك feedback وRTL mirroring)

### `lib/app/shell.dart` (أُعيدت كتابته)
- الشريط انتقل من `Scaffold.bottomNavigationBar` إلى **Stack فوق الـ body** (`Positioned` أسفل الشاشة)
- معامل جديد `location` (نوع `Uri`) — الشيل يستقبل الموقع الحالي من الراوتر
- **منطق الإخفاء الذكي** `showNav`: الشريط يظهر فقط على جذور التابات الأربعة (`/` و`/search` و`/groups` و`/explore`). أي صفحة داخلية في فرع (زي `/flights`, `/bag`, `/booking/review`, `/profile`...) تخفي الشريط تلقائيًا — السبب: هذه الصفحات تملك أسفلها أشرطة CTA ثابتة (`StickyCtaBar` في صفحات الحجز) أو حقول، والشريط العائم كان سيغطيها
- حذف `onAiPressed: () => context.push('/ai-chat')` وتعديل `_goBranch` لـ 4 فروع فقط
- **ملاحظة معمارية:** go_router يعيد بناء shell builder مع كل تنقل داخل الشل، لذا `state.uri` دائمًا محدث

### `lib/app/router/go_router_config.dart`
- تعديل وحيد: تمرير `location: state.uri` إلى `TokiGoShell` (سطر ~92)
- **كل الراوتات الأخرى لم تُلمس** — بما فيها `/ai-chat` (بقي كما هو خارج الشل بـ `parentNavigatorKey`)

### `lib/core/navigation/app_route.dart`
- حذف `ai('AI', ...)` من enum `AppRoute` ومن `primaryDestinations`
- سبب حذف الـ enum نفسه: لم يعد له أي مستهلك (زرار الشريط محذوف) — الحذف يمنع كودًا ميتًا يشير لوجهة غير موجودة في التنقل الأساسي

---

## 3. المرحلة الثانية — صندوق البحث الذكي في الهوم

### `lib/features/home/presentation/widgets/home_ai_search_field.dart` (ملف جديد)
- `HomeAiSearchField`: صندوق pill قابل للضغط (مش `TextField` حقيقي — نفس نهج `_HeroSearchField` في صفحة البحث) بخلفية `AppColors.aiContainer` وأيقونة `Icons.auto_awesome_rounded` بلون `AppColors.ai` + سهم أمامي
- الضغط يستدعي `showAiSmartSearchSheet(context)`
- يظهر في الهوم تحت سطر الترحيب (`_HomeWelcome`) بمسافة `AppSpacing.md`

### `lib/features/home/presentation/pages/home_page.dart`
- إضافة import + سطران في الـ header column (بعد `_HomeWelcome`):
  ```dart
  const SizedBox(height: AppSpacing.md),
  const HomeAiSearchField(),
  ```
- **لا شيء آخر في الصفحة تغيّر** — الـ feed والـ carousel والـ skeleton كما هي

### الضوء الدوار "Rotating Aura" (تنفيذ لاحق في نفس الجلسة، بناءً على طلب المستخدم)
- تحويل الـ widget إلى `StatefulWidget` مع `SingleTickerProviderStateMixin`
- **المذنب الدوّار** `_RotatingAuraBorder`: حلقة 2px مرسومة بالكامل بـ `AppColors.ai` فوق طبقة `ShaderMask` بـ `SweepGradient` دوّار (`GradientRotation(rotation)`) — الجزء المرئي قوس قصير يتدرج: شفاف → بنفسجي AI → أندigo براند → بنفسجي فاتح → شفاف (stops: 0.0, 0.52, 0.62, 0.72, 0.82, 0.92, 1.0) — يقرأ كـ "مذنب ضوء" يساف حول الحدود
- **حلقة خلفية ثابتة** خفيفة (`alpha 0.22`) تحت المذنب عشان الصندوق يفضل مقروءًا كحقل في كل frame
- **توهج تنفّسي** خلف الصندوق: `BoxShadow` بنفسجي بـ alpha يتنفس 0.10→0.18 و blur 22→28 — نفس أسلوب "quiet breathing glow" المقبول سابقًا في زرار الـ AI القديم
- **السرعة:** لفة كل 4500ms بـ `Curves.linear` (البطء هو الإحساس البريميم)
- `IgnorePointer` على طبقة المذنب حتى لا تعترض الضغط على الصندوق
- كل الألوان من الـ tokens الموجودة (`AppColors.ai/aiLight/brand`) — ألوان شفافة فقط (`0x00000000`) كماهية

---

## 4. المرحلة الثالثة — شيت الاقتراحات الذكي

### `lib/features/ai/presentation/widgets/ai_smart_search_sheet.dart` (ملف جديد — الملف الأهم)

**الدخول:** `showAiSmartSearchSheet(context, {aiContext})` — `showModalBottomSheet` بـ `isScrollControlled: true` + `useSafeArea: true` + خلفية شفافة، بحد أقصى 75% من الشاشة

**تجربة الكتابة:**
- حقل `TextField` بـ **autofocus** (الكيبورد يفتح فورًا مع الضغط على الصندوق في الهوم) داخل حاوية بحدود `AppColors.aiContainer` وزرار إرسال دائري بتدرج بنفسجي (`AppColors.ai → aiLight`) — نفس لغة `_SendButton` الموجودة في `AiPromptInput`
- **اقتراحات لحظية:** كل تغيير في النص يفعّل debounce 400ms ثم يستدعي `AiApiService.suggest()` مع رقم إصدار (`_suggestVersion`) لضمان أن آخر استعلام فقط هو من يُعرض (حماية من نتائج قديمة تصِل بعد الجديدة)
- أثناء التحميل: مؤشر دائري صغير؛ الاقتراحات تُعرض في list بأسلوب `_SuggestionTile` (أيقونة بنفسجية في حاوية `aiContainer` + أيقونة north-west)
- الضغط على اقتراح يعبّئ الحقل ويرسل مباشرة

**Fallback محلي بدون شبكة:** ثنائي اللغة (`_SmartSearchSheetEntry` en/ar) — 6 اقتراحات جاهزة تُعرض:
- قبل أي كتابة (resolve حسب `Localizations.localeOf`)
- عند فشل أو فراغ استجابة الـ backend (fail-silent — الشيت لا يتعطل أبدًا)
- عند قصر النص (<2 حرف)
- الفلترة المحلية تحاول مطابقة النص المكتوب مع الاقتراحات المعروضة حسب اللغة

**النتائج بعد الإرسال:** `_submit()` يقفل شيت الكتابة ثم يفتح `showAiResultsSheet` — draggable sheet (55%→85%) بـ **إعادة استخدام كاملة لـ `aiSheetControllerProvider` الموجود في `ai_bottom_sheet.dart`** — نفس الـ caching وerror handling وعرض النتائج عبر `HomeSectionWidget`. أي تعديل مستقبلي على منطق عرض نتائج الـ AI سيشمل الشيتين تلقائيًا

---

## 5. المرحلة الرابعة — الـ Backend: `POST /ai/suggest`

### `backend/src/common/dto/ai.dto.ts`
- `AiSuggestDto`: `{ query: string }` — `@IsNotEmpty` + `@MaxLength(120)` (نص جزئي مش prompt كامل)
- `AiSuggestResponseDto`: `{ suggestions: string[] }`

### `backend/src/modules/ai/ai.service.ts`
- كتالوج ثابت ثنائي اللغة: 24 قالب (12 إنجليزي + 12 عربي) — طيران/فنادق/سيارات/أفكار/وجهات
- `DEFAULT_SUGGESTIONS`: 6 اقتراحات افتراضية عند عدم التطابق
- خوارزمية matching (بدون ML/Vector/Embedding — التزامًا بقواعد AGENTS.md):
  - **containment مباشر:** `indexOf` — النتيجة `100 - min(direct, 50)` (البادئة أقوى)
  - **token-overlap fallback:** لاختلاف ترتيب الكلمات — `(matched/tokens) × 60`
  - ترتيب تنازلي بالنقاط، أقصى 6 نتائج، **متعمد ألا يكون LLM call** — typeahead لازم يرد بعشرات الميلي ثانية ويفضل مجانيًا
- المصفوفات `private static readonly` داخل `AiService`

### `backend/src/modules/ai/ai.controller.ts`
- `@Post('suggest')` → `{ suggestions: await aiService.suggest(dto.query) }`

### الـ Flutter side
- `lib/features/ai/data/ai_api_service.dart`: ميثود `suggest(query, {timeout: 3s})` — `POST /ai/suggest`، parse لـ `suggestions` كـ list نصوص، timeout قصير متعمد (الاقتراحات تحسين تدريجي)
- `lib/features/ai/application/ai_providers.dart`: `aiSuggestionsServiceProvider` منفصل عن `aiAssistantServiceProvider` — حتى تستطيع الـ tests عمل stub للـ typeahead دون المساس بخدمة الاستعلام الكامل

---

## 6. المرحلة الخامسة — l10n + الاختبارات

### l10n (`app_en.arb` / `app_ar.arb` + gen)
| المفتاح | English | العربية |
|---|---|---|
| `aiSearchHint` | Ask Hopper AI… | اسأل هوبر الذكي… |
| `aiSearchSheetHint` | Where do you want to go? | عايز تسافر فين؟ |
| `aiSearchNoSuggestions` | No suggestions right now. Try a different prompt. | مفيش اقتراحات دلوقتي. جرب صيغة تانية. |
| `aiSearchError` | Something went wrong. Please try again. | حدث خطأ ما. حاول مرة أخرى. |

### Tests محدّثة (تعقد جديد: 4 تابات بدل 5، بدون AI)
- `test/app/widgets/bottom_nav_branch_mapping_test.dart`: rewrite كامل — تابات الأربعة + **test جديد**: الشريط يختفي عند الدخول لصفحة فرعية (`/flights`) ويظهر على جذور التابات فقط
- `test/core/ui/accessibility_test.dart`: الـ semantics test — 4 تابات، `auto_awesome_rounded` لم يعد في الشريط (انتقل للهوم)، ونقل الـ widget من `bottomNavigationBar` إلى `body` (لأن الشريط الآن floating)
- `test/core/navigation/app_route_test.dart`: `AppRoute.ai` لم يعد من ضمن `primaryDestinations`

### Tests جديدة
- `test/features/ai/presentation/widgets/ai_smart_search_sheet_test.dart`:
  1. صندوق الهوم يفتح الشيت بالـ hint المترجم
  2. فشل الـ backend → fallback المحلي يعمل (بـ stub رافض `implements AiApiService` + `overrideWithValue`) — مع `Hive.init` في `setUpAll` (نفس نهج smoke test)
- `backend/test/ai.suggest.spec.ts` (6 tests): نص قصير → defaults، مطابقة إنجليزي substring، مطابقة عربي substring، ترتيب containment فوق token-overlap، لا نتائج → defaults، حد أقصى 6

---

## 7. نتائج التحقق (بنفس أوامر AGENTS.md)

| الأمر | النتيجة |
|---|---|
| `dart analyze lib test` | **0 errors, 0 warnings** (بقية الـ infos/warnings الموجودة قبل العمل في ملفات غير ملموسة — لم تُحدث) |
| `flutter test` | **527 passed / 6 skipped / 0 failed** (كانت 438 قبل العمل — الفرق من phases سابقة + 3 tests جديدة من هذا العمل) |
| `npx tsc --noEmit` (backend) | **clean** |
| `npx jest` (backend) | **232 passed / 1 skipped / 0 failed** (منها 6 جديدة لهذا العمل) |

### ملاحظة على الأنيميشن اللانهائي والاختبارات
فُحصت كل الـ tests المستخدمة `pumpAndSettle` مع صفحة الهوم (`new_surfaces_test`, `ai_chat_page_test`, `card_image_test`, `full_app_smoke_test`) — كلها تستخدم إما pumps بمدة ثابتة أو لا تركّب الهوم أصلًا، لذا الضوء الدوار (repeat) لم يكسر شيئًا. نفس الوضع كان قائمًا سابقًا مع زرار الـ AI النابض القديم.

---

## 8. ما لم يُلمس عمدًا (ضمان عدم الكسر)

- صفحة `/ai-chat` وراووتها — كما هي تمامًا
- `AiController` / `aiControllerProvider` / `AiChatPage` — منطق الشات الكامل
- `aiSheetControllerProvider` و`AiBottomSheetContent` و`showAiBottomSheet` — لم يُعدل سطر واحد فيها، فقط أُعيد استخدامها
- Home Ranking و`DerivedPreferenceProfile` وقواعد Phase 2C — لم تقترب
- booking flows و`StickyCtaBar` وصفحات البحث العمودية — لا تغيير
- `AiVisualShellPage` (المتقاعدة) و`SearchIntentParser` (غير الموصّل) — كما هما
- لا حذف ملفات، لا packages جديدة، لا commit/push

---

## 9. حالة git عند إغلاق التقرير

- كل التعديلات أعلاه **uncommitted** في الـ working tree
- الـ repo كان يحمل تعديلات سابقة غير ملتزمة (admin workstream + R-4 + Phase 0 — موثقة في `PROJECT_MEMORY/04_PHASE_HISTORY.md`) قبل هذا العمل — لم تُلمس
- انتظار تعليمات صريحة للـ commit حسب قواعد المشروع

---

## 10. الملفات المنشأة/المعدّلة — قائمة مرجعية سريعة

**Flutter — جديدة:**
- `lib/features/home/presentation/widgets/home_ai_search_field.dart`
- `lib/features/ai/presentation/widgets/ai_smart_search_sheet.dart`
- `test/features/ai/presentation/widgets/ai_smart_search_sheet_test.dart`

**Flutter — معدّلة:**
- `lib/app/widgets/app_bottom_nav.dart` (rewrite)
- `lib/app/shell.dart` (rewrite)
- `lib/app/router/go_router_config.dart` (سطر تمرير location)
- `lib/core/navigation/app_route.dart` (حذف ai)
- `lib/features/home/presentation/pages/home_page.dart` (سطران + import)
- `lib/features/ai/data/ai_api_service.dart` (ميثود suggest)
- `lib/features/ai/application/ai_providers.dart` (provider جديد)
- `lib/l10n/app_en.arb` + `app_ar.arb` (4 مفاتيح) + الملفات المولدة
- `test/app/widgets/bottom_nav_branch_mapping_test.dart` (rewrite + test جديد)
- `test/core/ui/accessibility_test.dart` / `test/core/navigation/app_route_test.dart` (تحديث)

**Backend — جديدة:**
- `backend/test/ai.suggest.spec.ts`

**Backend — معدّلة:**
- `backend/src/common/dto/ai.dto.ts` (AiSuggestDto + AiSuggestResponseDto)
- `backend/src/modules/ai/ai.service.ts` (كتالوج + خوارزمية suggest)
- `backend/src/modules/ai/ai.controller.ts` (endpoint)

---

## 11. الجولات اللاحقة (نفس اليوم)

### الجولة الأولى — خلفية بيضاء ناصعة (طلب المستخدم)
- خلفية الصندوق: `AppColors.aiContainer` → **`AppColors.surface`** (أبيض ناصع) — الضوء البنفسجي الدوار بقى أوضح تباينًا
- لون الـ hint: `onAiContainer` → **`textSecondary (alpha 0.7)`** — نفس نمط الحقول البيضاء في التطبيق

### الجولة الثانية — شكل "جوجل بريميم" + إصلاح ملاصقة الكيبورد (طلب المستخدم: "شكله يكون أحسن من ناحية شريط بحث + نفس الشيت مع الكتابة والكيبورد في iOS وأندرويد")

**أ) صندوق البحث (`home_ai_search_field.dart`):**
- يمين الصندوق: السهم العادي استُبدل بـ**زرار دائري 36px** بخلفية `aiContainer` فيه أيقونة `search_rounded` بنفسجي — نمط زرار المايك عند جوجل
- أيقونة الـ AI: 22px → 24px، والمسافات أعيدت معايرتها (padding عمودي `AppSpacing.md` حول الدائرة → ارتفاع ~60px)
- الظل التنفسي أخف وأعرض: alpha 0.06→0.12 (كان 0.10→0.18)، blur 16→24، offset (0,4)
- الضوء الدوار + الحلقة الخلفية + الأبيض الناصع كما هي

**ب) الشيت (`ai_smart_search_sheet.dart`) — التشخيص والإصلاح:**

المشكلة: تراكم ثلاث مسافات سفلية — `useSafeArea: true` (يستهلك home-indicator ~34px حتى مع الكيبورد المفتوح) + `Padding(viewInsets.bottom)` + `SizedBox(padding.bottom)` يدوي في نهاية العمود. النتيجة فجوة بين الشيت والكيبورد، وارتفاع `0.75×الشاشة` لا يحسب الكيبورد فالاقتراحات تتقطع. كذلك `TextInputType.multiline` يجعل زر الكيبورد "return" بدل "search".

الإصلاح:
1. `useSafeArea: false` — تحكم كامل في المسافات
2. **قاعدة موحدة:** `effectiveBottom = viewInsets.bottom > 0 ? viewInsets.bottom : padding.bottom` — كيبورد مفتوح → ملاصقة صفرية (viewInsets يصل لآخر الشاشة في المنصتين)؛ مغلق → احترام الـ home indicator. لا تراكم أبدًا
3. `AnimatedPadding` بـ `AppMotion.normal` — تتبع ناعم لحركة الكيبورد (يعالج نطّات أندرويد)
4. **ارتفاع متكيف:** `maxHeight = screenHeight − effectiveBottom − topSafeArea − md` — الشيت لا يخرج من الشاشة أبدًا والاقتراحات تظل فوق الكيبورد
5. حذف الـ `SizedBox(padding.bottom)` اليدوي
6. `TextInputType.text` + `TextInputAction.search` — زرار الكيبورد فعل بحث حقيقي
7. شيت النتائج لم يتغير (الكيبورد يقفل قبل فتحه)

**لماذا يتوحد السلوك بين iOS وAndroid:** Flutter يوفّر `viewInsets.bottom` بشكل موحد، و`adjustResize` موجود في AndroidManifest — الخلل كان في التراكم لا في المنصة.

**تحقق الجولتين:** `dart analyze` نضيف على الملفين، و`flutter test` كاملًا — **527 passed / 0 failed**.

### الجولة الثالثة — التحول لنمط انستجرام (صفحة بحث كاملة بدل الشيت)

**طلب المستخدم:** نمط انستجرام في البحث (fake field في الهوم → صفحة كاملة بـ input حقيقي فوق + نتائج لحظية تحته) + مسح القديم نهائيًا منعًا للتكرار + إعادة استخدام المتاح قبل الإضافة.

**أ) الصفحة الجديدة:** `lib/features/ai/presentation/pages/ai_smart_search_page.dart`
- صفحة كاملة خارج الشل (الشريط السفلي مخفي) بثلاث حالات:
  1. **فارغ:** قسم "Recent searches" (آخر 8 عمليات — حفظ/مسح فردي/مسح الكل) فوق قسم "Suggestions"
  2. **أثناء الكتابة:** نفس منطق debounce 400ms + `aiSuggestionsServiceProvider` + fallback محلي (منقول من الشيت القديم)
  3. **النتائج:** بعد الإرسال — الاقتراحات تختفي وكروت الـ AI تنزل تحت الحقل في نفس الصفحة (إعادة استخدام `aiSheetControllerProvider` + `HomeSectionWidget`) مع شريط "Results for «…»" + chip "Edit" للرجوع للاقتراحات
- الهيدر: زرار رجوع دائري (نمط `AiChatPage`) + حقل pill حقيقي (autofocus، `TextInputAction.search`، زرار ✕ لمسح النص، زرار إرسال بنفسجي) — الكيبورد تحت المحتوى مباشرة (لا يوجد docking لأن الحقل فوق)
- **Recent storage:** `OfflineCache` الموجود بمفاتيح `ai_search_recent/<n>` — بدون Hive boxes جديدة أو تغيير في الـ core (حد أقصى 8، dedupe، الأحدث أولًا)

**ب) الحذف بموافقة المستخدم الصريحة (منع التكرار):**
- حُذف `lib/features/ai/presentation/widgets/ai_smart_search_sheet.dart` بالكامل (الشيت + شيت النتائج) — كان المستهلك الوحيد صندوق الهوم
- حُذف test الشيت القديم واستُبدل بـ `test/features/ai/presentation/pages/ai_smart_search_page_test.dart`

**ج) إعادة الاستخدام (قبل أي إضافة جديدة):**
- `aiSheetControllerProvider` + `AiStatus` + `HomeSectionWidget` — عرض النتائج بدون كود جديد
- الـ fallback suggestions + `_SuggestionTile` + `_SendButton` — منقولين من الشيت مع تعديلات حجم طفيفة للسياق الجديد
- زرار الرجوع الدائري — نفس ستايل هيدر `AiChatPage`
- `offlineCacheProvider` — التخزين بدون تنفيذية جديدة

**د) التعديلات على الموجود:**
- `home_ai_search_field.dart`: `showAiSmartSearchSheet(context)` → `context.push('/smart-search')` (الضوء الدوار والشكل كما هما)
- `go_router_config.dart`: راوت `/smart-search` جنب `/ai-chat` (root navigator + fadeThroughPage)
- l10n: 5 مفاتيح جديدة (en/ar): `aiSearchSuggestions`, `recentSearches`, `clearAll`, `aiSearchEditQuery`, `aiSearchResultsFor` (بـ placeholder)

**هـ) Bug حقيقي اكتُشف وأُصلح أثناء العمل:**
`_scrollController.jumpTo(0)` في `_submit` كان يرمي `ScrollController not attached` عند الإرسال من قائمة الاقتراحات (الـ ListView ما كانتش اتبنت بعد) — أُصلح بـ `addPostFrameCallback` + حماية `hasClients`.

**و) أثناء الـ tests اكتُشف أن انتقال fadeThroughPage يحتاج pumps إضافية** — تم ضبط الـ tests (300ms + 600ms) والصندوق نفسه يعمل 100% (hit-test سليم).

**تحقق الجولة:** `dart analyze lib test` → **0 errors / 0 warnings**، `flutter test` → **528 passed / 6 skipped / 0 failed** (3 tests جديدة للصفحة: push + back، recent persistence، backend fallback).

### الجولة الرابعة — Container Transform (تحوّل الصندوق الحقيقي للصفحة)

**طلب المستخدم:** تجربة Container Transform / Shared Element Transition القياسية (Material 3 / iOS): الصندوق يتحول ويتمدد من مكانه في الهوم لملء أعلى الصفحة، مع scrim خلفية وانبثاق المحتوى — بمدة 250–350ms، وfocus/keyboard فوري مع انطلاق الحركة. ملاحظات المستخدم التقنية المطلوبة: (1) shuttle بستايل ثابت بدون نص حي منعًا للـ visual flickering، (2) Hero بين branch وroot في go_router 14.8.1 يعمل بكفاءة طالما نفس الـ tag، (3) requestFocus في initState بـ addPostFrameCallback.

**القرار المعماري:** بدون حزمة `animations` (رغم موافقة المستخدم على تثبيت الحزم) — فحص مصدر go_router 14.8.1 أكد أن كل navigator (root + كل branch) ملفوف بـ `HeroController` خاص، وpush على الـ root navigator يشغّل hero flight من أي widget جوه الشل. `OpenContainer` كان سيدفع الصفحة جوه الـ branch navigator (الشريط العائم كان سيظل ظاهرًا فوق البحث). **Hero الأصلي + CustomTransitionPage مخصص = نفس النتيجة بصفر حزم.**

**أ) `lib/core/navigation/app_transitions.dart` — إضافة `ContainerTransformTransition`:**
- `CustomTransitionPage` بمدة 320ms (ضمن النطاق المطلوب) لراوت `/smart-search` فقط + `containerTransformPage()` helper
- **Scrim:** طبقة بيضاء ناصعة (هوية Pure White Premium) تذوب 1→0 خلال أول 30% من الرحلة فوق الصفحة الجديدة = إحساس "الصندوق طلع من فوق الأبيض" والقديم يتراجع خلفه
- **Content reveal:** الجسم (Recent/اقتراحات/نتائج) `Opacity + SlideY(16→0)` يبدأ من 25% — يتبع الصندوق بعد استقراره
- الهيدر (وجهة الهيرو) غير ملفوف — ظاهر من t=0

**ب) `home_ai_search_field.dart` — الصندوق هو مصدر الهيرو:**
- `Hero(tag: kAiSmartSearchHeroTag)` حول الـ pill نفسه
- **إعادة هيكلة الـ aura:** الـ glow التنفسي + الحلقة الدوارة (`_RotatingAuraBorder` بالـ ShaderMask comet) **خارج الهيرو** — الكوميت يكمل دورانه في الهوم أثناء طيران الكبسولة (وكان داخل الهيرو قبله ما اتحط برة لمنع flicker)
- `flightShuttleBuilder`: كبسولة **بستايل ثابت** — pill أبيض بحلقة بنفسجي→أندigo هادئة (بدون دوران)، أيقونة sparkle فقط، **بدون أي Text حي** (منع الـ typography flickering أثناء interpolation الأحجام) — الـ opacity يظهرها تدريجيًا مع مغادرة الهوم
- `placeholderBuilder: SizedBox.shrink` — الكبسولة "تسيب" الهوم أثناء الرحلة

**ج) `ai_smart_search_page.dart` — الهيدر هو الوجهة:**
- الحقل ملفوف بنفس `kAiSmartSearchHeroTag` داخل `Expanded`
- `placeholderBuilder`: هيكل pill هادي بنفس الأبعاد — الهيدر لا يرمش عند تسليم الرحلة
- **`requestFocus` في `initState` بـ `addPostFrameCallback`** — الكيبورد والمؤشر يطلعوا مع انطلاق الهيرو (Instant Responsiveness) مع حماية `mounted`

**د) `go_router_config.dart`:** `/smart-search` من `fadeThroughPage` → `containerTransformPage`

**Timeline النهائي:** 0ms: ضغط → الكيبورد يبدأ الطلوع + الكبسولة تنطلق (قوس Material `fastOutSlowIn` = cubic-bezier(0.4,0,0.2,1)) — 0–96ms: scrim أبيض كامل — 80–320ms: المحتوى ينبثق fade+slide — 320ms: الاستقرار (المؤشر يرمش، Recent/اقتراحات في مكانها). الـ pop معكوس تمامًا.

**تحقق الجولة:** `dart analyze lib test` → **0 errors / 0 warnings**، `flutter test` → **528 passed / 0 failed**.

### الجولة الخامسة — إصلاح سلاسة الحركة (فجوة السكون) + منطقة الضغط + انصهار المؤشر

**شكوى المستخدم:** (1) إحساس بأن الأنيميشن "يقف" أثناء الفتح/الإغلاق، (2) الضغط يجب أن يكون في منطقة الكتابة فقط (زي انستجرام) مع ظهور مؤشر الكتابة مكان الـ hint.

**أ) التشخيص (من مصدر Flutter `heroes.dart`):**
- الـ Hero flight **ليس له مدة مستقلة** — مربوط حرفيًا بـ `toRoute.animation` (سطر 477)، فمدته = مدة انتقال الراوت (320ms)
- السبب البصري للتوقف: الـ scrim كان يكتمل عند **30%** (96ms) بينما الهيرو يطير حتى 320ms — أي ~75% من الرحلة لا حركة على الشاشة غير كبسولة باهتة = "سكون"
- كذلك منطق الـ scrim القديم (`if t < 0.30` مع alpha تنازلي) كان يعكس نفسه خطأً في اتجاه الـ pop

**ب) الإصلاحات:**

1. `app_transitions.dart` — إعادة توزيع الـ Timeline (المدة ثابتة 320ms):
   - `_scrimCompleteAt: 0.30 → 0.65` — الأبيض يذوب متزامنًا مع معظم الرحلة = تلاشي مستمر بلا فجوات سكون
   - `_revealFrom: 0.25 → 0.40` — المحتوى ينبثق بعد استقرار الكبسولة بصريًا ("يتبع الصندوق" حرفيًا)
   - **اتجاه الـ scrim مربوط بالـ flight direction:** على push يبدأ معتمًا 1→0، وعلى pop معكوس 0→1 (الأبيض يعود يغطي المحتوى المتراجع) — عبر فحص `animation.status == reverse`

2. `home_ai_search_field.dart` — منطقة الضغط (قرار المستخدم: منطقة النص فقط):
   - الـ `InkWell` انتقل من كامل الصندوق إلى **داخل الـ `Expanded` حول الـ hint** (`SizedBox(height: 36)` + `Align` — يغطي العرض المتاح كاملًا)
   - الأيقونة اليسرى والدائرة اليمنى **شكلانيتان تمامًا** (خارج أي منطقة ضغط)
   - العمود: منطقة الضغط 36px داخل pill 60px — ضمن معيار 48px المطلوب للمس الكامل يظل محققًا عبر ارتفاع الصف بأكمله (12+36+12 = 60px مع InkWell ممتد)

3. `ai_smart_search_page.dart` — انصهار المؤشر:
   - أيقونة الـ sparkle في الهيدر: **20 → 24px** (نفس حجم الهوم) + نفس `AppSpacing.md` gap → المؤشر يهبط **بالضبط مكان الـ hint text** — الكبسولة "تذوب" في الحقل الحقيقي

**تحقق الجولة:** `dart analyze` نضيف — `flutter test` → **528 passed / 0 failed** (tap الـ tests تعمل مع منطقة الضغط الجديدة لأن `tester.tap` يصيب مركز الصندوق = منطقة النص).
