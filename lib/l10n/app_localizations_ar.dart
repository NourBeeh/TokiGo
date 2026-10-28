// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'TokiGo';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navSearch => 'بحث';

  @override
  String get navGroups => 'الجروبات';

  @override
  String get navExplore => 'استكشف';

  @override
  String get navAi => 'المساعد الذكي';

  @override
  String get bag => 'رحلاتي';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get profileGuestTitle => 'أنت تتصفّح كضيف';

  @override
  String get profileGuestBody =>
      'سجّل الدخول لحفظ رحلاتك وأماكنك المفضّلة وتفضيلاتك.';

  @override
  String get profileTraveller => 'مسافر';

  @override
  String get profileErrorTitle => 'تعذّر تحميل حسابك';

  @override
  String get back => 'رجوع';

  @override
  String get searchHint => 'رايح فين؟';

  @override
  String get aiSearchHint => 'عايز تسافر فين؟';

  @override
  String get aiSend => 'إرسال';

  @override
  String get aiOpenChat => 'افتح TokiGo AI';

  @override
  String get aiHintPhrase1 => 'اسأل Toki — مساعدك السياحي';

  @override
  String get aiHintPhrase2 => 'إلى أين تريد السفر؟';

  @override
  String get aiHintPhrase3 => 'فنادق في إستنبول؟ رحلات إلى القاهرة؟';

  @override
  String get aiSearchSheetHint => 'عايز تسافر فين؟';

  @override
  String get aiSearchNoSuggestions => 'مفيش اقتراحات دلوقتي. جرب صيغة تانية.';

  @override
  String get aiSearchError => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get aiSearchSuggestions => 'اقتراحات';

  @override
  String get recentSearches => 'آخر عمليات البحث';

  @override
  String get clearAll => 'مسح الكل';

  @override
  String get aiSearchEditQuery => 'تعديل';

  @override
  String aiSearchResultsFor(Object query) {
    return 'نتائج عن «$query»';
  }

  @override
  String get aiSearchPersonalizedHint => 'مرتّبة حسب تفضيلاتك';

  @override
  String get aiSearchSort => 'ترتيب';

  @override
  String get aiSearchSortRecommended => 'الأنسب';

  @override
  String get aiSearchSortPriceLow => 'السعر: من الأقل';

  @override
  String get aiSearchSortPriceHigh => 'السعر: من الأعلى';

  @override
  String get aiSearchSortRating => 'التقييم';

  @override
  String get aiSearchRefine => 'تصفية';

  @override
  String get aiSearchRefineClear => 'مسح الفلاتر';

  @override
  String get aiSearchRefineTitle => 'تصفية النتائج';

  @override
  String get aiSearchApply => 'تطبيق';

  @override
  String get aiSearchFilterPriceMax => 'أقصى سعر';

  @override
  String get aiSearchFilterMinStars => 'أقل نجوم';

  @override
  String get aiSearchFilterMaxStops => 'أقصى توقفات';

  @override
  String get aiSearchFilterMinSeats => 'أقل مقاعد';

  @override
  String get aiSearchFilterAny => 'الكل';

  @override
  String get aiSearchCompare => 'قارن';

  @override
  String get aiSearchCompareMode => 'اختر من 2 لـ3 للمقارنة';

  @override
  String aiSearchCompareOpen(Object count) {
    return 'قارن ($count)';
  }

  @override
  String get aiSearchCompareTitle => 'المقارنة';

  @override
  String get aiSearchCompareCancel => 'إلغاء';

  @override
  String get aiSearchCompareSameType => 'اختر منتجات من نفس النوع للمقارنة.';

  @override
  String get aiSearchCompareMissing => '—';

  @override
  String get cmpPrice => 'السعر';

  @override
  String get cmpStars => 'النجوم';

  @override
  String get cmpRating => 'التقييم';

  @override
  String get cmpLocation => 'الموقع';

  @override
  String get cmpAmenities => 'المرافق';

  @override
  String get cmpCancellation => 'الإلغاء';

  @override
  String get cmpAirline => 'شركة الطيران';

  @override
  String get cmpDuration => 'المدة';

  @override
  String get cmpStops => 'التوقفات';

  @override
  String get cmpBaggage => 'الأمتعة';

  @override
  String get cmpDeparture => 'المغادرة';

  @override
  String get cmpArrival => 'الوصول';

  @override
  String get cmpCategory => 'الفئة';

  @override
  String get cmpSeats => 'المقاعد';

  @override
  String get cmpBags => 'الحقائب';

  @override
  String get cmpTransmission => 'ناقل الحركة';

  @override
  String get cmpMileage => 'المسافة';

  @override
  String get cmpDestination => 'الوجهة';

  @override
  String get cmpInclusions => 'يشمل';

  @override
  String get searchPromptTitle => 'رايح فين بعد؟';

  @override
  String get searchPromptSubtitle =>
      'خطط لرحلة مدينة، هروب للشاطئ أو ويك إند سريع.';

  @override
  String get searchAllServices => 'كل الخدمات';

  @override
  String homeHelloName(Object name) {
    return 'أهلاً، $name';
  }

  @override
  String get homeStaysTitle => 'فنادق مقترحة';

  @override
  String get homeContinuePlanning => 'كمّل تخطيطك';

  @override
  String get homeWelcome => 'أهلاً بعودتك';

  @override
  String get homeWelcomeSub => 'رحلات وأفكار مختارة لك';

  @override
  String get searchFlights => 'طيران';

  @override
  String get searchHotels => 'فنادق';

  @override
  String get searchCars => 'تأجير سيارات';

  @override
  String get searchPackages => 'إجازات';

  @override
  String get homeNavActivities => 'أنشطة';

  @override
  String get searchTransfers => ' transfére المطار';

  @override
  String get groupsTitle => 'الجروبات';

  @override
  String get groupsSubtitle => 'خططوا معًا وسافروا معًا';

  @override
  String get viewAll => 'عرض الكل';

  @override
  String get continueAsGuest => 'الاستكشاف كضيف';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get currency => 'العملة';

  @override
  String get wishlist => 'المفضلة';

  @override
  String get myTrips => 'رحلاتي';

  @override
  String get tripDetails => 'تفاصيل الرحلة';

  @override
  String get upcoming => 'القادمة';

  @override
  String get cancelled => 'ملغاة';

  @override
  String get past => 'السابقة';

  @override
  String get tripsEmptyUpcomingTitle => 'لا رحلات قادمة بعد';

  @override
  String get tripsEmptyCancelledTitle => 'لا توجد حجوزات ملغاة';

  @override
  String get tripsEmptyPastTitle => 'لا رحلات سابقة بعد';

  @override
  String get tripsEmptyBody => 'تظهر حجوزاتك المؤكَّدة هنا تلقائيًا.';

  @override
  String tripTravellersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مسافر',
      many: '$count مسافرًا',
      few: '$count مسافرين',
      two: 'مسافران',
      one: 'مسافر واحد',
    );
    return '$_temp0';
  }

  @override
  String get tripNotFoundTitle => 'الرحلة غير موجودة';

  @override
  String get tripNotFoundBody =>
      'هذه الرحلة غير موجودة في رحلاتي. تظهر الرحلات هنا بعد تأكيد الحجز داخل التطبيق.';

  @override
  String get tripStatusPending => 'قيد الانتظار';

  @override
  String get tripStatusCancelled => 'ملغاة';

  @override
  String get tripStatusFailed => 'فشل';

  @override
  String get tripStatusDraft => 'مسودة';

  @override
  String get tripTypeHotel => 'فندق';

  @override
  String get tripTypeFlight => 'طيران';

  @override
  String get tripTypeCar => 'سيارة';

  @override
  String get tripTypePackage => 'باقة';

  @override
  String get tripTypeBooking => 'حجز';

  @override
  String get readyToBook => 'جاهز للحجز؟';

  @override
  String get reviewBooking => 'مراجعة الحجز';

  @override
  String get passengerDetails => 'بيانات المسافرين';

  @override
  String get addOns => 'إضافات';

  @override
  String bookingStepOf(String current, String total) {
    return 'الخطوة $current من $total';
  }

  @override
  String get checkoutPaymentMethod => 'طريقة الدفع';

  @override
  String get checkoutCard => 'بطاقة ائتمان / خصم';

  @override
  String get checkoutWallet => 'محفظة رقمية';

  @override
  String get checkoutCardDetails => 'بيانات البطاقة';

  @override
  String get checkoutPriceBreakdown => 'تفاصيل السعر';

  @override
  String get checkoutProcessing => 'جاري تنفيذ الدفع…';

  @override
  String get payment => 'الدفع';

  @override
  String get confirmation => 'التأكيد';

  @override
  String get bookNow => 'احجز الآن';

  @override
  String get total => 'الإجمالي';

  @override
  String get continueAction => 'متابعة';

  @override
  String get adminPanel => 'لوحة الأدمن';

  @override
  String get adminContent => 'محتوى الصفحة الرئيسية';

  @override
  String get adminProviders => 'مزوّدو الخدمات (API)';

  @override
  String get adminAddSection => 'إضافة قسم';

  @override
  String get adminAddCard => 'إضافة كارت';

  @override
  String get adminEditCard => 'تعديل الكارت';

  @override
  String get adminType => 'نوع الكارت';

  @override
  String get adminTitle => 'العنوان';

  @override
  String get adminSubtitle => 'العنوان الفرعي';

  @override
  String get adminImageUrl => 'رابط الصورة';

  @override
  String get adminPrice => 'السعر';

  @override
  String get adminCurrency => 'العملة';

  @override
  String get adminRating => 'التقييم';

  @override
  String get adminBadge => 'الشارة';

  @override
  String get adminActionLabel => 'نص الزر';

  @override
  String get adminStatus => 'الحالة';

  @override
  String get adminDraft => 'مسودة';

  @override
  String get adminPublished => 'منشور';

  @override
  String get adminVisible => 'ظاهر';

  @override
  String get adminDelete => 'حذف';

  @override
  String get adminMoveUp => 'تحريك لأعلى';

  @override
  String get adminMoveDown => 'تحريك لأسفل';

  @override
  String get adminSave => 'حفظ';

  @override
  String get adminCancel => 'إلغاء';

  @override
  String get adminPreview => 'معاينة حية';

  @override
  String get adminHealthCheck => 'فحص الحالة';

  @override
  String get adminLatency => 'زمن الاستجابة';

  @override
  String get adminActive => 'نشط';

  @override
  String get adminPriority => 'الأولوية';

  @override
  String get adminRefreshRegistry => 'تطبيق التغييرات';

  @override
  String get adminEmpty => 'لا يوجد محتوى بعد. أضف أول قسم.';

  @override
  String get adminError => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get adminRetry => 'إعادة المحاولة';

  @override
  String get adminLoading => 'جارٍ التحميل…';

  @override
  String get adminSaved => 'تم الحفظ';

  @override
  String get adminFlight => 'طيران';

  @override
  String get adminHotel => 'فنادق';

  @override
  String get adminCar => 'عربيات';

  @override
  String get adminPackage => 'برامج';

  @override
  String get adminDestination => 'وجهات';

  @override
  String get adminDeal => 'عروض';

  @override
  String get adminTabletOnlyTitle => 'افتح لوحة الأدمن على شاشة أكبر';

  @override
  String get adminTabletOnlyBody =>
      'جداول الأدمن تحتاج عرض 480 نقطة على الأقل. افتح توكيغو على جهاز لوحي أو في متصفح سطح المكتب لإدارة المحتوى والمزوّدين.';

  @override
  String get adminTableSection => 'القسم';

  @override
  String get adminTableCards => 'الكروت';

  @override
  String get adminTableStatus => 'الحالة';

  @override
  String get adminTableProvider => 'المزوّد';

  @override
  String get adminTablePriority => 'الأولوية';

  @override
  String get adminTableLatency => 'زمن الاستجابة';

  @override
  String get adminHealthy => 'سليم';

  @override
  String get adminUnhealthy => 'غير سليم';

  @override
  String get adminUnknown => 'غير معروف';

  @override
  String get adminFallback => 'احتياطي';

  @override
  String get adminLayout => 'التخطيط';

  @override
  String get adminPriorityUp => 'رفع الأولوية';

  @override
  String get adminPriorityDown => 'خفض الأولوية';

  @override
  String get adminToggleCards => 'عرض كروت القسم';

  @override
  String get adminNoProviders => 'لا يوجد مزوّد مُهيّأ لهذا القسم بعد.';

  @override
  String get settingsAccount => 'الحساب';

  @override
  String get settingsAppLanguage => 'لغة التطبيق';

  @override
  String get settingsPreferences => 'التفضيلات';

  @override
  String get settingsAbout => 'حول التطبيق';

  @override
  String get settingsDangerZone => 'منطقة الخطر';

  @override
  String get settingsVersion => 'الإصدار';

  @override
  String get aiMemoryTitle => 'اللي أعرفه عنك';

  @override
  String get aiMemorySubtitle =>
      'حقائق شاركتها في محادثات الذكاء الاصطناعي. تقدر تعدّلها أو تحذفها في أي وقت.';

  @override
  String get aiMemorySignInPrompt =>
      'سجّل الدخول لتشاهد وتتحكم في اللي المساعد الذكي يتذكره عنك.';

  @override
  String get aiMemoryEmpty =>
      'مفيش حاجة بعد. الحقائق اللي هتشاركها مع المساعد الذكي هتظهر هنا.';

  @override
  String get aiMemoryEdit => 'تعديل';

  @override
  String get aiMemoryDelete => 'حذف';

  @override
  String get aiMemoryDeleted => 'تم الحذف.';

  @override
  String get aiMemoryClearAll => 'حذف الكل';

  @override
  String get aiMemoryClearAllConfirm =>
      'تحذف كل الحقائق المعروضة هنا؟ ملفك الشخصي وسجل سفرك مش هيتأثروا.';

  @override
  String get aiMemoryClearedAll => 'تم حذف كل الحقائق.';

  @override
  String get aiMemoryFieldDestination => 'الوجهة';

  @override
  String get aiMemoryFieldBudgetMin => 'أقل ميزانية';

  @override
  String get aiMemoryFieldBudgetMax => 'أقصى ميزانية';

  @override
  String get aiMemoryFieldBudgetCurrency => 'عملة الميزانية';

  @override
  String get aiMemoryBudgetCurrencyNone => 'بدون عملة';

  @override
  String get aiMemoryFieldStyles => 'أساليب السفر';

  @override
  String get aiMemoryFieldStylesHelper => 'افصل بين الأساليب بفواصل';

  @override
  String get aiMemoryMemoryButton => 'اللي أعرفه عنك';

  @override
  String get voiceSearch => 'البحث الصوتي';

  @override
  String get voiceStarting => 'جارٍ بدء البحث الصوتي…';

  @override
  String get voiceStop => 'إيقاف البحث الصوتي';

  @override
  String get voiceErrorPermission => 'الوصول للمايك مطلوب للبحث الصوتي.';

  @override
  String get voiceErrorUnavailable => 'البحث الصوتي غير متاح على هذا الجهاز.';

  @override
  String get voiceErrorEmpty => 'لم أسمع شيئًا — حاول التحدث مرة أخرى.';

  @override
  String get onboardingHeroTitle => 'مغامرتك القادمة في انتظارك';

  @override
  String get onboardingHeroBody =>
      'احجز الطيران والفنادق والمزيد — كل ذلك في مكان واحد.';

  @override
  String get onboardingAiTitle => 'رفيق سفرك بالذكاء الاصطناعي';

  @override
  String get onboardingAiBody =>
      'اسأل عن أي شيء: خطّط لعطلة نهاية أسبوع، اعثر على بدائل أرخص، وقارن العروض.';

  @override
  String get onboardingBagTitle => 'كل رحلاتك في مكان واحد';

  @override
  String get onboardingBagBody =>
      'كل حجز يُحفظ في مكان واحد — مع فحوصات الجاهزية ومتابعة الأسعار.';

  @override
  String get onboardingGetStarted => 'ابدأ الآن';

  @override
  String get onboardingNext => 'التالي';

  @override
  String get onboardingStartExploring => 'ابدأ الاستكشاف';

  @override
  String get onboardingSkip => 'تخطّي';

  @override
  String get onboardingHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String get onboardingLogIn => 'تسجيل الدخول';

  @override
  String get packagesUnavailableTitle => 'الإجازات قادمة قريبًا';

  @override
  String get packagesUnavailableBody =>
      'نعمل على إضافة مزوّدي الباكدجات. الرحلات والفنادق متاحة الآن.';

  @override
  String get carsUnavailableTitle => 'تأجير السيارات قادم قريبًا';

  @override
  String get carsUnavailableBody =>
      'نعمل على إضافة مزوّدي تأجير السيارات. الرحلات والفنادق متاحة الآن.';

  @override
  String get findFlights => 'ابحث عن رحلات';

  @override
  String get findHotels => 'ابحث عن فنادق';

  @override
  String get packagesSubtitle => 'برامج مُنسّقة متعددة الأيام';

  @override
  String get carsSubtitle => 'تأجير سيارات بالقيادة الذاتية';

  @override
  String get carsLiveSubtitle => 'سيارات للإيجار في وجهتك';

  @override
  String get aiSomethingWentWrong => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get aiNoSuggestions => 'لا توجد اقتراحات الآن. جرّب طلبًا مختلفًا.';

  @override
  String get aiTryAgain => 'حاول مرة أخرى';

  @override
  String get aiSendPrompt => 'إرسال الطلب';

  @override
  String get aiModeActive => 'وضع الذكاء الاصطناعي مفعّل';

  @override
  String get aiTravelCopilot => 'رفيقك في السفر';

  @override
  String get viewList => 'قائمة';

  @override
  String get viewMap => 'خريطة';

  @override
  String get sortResults => 'ترتيب النتائج';

  @override
  String get bookingNoSelection => 'لا يوجد حجز محدد';

  @override
  String get bookingStatusTitle => 'الحالة';

  @override
  String get bookingStepPreparing => 'جارٍ تجهيز الحجز';

  @override
  String get bookingStepValidatingPrice => 'جارٍ التحقق من السعر';

  @override
  String get bookingStepReady => 'جاهز للتأكيد';

  @override
  String get bookingPriceChanged => 'تغيّر السعر';

  @override
  String get bookingAcceptNewPrice => 'قبول السعر الجديد';

  @override
  String get bookingPrepare => 'تجهيز الحجز';

  @override
  String get bookingValidating => 'جارٍ التحقق…';

  @override
  String get bookingValidatePrice => 'تحقق من السعر';

  @override
  String get bookingConfirming => 'جارٍ التأكيد…';

  @override
  String get bookingViewTrip => 'اعرض رحلتي';

  @override
  String get bookingOfferUnavailable =>
      'هذا العرض لم يعد متاحًا. اختر عرضًا آخر.';

  @override
  String get carPickupLocation => 'موقع الاستلام';

  @override
  String get mapViewComingSoon => 'عرض الخريطة قريبًا';

  @override
  String get mapIntegrationUnavailable =>
      'تكامل الخريطة غير متاح بعد. تُعرض النتائج في وضع القائمة.';

  @override
  String get carDropoffLocation => 'موقع التسليم';

  @override
  String get carPickupHint => 'موقع الاستلام';

  @override
  String get carDropoffHint => 'موقع التسليم';

  @override
  String get carPickUpShort => 'الاستلام';

  @override
  String get carDropOffShort => 'التسليم';

  @override
  String get carSearchCta => 'ابحث عن سيارة';

  @override
  String get carFindYourRide => 'اعثر على سيارتك';

  @override
  String get carNoMatchesTitle => 'لا نتائج لعوامل التصفية';

  @override
  String get carNoCarsTitle => 'لا توجد سيارات';

  @override
  String get carConnectionErrorTitle => 'خطأ في الاتصال';

  @override
  String get bookingAddTraveller => 'أضف مسافرًا';

  @override
  String get bookingContactInformation => 'معلومات التواصل';

  @override
  String get bookingRemoveTraveller => 'احذف المسافر';

  @override
  String get bookingFirstName => 'الاسم الأول';

  @override
  String get bookingLastName => 'اسم العائلة';

  @override
  String get bookingRequiredField => 'مطلوب';

  @override
  String get bookingEmailLabel => 'البريد الإلكتروني';

  @override
  String get bookingPhoneLabel => 'رقم الهاتف';

  @override
  String get bookingValidEmail => 'أدخل بريدًا إلكترونيًا صحيحًا';

  @override
  String get bookingValidPhone => 'أدخل رقم هاتف صحيحًا';

  @override
  String get groupsCreateTrip => 'أنشئ رحلة جماعية';

  @override
  String get groupsPlanTogether => 'خططوا معًا، وقرروا معًا';

  @override
  String get carIdleBody =>
      'قارن عروض تأجير السيارات في نقاط الاستلام حول العالم';

  @override
  String get carNoMatchesBody => 'جرّب توسيع نطاق السعر أو مسح عوامل التصفية';

  @override
  String get carNoCarsBody => 'جرّب مكانًا أو تواريخ أخرى';

  @override
  String get offlineShowingCached =>
      'أنت غير متصل بالإنترنت — نعرض آخر بيانات تم حفظها';

  @override
  String get homeCompleteYourTrip => 'أكمل رحلتك';

  @override
  String get homeFinishWhatYouStarted => 'أكمل ما بدأته';

  @override
  String homeForYourTripTo(Object destination) {
    return 'لرحلة إلى $destination';
  }

  @override
  String homeBecauseYouViewed(Object title) {
    return 'لأنك شاهدت $title';
  }

  @override
  String get homePicksRelatedToWhatYouSaw => 'اختيارات مرتبطة بما شاهدته';

  @override
  String get homePickedForYou => 'مختارة لك';

  @override
  String get homeBasedOnYourProfile => 'بناءً على ملفك';

  @override
  String get homeBasedOnRecentSearches => 'بناءً على عمليات بحثك الأخيرة';

  @override
  String get homeBasedOnWhatYouViewed => 'بناءً على ما شاهدته';

  @override
  String get homeYourFavoritesFirst => 'مفضلاتك أولًا';

  @override
  String get homeMatchedToYourPreferences => 'مطابقة لتفضيلاتك';

  @override
  String get homeForYourUpcomingTrip => 'لرحلتك القادمة';

  @override
  String get homePopularNearYou => 'شائع بالقرب منك';

  @override
  String get homeBecauseYouViewedThis => 'لأنك شاهدت هذا';

  @override
  String get tripCancelBooking => 'إلغاء الحجز';

  @override
  String get tripCancelTitle => 'هل تريد إلغاء هذا الحجز؟';

  @override
  String get tripCancelBody =>
      'المزوّد هو من يقرر ما إذا كان يمكن إلغاء هذا الحجز. وإن لم يكن، ف سيخبرك بالسبب.';

  @override
  String get tripCancelConfirm => 'إلغاء الحجز';

  @override
  String get tripCancelKeep => 'أبقِ الحجز';

  @override
  String get tripCancelled => 'تم إلغاء الحجز';

  @override
  String get profileGuestSavedPlaces => 'الأماكن المحفوظة';

  @override
  String get profileGuestSavedPlacesBody =>
      'الإقامات التي حفظتها بعلامة القلب موجودة على هذا الجهاز — بدون حساب.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get addOnsProviderTitle => 'الإضافات بسعر المزوّد';

  @override
  String get addOnsProviderBody =>
      'الشنط الإضافية والمقاعد والوجبات بيبيعها المزوّد لسعرك المحدد. هتظهر هنا بسعر المزوّد نفسه أول ما يتوصل، وإحنا مبنقدّرش سعر من عندنا.';

  @override
  String get notificationsEmptyTitle => 'مفيش إشعارات لحد الآن';

  @override
  String get notificationsEmptyBody =>
      'تحديثات الحجز وتنبيهات الأسعار وتذكيرات التسجيل هتظهر هنا لما تحصل فعلًا. إحنا مش بنختلقها.';

  @override
  String get notificationToday => 'اليوم';

  @override
  String get notificationEarlier => 'في وقت سابق';

  @override
  String get notificationUnread => 'غير مقروء';

  @override
  String get wishlistEmptyTitle => 'مفيش حاجة محفوظة لحد الآن';

  @override
  String get wishlistEmptyBody =>
      'دوس على القلب في أي فندق أو رحلة أو باقة عشان تحفظها هنا. الأسعار المعروضة هي أسعار المزوّد.';

  @override
  String wishlistSavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محفوظ',
      one: 'محفوظ واحد',
    );
    return '$_temp0';
  }

  @override
  String get wishlistExploreStays => 'استكشف الفنادق';

  @override
  String get groupsEmptyTitle => 'الرحلات الجماعية قادمة قريبًا';

  @override
  String get groupsEmptyBody =>
      'إنشاء رحلة ودعوة الأصدقاء وتقسيم الخطة هيتفتحوا هنا أول ما يتم ربط خدمات الرحلات الجماعية.';

  @override
  String get exploreCitiesTitle => 'مدن تناسب مودك';

  @override
  String get createNewTrip => 'أنشئ رحلة جديدة';

  @override
  String get tripBuilderTitle => 'خطط رحلتك';

  @override
  String get tripBuilderCancel => 'إلغاء التخطيط';

  @override
  String get tripBuilderStartFromHome => 'ابدأ باختيار مدينة من الرئيسية.';

  @override
  String get tripBuilderAddProducts => 'أضف إلى رحلتك';

  @override
  String get tripBuilderSelected => 'اختيارات رحلتك';

  @override
  String get tripBuilderEmpty =>
      'اختار فندقًا أو رحلة طيران أو سيارة لإضافتها هنا.';

  @override
  String get tripBuilderRemove => 'إزالة من الرحلة';

  @override
  String get tripBuilderTotal => 'الإجمالي الحالي';

  @override
  String get tripBuilderTotalNote =>
      'الإجمالي يجمع أسعار الاختيارات الحالية. قد تختلف العملة بين المزودين، والحجز والدفع يتمان لكل اختيار عبر المزود.';

  @override
  String get tripBuilderAddToTrip => 'أضف إلى الرحلة';

  @override
  String get homeEmptyTitle => 'لا توجد توصيات الآن';

  @override
  String get homeEmptyBody =>
      'لا توجد فنادق متاحة للنصيحة بها حاليًا. ابحث عن وجهة، أو حاول مرة أخرى بعد قليل.';

  @override
  String get homeErrorTitle => 'تعذّر الوصول إلى خدمة السفر';

  @override
  String get homeErrorBody =>
      'قد تكون مشكلة في الاتصال أو عند مزوّد الخدمة. لا شيء ضائع — حاول مرة أخرى.';

  @override
  String get checkoutNoBookingTitle => 'الحجز ده لسه مش جاهز للدفع';

  @override
  String get checkoutNoBookingBody =>
      'مفيش حجز مُجهَّز للرحلة دي، فمفيش حاجة تتحصّل. ارجع لمراجعة الحجز وجهّزه من جديد.';

  @override
  String get checkoutProviderPrice => 'سعر الرحلة (من المزوّد)';

  @override
  String get paymentFailedBody =>
      'الدفع مكتملش، فمفيش حجز اتعمل ومفيش مبلغ اتحصّل.';

  @override
  String get paymentUnavailableBody =>
      'الدفع مش متاح دلوقتي، فمفيش حجز اتعمل. جرّب تاني بعد شوية.';

  @override
  String get paymentPendingBody =>
      'البنك لسه بيتحقق من الدفع. الحجز هيتأكد أول ما الدفع يكتمل.';

  @override
  String get bookingConfirmFailedBody =>
      'الدفع مكتملش، فالحجز متأكّدش. مفيش حجز اتعمل.';

  @override
  String get bookingConfirmLabel => 'تأكيد الحجز';

  @override
  String payAmount(String amount) {
    return 'ادفع $amount';
  }

  @override
  String get confirmationNoneTitle => 'مفيش حجز مؤكَّد لعرضه';

  @override
  String get confirmationNoneBody =>
      'الشاشة دي بتعرض الحجز اللي المزوّد أكّده فعلًا. مفيش حاجة متأكّدة للرحلة دي لحد الآن.';

  @override
  String get bookingConfirmedTitle => 'تم تأكيد الحجز';

  @override
  String get confirmationSubtitle => 'احتفظ برقم الحجز لإدارة حجزك مع المزوّد.';

  @override
  String get confirmationCopyReference => 'نسخ رقم الحجز';

  @override
  String get confirmationCopied => 'تم النسخ';

  @override
  String get confirmationDeparture => 'المغادرة';

  @override
  String get confirmationArrival => 'الوصول';

  @override
  String get bookingReferenceLabel => 'رقم الحجز';

  @override
  String get bookingStatusConfirmed => 'مؤكَّد';

  @override
  String get statusLabel => 'الحالة';

  @override
  String get bookingTravellersLabel => 'المسافرون';

  @override
  String get bookingBackHome => 'الرجوع للرئيسية';

  @override
  String get flightSearchSubtitle => 'ابحث عن رحلات من كل المزوّدين';

  @override
  String get tripTypeOneWay => 'ذهاب فقط';

  @override
  String get tripTypeMultiCity => 'رحلة متعددة المدن';

  @override
  String get flightAddLeg => 'أضف رحلة أخرى';

  @override
  String get flightRemoveLeg => 'احذف الرحلة';

  @override
  String flightLegLabel(int n) {
    return 'الرحلة $n';
  }

  @override
  String get flightLegsIncomplete => 'أكمل بيانات كل رحلة قبل البحث';

  @override
  String get flightLegsMax => 'الرحلة متعددة المدن 최대 6 رحلات';

  @override
  String get tripTypeRoundTrip => 'ذهاب وعودة';

  @override
  String get fieldFrom => 'من';

  @override
  String get fieldTo => 'إلى';

  @override
  String get fieldDeparture => 'المغادرة';

  @override
  String get fieldReturn => 'العودة';

  @override
  String get selectAirport => 'اختر المطار';

  @override
  String get selectAction => 'اختر';

  @override
  String get pickDateHint => 'اختر التاريخ';

  @override
  String get swapRoute => 'تبديل نقطة الانطلاق والوصول';

  @override
  String get cabinEconomy => 'اقتصادية';

  @override
  String passengersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مسافر',
      many: '$count مسافرًا',
      few: '$count مسافرين',
      two: 'مسافران',
      one: 'مسافر واحد',
      zero: 'لا مسافرين',
    );
    return '$_temp0';
  }

  @override
  String get sortRecommended => 'المقترح';

  @override
  String get sortCheapest => 'الأرخص';

  @override
  String get sortFastest => 'الأسرع';

  @override
  String get sortLongest => 'الأطول';

  @override
  String get filtersAction => 'الفلاتر';

  @override
  String get filtersReset => 'إعادة تعيين';

  @override
  String get filtersApply => 'تطبيق الفلاتر';

  @override
  String get filterPriceRange => 'نطاق السعر';

  @override
  String get filterHotelClass => 'تصنيف الفندق';

  @override
  String get filterGuestScore => 'تقييم النزلاء';

  @override
  String get filterStops => 'الوقفات';

  @override
  String get filterDirect => 'مباشر';

  @override
  String get filterAny => 'أي';

  @override
  String get filterAirlines => 'شركات الطيران';

  @override
  String get flightIdleTitle => 'دوّر على رحلتك';

  @override
  String get flightIdleBody => 'قارن الأسعار بين شركات الطيران لرحلتك القادمة';

  @override
  String get flightEmptyTitle => 'مفيش رحلات';

  @override
  String get flightEmptyBody => 'جرّب تواريخ تانية أو مطارات قريبة';

  @override
  String get searchFilteredEmptyTitle => 'مفيش نتائج للفلاتر';

  @override
  String searchBudgetCap(Object amount, Object currency) {
    return 'حتى $amount $currency';
  }

  @override
  String searchBudgetNoCurrency(Object amount) {
    return 'الميزانية $amount بدون عملة — لم تُطبَّق';
  }

  @override
  String get searchBudgetRemove => 'إزالة فلتر الميزانية';

  @override
  String get searchBudgetApply => 'تطبيق فلتر الميزانية';

  @override
  String searchBudgetNotApplicable(Object currency) {
    return 'الميزانية غير مطبَّقة — الأسعار المعروضة بـ $currency';
  }

  @override
  String get searchFilteredEmptyBody => 'جرّب توسّع نطاق السعر أو شيل الفلاتر';

  @override
  String get searchErrorTitle => 'خطأ في الاتصال';

  @override
  String get searchErrorBody => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get pickerFromTitle => 'من فين؟';

  @override
  String get pickerSearchHint => 'ابحث…';

  @override
  String get pickerNoMatches => 'مفيش نتائج';

  @override
  String get flightRouteRequired => 'اختر نقطة الانطلاق والوصول الأول.';

  @override
  String get hotelDestination => 'الوجهة';

  @override
  String get hotelIdleTitle => 'دوّر على إقامتك';

  @override
  String get hotelIdleBody => 'اكتب الوجهة والتواريخ لعرض الغرف المتاحة.';

  @override
  String get hotelEmptyTitle => 'مفيش فنادق';

  @override
  String get hotelEmptyBody => 'جرّب وجهة تانية أو تواريخ تانية';

  @override
  String get hotelDestinationRequired => 'اكتب الوجهة الأول.';

  @override
  String get hotelSortTopRated => 'الأعلى تقييمًا';

  @override
  String get hotelRatingAll => 'الكل';

  @override
  String get hotelLoading => 'جارٍ تحميل الفندق';

  @override
  String get hotelFreeCancellation => 'إلغاء مجاني';

  @override
  String hotelNightsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ليلة',
      many: '$count ليلة',
      few: '$count ليالٍ',
      two: 'ليلتان',
      one: 'ليلة واحدة',
    );
    return '$_temp0';
  }

  @override
  String hotelGuestsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ضيف',
      many: '$count ضيفًا',
      few: '$count ضيوف',
      two: 'ضيفان',
      one: 'ضيف واحد',
    );
    return '$_temp0';
  }

  @override
  String hotelRoomsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غرفة',
      many: '$count غرفة',
      few: '$count غرف',
      two: 'غرفتان',
      one: 'غرفة واحدة',
    );
    return '$_temp0';
  }

  @override
  String cityStaysCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إقامة',
      one: 'إقامة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get discoverTitle => 'اكتشف';

  @override
  String get discoverMore => 'اكتشف المزيد';

  @override
  String hotelResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إقامة',
      many: '$count إقامة',
      few: '$count إقامات',
      two: 'إقامتان',
      one: 'إقامة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get editSearch => 'تعديل البحث';

  @override
  String hotelStarClass(Object count) {
    return 'فنادق $count نجوم';
  }

  @override
  String get sortBy => 'ترتيب حسب';

  @override
  String hotelRatingSemantics(Object rating, Object count) {
    return '$rating نجوم، $count مراجعة';
  }

  @override
  String get unitNight => 'ليلة';

  @override
  String get unitDay => 'يوم';

  @override
  String get unitPerson => 'شخص';

  @override
  String get cardTotalLabel => 'الإجمالي';

  @override
  String get cardFromLabel => 'من';

  @override
  String cardSaveLabel(Object amount) {
    return 'وفّر $amount';
  }

  @override
  String get cardTaxesIncludedLabel => 'شامل الضرائب';

  @override
  String get cardTaxesExtraLabel => 'ضرائب إضافية';

  @override
  String cardPerUnitSemantics(Object unit, Object amount, Object currency) {
    return '$amount $currency لكل $unit';
  }

  @override
  String cardPerUnitLabel(Object unit) {
    return 'لكل $unit';
  }

  @override
  String cardTotalSemantics(Object amount, Object currency) {
    return 'الإجمالي $amount $currency';
  }

  @override
  String get offerAbout => 'عن العرض';

  @override
  String get offerAmenities => 'المرافق';

  @override
  String get offerAircraft => 'الطائرة';

  @override
  String get offerBaggage => 'الأمتعة';

  @override
  String get offerBoard => 'الوجبات';

  @override
  String get offerCabin => 'الدرجة';

  @override
  String get offerCancellation => 'سياسة الإلغاء';

  @override
  String get offerCarType => 'النوع';

  @override
  String get offerCheckIn => 'تسجيل الدخول';

  @override
  String get offerCheckOut => 'تسجيل الخروج';

  @override
  String get offerDestination => 'الوجهة';

  @override
  String get offerDuration => 'المدة';

  @override
  String get offerFare => 'نوع التذكرة';

  @override
  String get offerFeatures => 'المزايا';

  @override
  String get offerInclusions => 'المشمولات';

  @override
  String get offerMileage => 'الكيلومترات';

  @override
  String get offerNonRefundableRate => 'سعر غير قابل للاسترداد';

  @override
  String get offerPickup => 'الاستلام';

  @override
  String get offerDropOff => 'التسليم';

  @override
  String get offerPrice => 'السعر';

  @override
  String get offerPriceNote =>
      'هذا إجمالي المزوّد نفسه، ولا نضيف عليه أي مبلغ.';

  @override
  String get offerProvider => 'المزوّد';

  @override
  String get offerRating => 'التقييم';

  @override
  String get offerRefundable => 'قابل للاسترداد';

  @override
  String get offerRefundableRate => 'سعر قابل للاسترداد';

  @override
  String get offerRefundableYes => 'نعم';

  @override
  String get offerRevalidated => 'يُعاد تأكيده عند الحجز';

  @override
  String get offerRoom => 'الغرفة';

  @override
  String get offerSeats => 'المقاعد';

  @override
  String get offerStars => 'النجوم';

  @override
  String get offerTaxesFees => 'الضرائب والرسوم';

  @override
  String get offerTotalFromProvider => 'الإجمالي (من المزوّد)';

  @override
  String get offerTransmission => 'ناقل الحركة';

  @override
  String get offerBadgeCheapest => 'الأرخص';

  @override
  String get offerBadgeFastest => 'الأسرع';

  @override
  String get offerBadgeBestValue => 'أفضل قيمة';

  @override
  String get offerWarningSelfTransfer => 'ترانزيت ذاتي';

  @override
  String get offerWarningAirportChange => 'تغيير مطار';

  @override
  String get offerWarningRiskyConnection => 'ترانزيت ضيق';

  @override
  String get offerWarningOvernight => 'رحلة ليلية';

  @override
  String get offerWarningLongLayover => 'انتظار طويل';

  @override
  String get offerLoadingFlight => 'جارٍ تحميل الرحلة';

  @override
  String get offerSaved => 'محفوظة';

  @override
  String get offerTaxesIncluded => '(مضمنة في السعر)';

  @override
  String offerReviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مراجعة',
      many: '$count مراجعة',
      few: '$count مراجعات',
      two: 'مراجعتان',
      one: 'مراجعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get offerPerNightStated => 'سعر المزوّد المعلن لليلة';

  @override
  String offerPerNightDerived(Object nights) {
    return 'إجمالي المزوّد ÷ $nights';
  }

  @override
  String get offerCheckAvailability => 'تحقق من التوفر';

  @override
  String offerDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String offerStopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count وقفة',
      many: '$count وقفة',
      few: '$count وقفات',
      two: 'وقفتان',
      one: 'وقفة واحدة',
      zero: 'بدون وقفات',
    );
    return '$_temp0';
  }

  @override
  String offerStopsWithAirport(Object airport) {
    return 'وقفة واحدة ($airport)';
  }

  @override
  String offerLayover(Object duration) {
    return 'انتظار $duration';
  }

  @override
  String offerSeatsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقعد فقط',
      many: '$count مقعدًا فقط',
      few: '$count مقاعد فقط',
      two: 'مقعدان فقط',
      one: 'مقعد واحد فقط',
    );
    return '$_temp0';
  }

  @override
  String offerCardTotal(Object amount) {
    return 'الإجمالي $amount';
  }

  @override
  String offerFreeCancellationUntil(Object date) {
    return 'إلغاء مجاني حتى $date';
  }

  @override
  String offerCancellationFeeNote(Object fee) {
    return 'رسوم الإلغاء بعد ذلك: $fee';
  }

  @override
  String offerSemanticsFlightRoute(Object origin, Object destination) {
    return 'رحلة من $origin إلى $destination';
  }

  @override
  String offerSemanticsFlightNumber(Object number) {
    return 'رحلة $number';
  }

  @override
  String offerSemanticsDeparts(Object time) {
    return 'المغادرة $time';
  }

  @override
  String offerSemanticsArrives(Object time) {
    return 'الوصول $time';
  }

  @override
  String offerSemanticsDuration(Object duration) {
    return 'المدة $duration';
  }

  @override
  String offerSemanticsPrice(Object amount) {
    return 'السعر $amount';
  }

  @override
  String offerSemanticsTotal(Object amount) {
    return 'الإجمالي $amount';
  }

  @override
  String get locationPromptTitle => 'فعّل موقعك لاقتراح مطار الإقلاع الصح';

  @override
  String get locationPromptBody =>
      'بنقرأ بلدك مرة واحدة لاقتراح مطار إقلاع. موقعك الدقيق مش بيتخزّن في التطبيق.';

  @override
  String get locationPromptAllow => 'تفعيل الموقع';

  @override
  String get locationPromptNotNow => 'مش دلوقتي';

  @override
  String get locationPromptBlockedTitle => 'صلاحية الموقع مقفولة';

  @override
  String get locationPromptBlockedBody =>
      'اسمح بالموقع لتوكي جو من إعدادات النظام عشان نقترح مطار الإقلاع.';

  @override
  String get locationPromptOpenSettings => 'فتح الإعدادات';

  @override
  String get locationPromptServiceOffTitle => 'خدمة الموقع مقفولة';

  @override
  String get locationPromptServiceOffBody =>
      'فعّل خدمة الموقع عشان نقترح مطار الإقلاع.';

  @override
  String get locationPromptLocationSettings => 'إعدادات الموقع';

  @override
  String get locationChooseCountry => 'اختار بلدك يدويًا';

  @override
  String get locationCountrySaveFailed => 'تعذر حفظ البلد. حاول مرة أخرى.';

  @override
  String get settingsCountry => 'البلد';

  @override
  String get settingsCountryNotSet => 'اختار البلد';
}
