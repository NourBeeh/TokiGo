import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'TokiGo'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get navGroups;

  /// No description provided for @navExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get navExplore;

  /// No description provided for @navAi.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get navAi;

  /// No description provided for @bag.
  ///
  /// In en, this message translates to:
  /// **'My Trips'**
  String get bag;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @profileGuestTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re browsing as a guest'**
  String get profileGuestTitle;

  /// No description provided for @profileGuestBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to keep your trips, saved places and preferences.'**
  String get profileGuestBody;

  /// No description provided for @profileTraveller.
  ///
  /// In en, this message translates to:
  /// **'Traveller'**
  String get profileTraveller;

  /// No description provided for @profileErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your account'**
  String get profileErrorTitle;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get searchHint;

  /// No description provided for @aiSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Where do you want to go?'**
  String get aiSearchHint;

  /// No description provided for @aiSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get aiSend;

  /// No description provided for @aiOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Open TokiGo AI'**
  String get aiOpenChat;

  /// No description provided for @aiHintPhrase1.
  ///
  /// In en, this message translates to:
  /// **'Ask Toki AI — Your Travel Assistant'**
  String get aiHintPhrase1;

  /// No description provided for @aiHintPhrase2.
  ///
  /// In en, this message translates to:
  /// **'Where do you want to go?'**
  String get aiHintPhrase2;

  /// No description provided for @aiHintPhrase3.
  ///
  /// In en, this message translates to:
  /// **'Hotels in Istanbul? Flights to Cairo?'**
  String get aiHintPhrase3;

  /// No description provided for @aiSearchSheetHint.
  ///
  /// In en, this message translates to:
  /// **'Where do you want to go?'**
  String get aiSearchSheetHint;

  /// No description provided for @aiSearchNoSuggestions.
  ///
  /// In en, this message translates to:
  /// **'No suggestions right now. Try a different prompt.'**
  String get aiSearchNoSuggestions;

  /// No description provided for @aiSearchError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get aiSearchError;

  /// No description provided for @aiSearchSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get aiSearchSuggestions;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentSearches;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @aiSearchEditQuery.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get aiSearchEditQuery;

  /// No description provided for @aiSearchResultsFor.
  ///
  /// In en, this message translates to:
  /// **'Results for \"{query}\"'**
  String aiSearchResultsFor(Object query);

  /// No description provided for @aiSearchPersonalizedHint.
  ///
  /// In en, this message translates to:
  /// **'Ordered by your preferences'**
  String get aiSearchPersonalizedHint;

  /// No description provided for @aiSearchSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get aiSearchSort;

  /// No description provided for @aiSearchSortRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get aiSearchSortRecommended;

  /// No description provided for @aiSearchSortPriceLow.
  ///
  /// In en, this message translates to:
  /// **'Price: Low to High'**
  String get aiSearchSortPriceLow;

  /// No description provided for @aiSearchSortPriceHigh.
  ///
  /// In en, this message translates to:
  /// **'Price: High to Low'**
  String get aiSearchSortPriceHigh;

  /// No description provided for @aiSearchSortRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get aiSearchSortRating;

  /// No description provided for @aiSearchRefine.
  ///
  /// In en, this message translates to:
  /// **'Refine'**
  String get aiSearchRefine;

  /// No description provided for @aiSearchRefineClear.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get aiSearchRefineClear;

  /// No description provided for @aiSearchRefineTitle.
  ///
  /// In en, this message translates to:
  /// **'Refine results'**
  String get aiSearchRefineTitle;

  /// No description provided for @aiSearchApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get aiSearchApply;

  /// No description provided for @aiSearchFilterPriceMax.
  ///
  /// In en, this message translates to:
  /// **'Max price'**
  String get aiSearchFilterPriceMax;

  /// No description provided for @aiSearchFilterMinStars.
  ///
  /// In en, this message translates to:
  /// **'Min stars'**
  String get aiSearchFilterMinStars;

  /// No description provided for @aiSearchFilterMaxStops.
  ///
  /// In en, this message translates to:
  /// **'Max stops'**
  String get aiSearchFilterMaxStops;

  /// No description provided for @aiSearchFilterMinSeats.
  ///
  /// In en, this message translates to:
  /// **'Min seats'**
  String get aiSearchFilterMinSeats;

  /// No description provided for @aiSearchFilterAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get aiSearchFilterAny;

  /// No description provided for @aiSearchCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get aiSearchCompare;

  /// No description provided for @aiSearchCompareMode.
  ///
  /// In en, this message translates to:
  /// **'Select 2–3 to compare'**
  String get aiSearchCompareMode;

  /// No description provided for @aiSearchCompareOpen.
  ///
  /// In en, this message translates to:
  /// **'Compare ({count})'**
  String aiSearchCompareOpen(Object count);

  /// No description provided for @aiSearchCompareTitle.
  ///
  /// In en, this message translates to:
  /// **'Comparison'**
  String get aiSearchCompareTitle;

  /// No description provided for @aiSearchCompareCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get aiSearchCompareCancel;

  /// No description provided for @aiSearchCompareSameType.
  ///
  /// In en, this message translates to:
  /// **'Pick products of the same type to compare.'**
  String get aiSearchCompareSameType;

  /// No description provided for @aiSearchCompareMissing.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get aiSearchCompareMissing;

  /// No description provided for @cmpPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get cmpPrice;

  /// No description provided for @cmpStars.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get cmpStars;

  /// No description provided for @cmpRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get cmpRating;

  /// No description provided for @cmpLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get cmpLocation;

  /// No description provided for @cmpAmenities.
  ///
  /// In en, this message translates to:
  /// **'Amenities'**
  String get cmpAmenities;

  /// No description provided for @cmpCancellation.
  ///
  /// In en, this message translates to:
  /// **'Cancellation'**
  String get cmpCancellation;

  /// No description provided for @cmpAirline.
  ///
  /// In en, this message translates to:
  /// **'Airline'**
  String get cmpAirline;

  /// No description provided for @cmpDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get cmpDuration;

  /// No description provided for @cmpStops.
  ///
  /// In en, this message translates to:
  /// **'Stops'**
  String get cmpStops;

  /// No description provided for @cmpBaggage.
  ///
  /// In en, this message translates to:
  /// **'Baggage'**
  String get cmpBaggage;

  /// No description provided for @cmpDeparture.
  ///
  /// In en, this message translates to:
  /// **'Departure'**
  String get cmpDeparture;

  /// No description provided for @cmpArrival.
  ///
  /// In en, this message translates to:
  /// **'Arrival'**
  String get cmpArrival;

  /// No description provided for @cmpCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get cmpCategory;

  /// No description provided for @cmpSeats.
  ///
  /// In en, this message translates to:
  /// **'Seats'**
  String get cmpSeats;

  /// No description provided for @cmpBags.
  ///
  /// In en, this message translates to:
  /// **'Bags'**
  String get cmpBags;

  /// No description provided for @cmpTransmission.
  ///
  /// In en, this message translates to:
  /// **'Transmission'**
  String get cmpTransmission;

  /// No description provided for @cmpMileage.
  ///
  /// In en, this message translates to:
  /// **'Mileage'**
  String get cmpMileage;

  /// No description provided for @cmpDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get cmpDestination;

  /// No description provided for @cmpInclusions.
  ///
  /// In en, this message translates to:
  /// **'Inclusions'**
  String get cmpInclusions;

  /// No description provided for @searchPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Where to next?'**
  String get searchPromptTitle;

  /// No description provided for @searchPromptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Plan a city break, beach escape or weekend getaway.'**
  String get searchPromptSubtitle;

  /// No description provided for @searchAllServices.
  ///
  /// In en, this message translates to:
  /// **'All services'**
  String get searchAllServices;

  /// No description provided for @homeHelloName.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String homeHelloName(Object name);

  /// No description provided for @homeStaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Hotels recommended'**
  String get homeStaysTitle;

  /// No description provided for @homeContinuePlanning.
  ///
  /// In en, this message translates to:
  /// **'Continue planning'**
  String get homeContinuePlanning;

  /// No description provided for @homeWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get homeWelcome;

  /// No description provided for @homeWelcomeSub.
  ///
  /// In en, this message translates to:
  /// **'Trips and ideas picked for you'**
  String get homeWelcomeSub;

  /// No description provided for @searchFlights.
  ///
  /// In en, this message translates to:
  /// **'Flights'**
  String get searchFlights;

  /// No description provided for @searchHotels.
  ///
  /// In en, this message translates to:
  /// **'Hotels'**
  String get searchHotels;

  /// No description provided for @searchCars.
  ///
  /// In en, this message translates to:
  /// **'Cars Rental'**
  String get searchCars;

  /// No description provided for @searchPackages.
  ///
  /// In en, this message translates to:
  /// **'Holidays'**
  String get searchPackages;

  /// No description provided for @homeNavActivities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get homeNavActivities;

  /// No description provided for @searchTransfers.
  ///
  /// In en, this message translates to:
  /// **'Airport transfer'**
  String get searchTransfers;

  /// No description provided for @groupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groupsTitle;

  /// No description provided for @groupsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Plan together, travel together'**
  String get groupsSubtitle;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get continueAsGuest;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @wishlist.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get wishlist;

  /// No description provided for @myTrips.
  ///
  /// In en, this message translates to:
  /// **'My trips'**
  String get myTrips;

  /// No description provided for @tripDetails.
  ///
  /// In en, this message translates to:
  /// **'Trip details'**
  String get tripDetails;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @past.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get past;

  /// No description provided for @tripsEmptyUpcomingTitle.
  ///
  /// In en, this message translates to:
  /// **'No upcoming trips yet'**
  String get tripsEmptyUpcomingTitle;

  /// No description provided for @tripsEmptyCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'No cancelled bookings'**
  String get tripsEmptyCancelledTitle;

  /// No description provided for @tripsEmptyPastTitle.
  ///
  /// In en, this message translates to:
  /// **'No past trips yet'**
  String get tripsEmptyPastTitle;

  /// No description provided for @tripsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Your confirmed bookings appear here automatically.'**
  String get tripsEmptyBody;

  /// No description provided for @tripTravellersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 traveller} other{{count} travellers}}'**
  String tripTravellersCount(int count);

  /// No description provided for @tripNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip not found'**
  String get tripNotFoundTitle;

  /// No description provided for @tripNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'This trip isn\'t in My Trips. Trips appear here once a booking is confirmed in the app.'**
  String get tripNotFoundBody;

  /// No description provided for @tripStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get tripStatusPending;

  /// No description provided for @tripStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get tripStatusCancelled;

  /// No description provided for @tripStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get tripStatusFailed;

  /// No description provided for @tripStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get tripStatusDraft;

  /// No description provided for @tripTypeHotel.
  ///
  /// In en, this message translates to:
  /// **'Hotel'**
  String get tripTypeHotel;

  /// No description provided for @tripTypeFlight.
  ///
  /// In en, this message translates to:
  /// **'Flight'**
  String get tripTypeFlight;

  /// No description provided for @tripTypeCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get tripTypeCar;

  /// No description provided for @tripTypePackage.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get tripTypePackage;

  /// No description provided for @tripTypeBooking.
  ///
  /// In en, this message translates to:
  /// **'Booking'**
  String get tripTypeBooking;

  /// No description provided for @readyToBook.
  ///
  /// In en, this message translates to:
  /// **'Ready to book?'**
  String get readyToBook;

  /// No description provided for @reviewBooking.
  ///
  /// In en, this message translates to:
  /// **'Review booking'**
  String get reviewBooking;

  /// No description provided for @passengerDetails.
  ///
  /// In en, this message translates to:
  /// **'Passenger details'**
  String get passengerDetails;

  /// No description provided for @addOns.
  ///
  /// In en, this message translates to:
  /// **'Add-ons'**
  String get addOns;

  /// No description provided for @bookingStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String bookingStepOf(String current, String total);

  /// No description provided for @checkoutPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get checkoutPaymentMethod;

  /// No description provided for @checkoutCard.
  ///
  /// In en, this message translates to:
  /// **'Credit / debit card'**
  String get checkoutCard;

  /// No description provided for @checkoutWallet.
  ///
  /// In en, this message translates to:
  /// **'Digital wallet'**
  String get checkoutWallet;

  /// No description provided for @checkoutCardDetails.
  ///
  /// In en, this message translates to:
  /// **'Card details'**
  String get checkoutCardDetails;

  /// No description provided for @checkoutPriceBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Price breakdown'**
  String get checkoutPriceBreakdown;

  /// No description provided for @checkoutProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing payment…'**
  String get checkoutProcessing;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @confirmation.
  ///
  /// In en, this message translates to:
  /// **'Confirmation'**
  String get confirmation;

  /// No description provided for @bookNow.
  ///
  /// In en, this message translates to:
  /// **'Book now'**
  String get bookNow;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @adminPanel.
  ///
  /// In en, this message translates to:
  /// **'Admin panel'**
  String get adminPanel;

  /// No description provided for @adminContent.
  ///
  /// In en, this message translates to:
  /// **'Home content'**
  String get adminContent;

  /// No description provided for @adminProviders.
  ///
  /// In en, this message translates to:
  /// **'API providers'**
  String get adminProviders;

  /// No description provided for @adminAddSection.
  ///
  /// In en, this message translates to:
  /// **'Add section'**
  String get adminAddSection;

  /// No description provided for @adminAddCard.
  ///
  /// In en, this message translates to:
  /// **'Add card'**
  String get adminAddCard;

  /// No description provided for @adminEditCard.
  ///
  /// In en, this message translates to:
  /// **'Edit card'**
  String get adminEditCard;

  /// No description provided for @adminType.
  ///
  /// In en, this message translates to:
  /// **'Card type'**
  String get adminType;

  /// No description provided for @adminTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get adminTitle;

  /// No description provided for @adminSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get adminSubtitle;

  /// No description provided for @adminImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get adminImageUrl;

  /// No description provided for @adminPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get adminPrice;

  /// No description provided for @adminCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get adminCurrency;

  /// No description provided for @adminRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get adminRating;

  /// No description provided for @adminBadge.
  ///
  /// In en, this message translates to:
  /// **'Badge'**
  String get adminBadge;

  /// No description provided for @adminActionLabel.
  ///
  /// In en, this message translates to:
  /// **'Action label'**
  String get adminActionLabel;

  /// No description provided for @adminStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get adminStatus;

  /// No description provided for @adminDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get adminDraft;

  /// No description provided for @adminPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get adminPublished;

  /// No description provided for @adminVisible.
  ///
  /// In en, this message translates to:
  /// **'Visible'**
  String get adminVisible;

  /// No description provided for @adminDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get adminDelete;

  /// No description provided for @adminMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get adminMoveUp;

  /// No description provided for @adminMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get adminMoveDown;

  /// No description provided for @adminSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get adminSave;

  /// No description provided for @adminCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get adminCancel;

  /// No description provided for @adminPreview.
  ///
  /// In en, this message translates to:
  /// **'Live preview'**
  String get adminPreview;

  /// No description provided for @adminHealthCheck.
  ///
  /// In en, this message translates to:
  /// **'Health check'**
  String get adminHealthCheck;

  /// No description provided for @adminLatency.
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get adminLatency;

  /// No description provided for @adminActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminActive;

  /// No description provided for @adminPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get adminPriority;

  /// No description provided for @adminRefreshRegistry.
  ///
  /// In en, this message translates to:
  /// **'Apply changes'**
  String get adminRefreshRegistry;

  /// No description provided for @adminEmpty.
  ///
  /// In en, this message translates to:
  /// **'No content yet. Add your first section.'**
  String get adminEmpty;

  /// No description provided for @adminError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please retry.'**
  String get adminError;

  /// No description provided for @adminRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get adminRetry;

  /// No description provided for @adminLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get adminLoading;

  /// No description provided for @adminSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get adminSaved;

  /// No description provided for @adminFlight.
  ///
  /// In en, this message translates to:
  /// **'Flight'**
  String get adminFlight;

  /// No description provided for @adminHotel.
  ///
  /// In en, this message translates to:
  /// **'Hotel'**
  String get adminHotel;

  /// No description provided for @adminCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get adminCar;

  /// No description provided for @adminPackage.
  ///
  /// In en, this message translates to:
  /// **'Package'**
  String get adminPackage;

  /// No description provided for @adminDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get adminDestination;

  /// No description provided for @adminDeal.
  ///
  /// In en, this message translates to:
  /// **'Deal'**
  String get adminDeal;

  /// No description provided for @adminTabletOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Open the admin panel on a bigger screen'**
  String get adminTabletOnlyTitle;

  /// No description provided for @adminTabletOnlyBody.
  ///
  /// In en, this message translates to:
  /// **'The admin tables need at least 480pt of width. Open TokiGo on a tablet or a desktop browser to manage content and providers.'**
  String get adminTabletOnlyBody;

  /// No description provided for @adminTableSection.
  ///
  /// In en, this message translates to:
  /// **'Section'**
  String get adminTableSection;

  /// No description provided for @adminTableCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get adminTableCards;

  /// No description provided for @adminTableStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get adminTableStatus;

  /// No description provided for @adminTableProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get adminTableProvider;

  /// No description provided for @adminTablePriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get adminTablePriority;

  /// No description provided for @adminTableLatency.
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get adminTableLatency;

  /// No description provided for @adminHealthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get adminHealthy;

  /// No description provided for @adminUnhealthy.
  ///
  /// In en, this message translates to:
  /// **'Unhealthy'**
  String get adminUnhealthy;

  /// No description provided for @adminUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get adminUnknown;

  /// No description provided for @adminFallback.
  ///
  /// In en, this message translates to:
  /// **'Fallback'**
  String get adminFallback;

  /// No description provided for @adminLayout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get adminLayout;

  /// No description provided for @adminPriorityUp.
  ///
  /// In en, this message translates to:
  /// **'Raise priority'**
  String get adminPriorityUp;

  /// No description provided for @adminPriorityDown.
  ///
  /// In en, this message translates to:
  /// **'Lower priority'**
  String get adminPriorityDown;

  /// No description provided for @adminToggleCards.
  ///
  /// In en, this message translates to:
  /// **'Show the section\'s cards'**
  String get adminToggleCards;

  /// No description provided for @adminNoProviders.
  ///
  /// In en, this message translates to:
  /// **'No provider is configured for this vertical yet.'**
  String get adminNoProviders;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsAppLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsAppLanguage;

  /// No description provided for @settingsPreferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsPreferences;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get settingsDangerZone;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @aiMemoryTitle.
  ///
  /// In en, this message translates to:
  /// **'What I Know About You'**
  String get aiMemoryTitle;

  /// No description provided for @aiMemorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Facts you shared in AI chats. You can edit or remove them anytime.'**
  String get aiMemorySubtitle;

  /// No description provided for @aiMemorySignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see and manage what the AI remembers about you.'**
  String get aiMemorySignInPrompt;

  /// No description provided for @aiMemoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet. Facts you share with the AI assistant will appear here.'**
  String get aiMemoryEmpty;

  /// No description provided for @aiMemoryEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get aiMemoryEdit;

  /// No description provided for @aiMemoryDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get aiMemoryDelete;

  /// No description provided for @aiMemoryDeleted.
  ///
  /// In en, this message translates to:
  /// **'Removed.'**
  String get aiMemoryDeleted;

  /// No description provided for @aiMemoryClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get aiMemoryClearAll;

  /// No description provided for @aiMemoryClearAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove every fact listed here? Your profile and travel history are not affected.'**
  String get aiMemoryClearAllConfirm;

  /// No description provided for @aiMemoryClearedAll.
  ///
  /// In en, this message translates to:
  /// **'All facts removed.'**
  String get aiMemoryClearedAll;

  /// No description provided for @aiMemoryFieldDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get aiMemoryFieldDestination;

  /// No description provided for @aiMemoryFieldBudgetMin.
  ///
  /// In en, this message translates to:
  /// **'Minimum budget'**
  String get aiMemoryFieldBudgetMin;

  /// No description provided for @aiMemoryFieldBudgetMax.
  ///
  /// In en, this message translates to:
  /// **'Maximum budget'**
  String get aiMemoryFieldBudgetMax;

  /// No description provided for @aiMemoryFieldBudgetCurrency.
  ///
  /// In en, this message translates to:
  /// **'Budget currency'**
  String get aiMemoryFieldBudgetCurrency;

  /// No description provided for @aiMemoryBudgetCurrencyNone.
  ///
  /// In en, this message translates to:
  /// **'No currency'**
  String get aiMemoryBudgetCurrencyNone;

  /// No description provided for @aiMemoryFieldStyles.
  ///
  /// In en, this message translates to:
  /// **'Travel styles'**
  String get aiMemoryFieldStyles;

  /// No description provided for @aiMemoryFieldStylesHelper.
  ///
  /// In en, this message translates to:
  /// **'Separate styles with commas'**
  String get aiMemoryFieldStylesHelper;

  /// No description provided for @aiMemoryMemoryButton.
  ///
  /// In en, this message translates to:
  /// **'What I Know About You'**
  String get aiMemoryMemoryButton;

  /// No description provided for @voiceSearch.
  ///
  /// In en, this message translates to:
  /// **'Voice search'**
  String get voiceSearch;

  /// No description provided for @voiceStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting voice search…'**
  String get voiceStarting;

  /// No description provided for @voiceStop.
  ///
  /// In en, this message translates to:
  /// **'Stop voice search'**
  String get voiceStop;

  /// No description provided for @voiceErrorPermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is needed for voice search.'**
  String get voiceErrorPermission;

  /// No description provided for @voiceErrorUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice search is not available on this device.'**
  String get voiceErrorUnavailable;

  /// No description provided for @voiceErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t catch that — try speaking again.'**
  String get voiceErrorEmpty;

  /// No description provided for @onboardingHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Next Adventure Awaits'**
  String get onboardingHeroTitle;

  /// No description provided for @onboardingHeroBody.
  ///
  /// In en, this message translates to:
  /// **'Book flights, hotels, and more — all in one place.'**
  String get onboardingHeroBody;

  /// No description provided for @onboardingAiTitle.
  ///
  /// In en, this message translates to:
  /// **'Your AI travel companion'**
  String get onboardingAiTitle;

  /// No description provided for @onboardingAiBody.
  ///
  /// In en, this message translates to:
  /// **'Ask anything: plan a weekend, find cheaper alternatives, compare offers.'**
  String get onboardingAiBody;

  /// No description provided for @onboardingBagTitle.
  ///
  /// In en, this message translates to:
  /// **'All your trips in one bag'**
  String get onboardingBagTitle;

  /// No description provided for @onboardingBagBody.
  ///
  /// In en, this message translates to:
  /// **'Every booking lands in one place — with readiness checks and price watches.'**
  String get onboardingBagBody;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingStartExploring.
  ///
  /// In en, this message translates to:
  /// **'Start exploring'**
  String get onboardingStartExploring;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get onboardingHaveAccount;

  /// No description provided for @onboardingLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get onboardingLogIn;

  /// No description provided for @packagesUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Holidays are coming soon'**
  String get packagesUnavailableTitle;

  /// No description provided for @packagesUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'We are onboarding package providers. Flights and hotels are live today.'**
  String get packagesUnavailableBody;

  /// No description provided for @carsUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Cars Rental is coming soon'**
  String get carsUnavailableTitle;

  /// No description provided for @carsUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'We are onboarding car-rental providers. Flights and hotels are live today.'**
  String get carsUnavailableBody;

  /// No description provided for @findFlights.
  ///
  /// In en, this message translates to:
  /// **'Find flights'**
  String get findFlights;

  /// No description provided for @findHotels.
  ///
  /// In en, this message translates to:
  /// **'Find hotels'**
  String get findHotels;

  /// No description provided for @packagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Curated multi-day programs'**
  String get packagesSubtitle;

  /// No description provided for @carsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Self-drive rental cars'**
  String get carsSubtitle;

  /// No description provided for @carsLiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Rental cars at your destination'**
  String get carsLiveSubtitle;

  /// No description provided for @aiSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get aiSomethingWentWrong;

  /// No description provided for @aiNoSuggestions.
  ///
  /// In en, this message translates to:
  /// **'No suggestions right now. Try a different prompt.'**
  String get aiNoSuggestions;

  /// No description provided for @aiTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get aiTryAgain;

  /// No description provided for @aiSendPrompt.
  ///
  /// In en, this message translates to:
  /// **'Send prompt'**
  String get aiSendPrompt;

  /// No description provided for @aiModeActive.
  ///
  /// In en, this message translates to:
  /// **'AI mode active'**
  String get aiModeActive;

  /// No description provided for @aiTravelCopilot.
  ///
  /// In en, this message translates to:
  /// **'Your travel co-pilot'**
  String get aiTravelCopilot;

  /// No description provided for @viewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get viewList;

  /// No description provided for @viewMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get viewMap;

  /// No description provided for @sortResults.
  ///
  /// In en, this message translates to:
  /// **'Sort results'**
  String get sortResults;

  /// No description provided for @bookingNoSelection.
  ///
  /// In en, this message translates to:
  /// **'No booking selected'**
  String get bookingNoSelection;

  /// No description provided for @bookingStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get bookingStatusTitle;

  /// No description provided for @bookingStepPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing booking'**
  String get bookingStepPreparing;

  /// No description provided for @bookingStepValidatingPrice.
  ///
  /// In en, this message translates to:
  /// **'Validating price'**
  String get bookingStepValidatingPrice;

  /// No description provided for @bookingStepReady.
  ///
  /// In en, this message translates to:
  /// **'Ready to confirm'**
  String get bookingStepReady;

  /// No description provided for @bookingPriceChanged.
  ///
  /// In en, this message translates to:
  /// **'Price changed'**
  String get bookingPriceChanged;

  /// No description provided for @bookingAcceptNewPrice.
  ///
  /// In en, this message translates to:
  /// **'Accept new price'**
  String get bookingAcceptNewPrice;

  /// No description provided for @bookingPrepare.
  ///
  /// In en, this message translates to:
  /// **'Prepare booking'**
  String get bookingPrepare;

  /// No description provided for @bookingValidating.
  ///
  /// In en, this message translates to:
  /// **'Validating…'**
  String get bookingValidating;

  /// No description provided for @bookingValidatePrice.
  ///
  /// In en, this message translates to:
  /// **'Validate price'**
  String get bookingValidatePrice;

  /// No description provided for @bookingConfirming.
  ///
  /// In en, this message translates to:
  /// **'Confirming…'**
  String get bookingConfirming;

  /// No description provided for @bookingViewTrip.
  ///
  /// In en, this message translates to:
  /// **'View my trip'**
  String get bookingViewTrip;

  /// No description provided for @bookingOfferUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This offer is no longer available. Please pick another.'**
  String get bookingOfferUnavailable;

  /// No description provided for @carPickupLocation.
  ///
  /// In en, this message translates to:
  /// **'Pickup location'**
  String get carPickupLocation;

  /// No description provided for @mapViewComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Map view coming soon'**
  String get mapViewComingSoon;

  /// No description provided for @mapIntegrationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Map integration is not yet available. Results are shown in list view.'**
  String get mapIntegrationUnavailable;

  /// No description provided for @carDropoffLocation.
  ///
  /// In en, this message translates to:
  /// **'Dropoff location'**
  String get carDropoffLocation;

  /// No description provided for @carPickupHint.
  ///
  /// In en, this message translates to:
  /// **'Pickup location'**
  String get carPickupHint;

  /// No description provided for @carDropoffHint.
  ///
  /// In en, this message translates to:
  /// **'Dropoff location'**
  String get carDropoffHint;

  /// No description provided for @carPickUpShort.
  ///
  /// In en, this message translates to:
  /// **'Pick-up'**
  String get carPickUpShort;

  /// No description provided for @carDropOffShort.
  ///
  /// In en, this message translates to:
  /// **'Drop-off'**
  String get carDropOffShort;

  /// No description provided for @carSearchCta.
  ///
  /// In en, this message translates to:
  /// **'Search cars'**
  String get carSearchCta;

  /// No description provided for @carFindYourRide.
  ///
  /// In en, this message translates to:
  /// **'Find your ride'**
  String get carFindYourRide;

  /// No description provided for @carNoMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'No matches for your filters'**
  String get carNoMatchesTitle;

  /// No description provided for @carNoCarsTitle.
  ///
  /// In en, this message translates to:
  /// **'No cars found'**
  String get carNoCarsTitle;

  /// No description provided for @carConnectionErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get carConnectionErrorTitle;

  /// No description provided for @bookingAddTraveller.
  ///
  /// In en, this message translates to:
  /// **'Add traveller'**
  String get bookingAddTraveller;

  /// No description provided for @bookingContactInformation.
  ///
  /// In en, this message translates to:
  /// **'Contact information'**
  String get bookingContactInformation;

  /// No description provided for @bookingRemoveTraveller.
  ///
  /// In en, this message translates to:
  /// **'Remove traveller'**
  String get bookingRemoveTraveller;

  /// No description provided for @bookingFirstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get bookingFirstName;

  /// No description provided for @bookingLastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get bookingLastName;

  /// No description provided for @bookingRequiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get bookingRequiredField;

  /// No description provided for @bookingEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get bookingEmailLabel;

  /// No description provided for @bookingPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get bookingPhoneLabel;

  /// No description provided for @bookingValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get bookingValidEmail;

  /// No description provided for @bookingValidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone'**
  String get bookingValidPhone;

  /// No description provided for @groupsCreateTrip.
  ///
  /// In en, this message translates to:
  /// **'Create a group trip'**
  String get groupsCreateTrip;

  /// No description provided for @groupsPlanTogether.
  ///
  /// In en, this message translates to:
  /// **'Plan together, decide together'**
  String get groupsPlanTogether;

  /// No description provided for @carIdleBody.
  ///
  /// In en, this message translates to:
  /// **'Compare car rentals at pickup points worldwide'**
  String get carIdleBody;

  /// No description provided for @carNoMatchesBody.
  ///
  /// In en, this message translates to:
  /// **'Try widening the price range or clearing filters'**
  String get carNoMatchesBody;

  /// No description provided for @carNoCarsBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different location or dates'**
  String get carNoCarsBody;

  /// No description provided for @offlineShowingCached.
  ///
  /// In en, this message translates to:
  /// **'You are offline — showing the last saved data'**
  String get offlineShowingCached;

  /// No description provided for @homeCompleteYourTrip.
  ///
  /// In en, this message translates to:
  /// **'Complete your trip'**
  String get homeCompleteYourTrip;

  /// No description provided for @homeFinishWhatYouStarted.
  ///
  /// In en, this message translates to:
  /// **'Finish what you started'**
  String get homeFinishWhatYouStarted;

  /// No description provided for @homeForYourTripTo.
  ///
  /// In en, this message translates to:
  /// **'For your trip to {destination}'**
  String homeForYourTripTo(Object destination);

  /// No description provided for @homeBecauseYouViewed.
  ///
  /// In en, this message translates to:
  /// **'Because you viewed {title}'**
  String homeBecauseYouViewed(Object title);

  /// No description provided for @homePicksRelatedToWhatYouSaw.
  ///
  /// In en, this message translates to:
  /// **'Picks related to what you saw'**
  String get homePicksRelatedToWhatYouSaw;

  /// No description provided for @homePickedForYou.
  ///
  /// In en, this message translates to:
  /// **'Picked for you'**
  String get homePickedForYou;

  /// No description provided for @homeBasedOnYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Based on your profile'**
  String get homeBasedOnYourProfile;

  /// No description provided for @homeBasedOnRecentSearches.
  ///
  /// In en, this message translates to:
  /// **'Based on your recent searches'**
  String get homeBasedOnRecentSearches;

  /// No description provided for @homeBasedOnWhatYouViewed.
  ///
  /// In en, this message translates to:
  /// **'Based on what you viewed'**
  String get homeBasedOnWhatYouViewed;

  /// No description provided for @homeYourFavoritesFirst.
  ///
  /// In en, this message translates to:
  /// **'Your favourites first'**
  String get homeYourFavoritesFirst;

  /// No description provided for @homeMatchedToYourPreferences.
  ///
  /// In en, this message translates to:
  /// **'Matched to your preferences'**
  String get homeMatchedToYourPreferences;

  /// No description provided for @homeForYourUpcomingTrip.
  ///
  /// In en, this message translates to:
  /// **'For your upcoming trip'**
  String get homeForYourUpcomingTrip;

  /// No description provided for @homePopularNearYou.
  ///
  /// In en, this message translates to:
  /// **'Popular near you'**
  String get homePopularNearYou;

  /// No description provided for @homeBecauseYouViewedThis.
  ///
  /// In en, this message translates to:
  /// **'Because you viewed this'**
  String get homeBecauseYouViewedThis;

  /// No description provided for @tripCancelBooking.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get tripCancelBooking;

  /// No description provided for @tripCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this booking?'**
  String get tripCancelTitle;

  /// No description provided for @tripCancelBody.
  ///
  /// In en, this message translates to:
  /// **'The provider decides whether this booking can be cancelled. If it cannot, it will say why.'**
  String get tripCancelBody;

  /// No description provided for @tripCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get tripCancelConfirm;

  /// No description provided for @tripCancelKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep booking'**
  String get tripCancelKeep;

  /// No description provided for @tripCancelled.
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled'**
  String get tripCancelled;

  /// No description provided for @profileGuestSavedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Saved places'**
  String get profileGuestSavedPlaces;

  /// No description provided for @profileGuestSavedPlacesBody.
  ///
  /// In en, this message translates to:
  /// **'The stays you saved with the heart are on this device — no account needed.'**
  String get profileGuestSavedPlacesBody;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @addOnsProviderTitle.
  ///
  /// In en, this message translates to:
  /// **'Add-ons are priced by the provider'**
  String get addOnsProviderTitle;

  /// No description provided for @addOnsProviderBody.
  ///
  /// In en, this message translates to:
  /// **'Extra bags, seats and meals are sold by the airline for your specific fare. They will appear here with the airline\'s own prices once that feed is connected — we never estimate a price.'**
  String get addOnsProviderBody;

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Booking updates, price alerts and check-in reminders will appear here once they really happen. We don\'t invent them.'**
  String get notificationsEmptyBody;

  /// No description provided for @notificationToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get notificationToday;

  /// No description provided for @notificationEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get notificationEarlier;

  /// No description provided for @notificationUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notificationUnread;

  /// No description provided for @wishlistEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet'**
  String get wishlistEmptyTitle;

  /// No description provided for @wishlistEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on a hotel, flight or package to keep it here. Saved items show the provider\'s own price.'**
  String get wishlistEmptyBody;

  /// No description provided for @wishlistSavedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 saved} other{{count} saved}}'**
  String wishlistSavedCount(int count);

  /// No description provided for @wishlistExploreStays.
  ///
  /// In en, this message translates to:
  /// **'Explore stays'**
  String get wishlistExploreStays;

  /// No description provided for @groupsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Group trips are coming soon'**
  String get groupsEmptyTitle;

  /// No description provided for @groupsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Creating a trip, inviting friends and splitting the plan will open here once the group trips backend is connected.'**
  String get groupsEmptyBody;

  /// No description provided for @exploreCitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Cities for your mood'**
  String get exploreCitiesTitle;

  /// No description provided for @createNewTrip.
  ///
  /// In en, this message translates to:
  /// **'Create a new trip'**
  String get createNewTrip;

  /// No description provided for @tripBuilderTitle.
  ///
  /// In en, this message translates to:
  /// **'Plan your trip'**
  String get tripBuilderTitle;

  /// No description provided for @tripBuilderCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel trip planning'**
  String get tripBuilderCancel;

  /// No description provided for @tripBuilderStartFromHome.
  ///
  /// In en, this message translates to:
  /// **'Start by choosing a city from Home.'**
  String get tripBuilderStartFromHome;

  /// No description provided for @tripBuilderAddProducts.
  ///
  /// In en, this message translates to:
  /// **'Add to your trip'**
  String get tripBuilderAddProducts;

  /// No description provided for @tripBuilderSelected.
  ///
  /// In en, this message translates to:
  /// **'Your trip selections'**
  String get tripBuilderSelected;

  /// No description provided for @tripBuilderEmpty.
  ///
  /// In en, this message translates to:
  /// **'Choose a hotel, flight, or car to add it here.'**
  String get tripBuilderEmpty;

  /// No description provided for @tripBuilderRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from trip'**
  String get tripBuilderRemove;

  /// No description provided for @tripBuilderTotal.
  ///
  /// In en, this message translates to:
  /// **'Current total'**
  String get tripBuilderTotal;

  /// No description provided for @tripBuilderTotalNote.
  ///
  /// In en, this message translates to:
  /// **'This total adds the selected offers. Providers may use different currencies, and each item is booked and paid through its provider.'**
  String get tripBuilderTotalNote;

  /// No description provided for @tripBuilderAddToTrip.
  ///
  /// In en, this message translates to:
  /// **'Add to trip'**
  String get tripBuilderAddToTrip;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No recommendations right now'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'We don\'t have hotels to suggest yet. Search a destination instead — or try again in a moment.'**
  String get homeEmptyBody;

  /// No description provided for @homeErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t reach the travel service'**
  String get homeErrorTitle;

  /// No description provided for @homeErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Your connection or the provider may be having a moment. Nothing is lost — try again.'**
  String get homeErrorBody;

  /// No description provided for @checkoutNoBookingTitle.
  ///
  /// In en, this message translates to:
  /// **'This booking isn\'t ready to pay for'**
  String get checkoutNoBookingTitle;

  /// No description provided for @checkoutNoBookingBody.
  ///
  /// In en, this message translates to:
  /// **'There is no prepared booking for this trip, so there is nothing to charge. Go back to the booking review and prepare it again.'**
  String get checkoutNoBookingBody;

  /// No description provided for @checkoutProviderPrice.
  ///
  /// In en, this message translates to:
  /// **'Trip price (from the provider)'**
  String get checkoutProviderPrice;

  /// No description provided for @paymentFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Your payment was not completed, so nothing was booked and nothing was charged.'**
  String get paymentFailedBody;

  /// No description provided for @paymentUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Payment is not available right now, so nothing was booked. Please try again later.'**
  String get paymentUnavailableBody;

  /// No description provided for @paymentPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Your bank is still verifying this payment. The booking will be confirmed as soon as the payment completes.'**
  String get paymentPendingBody;

  /// No description provided for @bookingConfirmFailedBody.
  ///
  /// In en, this message translates to:
  /// **'The payment was not completed, so the booking was not confirmed. Nothing was booked.'**
  String get bookingConfirmFailedBody;

  /// No description provided for @bookingConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm booking'**
  String get bookingConfirmLabel;

  /// No description provided for @payAmount.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String payAmount(String amount);

  /// No description provided for @confirmationNoneTitle.
  ///
  /// In en, this message translates to:
  /// **'No confirmed booking to show'**
  String get confirmationNoneTitle;

  /// No description provided for @confirmationNoneBody.
  ///
  /// In en, this message translates to:
  /// **'This screen shows the booking the provider actually confirmed. Nothing is confirmed for this trip yet.'**
  String get confirmationNoneBody;

  /// No description provided for @bookingConfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking confirmed'**
  String get bookingConfirmedTitle;

  /// No description provided for @confirmationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep this reference to manage your booking with the provider.'**
  String get confirmationSubtitle;

  /// No description provided for @confirmationCopyReference.
  ///
  /// In en, this message translates to:
  /// **'Copy booking reference'**
  String get confirmationCopyReference;

  /// No description provided for @confirmationCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get confirmationCopied;

  /// No description provided for @confirmationDeparture.
  ///
  /// In en, this message translates to:
  /// **'Departure'**
  String get confirmationDeparture;

  /// No description provided for @confirmationArrival.
  ///
  /// In en, this message translates to:
  /// **'Arrival'**
  String get confirmationArrival;

  /// No description provided for @bookingReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Booking reference'**
  String get bookingReferenceLabel;

  /// No description provided for @bookingStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get bookingStatusConfirmed;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @bookingTravellersLabel.
  ///
  /// In en, this message translates to:
  /// **'Travellers'**
  String get bookingTravellersLabel;

  /// No description provided for @bookingBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get bookingBackHome;

  /// No description provided for @flightSearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search flights across providers'**
  String get flightSearchSubtitle;

  /// No description provided for @tripTypeOneWay.
  ///
  /// In en, this message translates to:
  /// **'One-way'**
  String get tripTypeOneWay;

  /// No description provided for @tripTypeMultiCity.
  ///
  /// In en, this message translates to:
  /// **'Multi-city'**
  String get tripTypeMultiCity;

  /// No description provided for @flightAddLeg.
  ///
  /// In en, this message translates to:
  /// **'Add another leg'**
  String get flightAddLeg;

  /// No description provided for @flightRemoveLeg.
  ///
  /// In en, this message translates to:
  /// **'Remove leg'**
  String get flightRemoveLeg;

  /// No description provided for @flightLegLabel.
  ///
  /// In en, this message translates to:
  /// **'Leg {n}'**
  String flightLegLabel(int n);

  /// No description provided for @flightLegsIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Fill in every leg before searching'**
  String get flightLegsIncomplete;

  /// No description provided for @flightLegsMax.
  ///
  /// In en, this message translates to:
  /// **'A multi-city trip can have up to 6 legs'**
  String get flightLegsMax;

  /// No description provided for @tripTypeRoundTrip.
  ///
  /// In en, this message translates to:
  /// **'Round-trip'**
  String get tripTypeRoundTrip;

  /// No description provided for @fieldFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fieldFrom;

  /// No description provided for @fieldTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get fieldTo;

  /// No description provided for @fieldDeparture.
  ///
  /// In en, this message translates to:
  /// **'Departure'**
  String get fieldDeparture;

  /// No description provided for @fieldReturn.
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get fieldReturn;

  /// No description provided for @selectAirport.
  ///
  /// In en, this message translates to:
  /// **'Select airport'**
  String get selectAirport;

  /// No description provided for @selectAction.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get selectAction;

  /// No description provided for @pickDateHint.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get pickDateHint;

  /// No description provided for @swapRoute.
  ///
  /// In en, this message translates to:
  /// **'Swap origin and destination'**
  String get swapRoute;

  /// No description provided for @cabinEconomy.
  ///
  /// In en, this message translates to:
  /// **'Economy'**
  String get cabinEconomy;

  /// No description provided for @passengersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 passenger} other{{count} passengers}}'**
  String passengersCount(int count);

  /// No description provided for @sortRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get sortRecommended;

  /// No description provided for @sortCheapest.
  ///
  /// In en, this message translates to:
  /// **'Cheapest'**
  String get sortCheapest;

  /// No description provided for @sortFastest.
  ///
  /// In en, this message translates to:
  /// **'Fastest'**
  String get sortFastest;

  /// No description provided for @sortLongest.
  ///
  /// In en, this message translates to:
  /// **'Longest'**
  String get sortLongest;

  /// No description provided for @filtersAction.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filtersAction;

  /// No description provided for @filtersReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get filtersReset;

  /// No description provided for @filtersApply.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get filtersApply;

  /// No description provided for @filterPriceRange.
  ///
  /// In en, this message translates to:
  /// **'Price range'**
  String get filterPriceRange;

  /// No description provided for @filterHotelClass.
  ///
  /// In en, this message translates to:
  /// **'Hotel class'**
  String get filterHotelClass;

  /// No description provided for @filterGuestScore.
  ///
  /// In en, this message translates to:
  /// **'Guest score'**
  String get filterGuestScore;

  /// No description provided for @filterStops.
  ///
  /// In en, this message translates to:
  /// **'Stops'**
  String get filterStops;

  /// No description provided for @filterDirect.
  ///
  /// In en, this message translates to:
  /// **'Direct'**
  String get filterDirect;

  /// No description provided for @filterAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get filterAny;

  /// No description provided for @filterAirlines.
  ///
  /// In en, this message translates to:
  /// **'Airlines'**
  String get filterAirlines;

  /// No description provided for @flightIdleTitle.
  ///
  /// In en, this message translates to:
  /// **'Find your flight'**
  String get flightIdleTitle;

  /// No description provided for @flightIdleBody.
  ///
  /// In en, this message translates to:
  /// **'Compare fares across airlines for your next trip'**
  String get flightIdleBody;

  /// No description provided for @flightEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No flights found'**
  String get flightEmptyTitle;

  /// No description provided for @flightEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try different dates or nearby airports'**
  String get flightEmptyBody;

  /// No description provided for @searchFilteredEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No matches for your filters'**
  String get searchFilteredEmptyTitle;

  /// No description provided for @searchBudgetCap.
  ///
  /// In en, this message translates to:
  /// **'Up to {amount} {currency}'**
  String searchBudgetCap(Object amount, Object currency);

  /// No description provided for @searchBudgetNoCurrency.
  ///
  /// In en, this message translates to:
  /// **'Budget {amount} has no currency — not applied'**
  String searchBudgetNoCurrency(Object amount);

  /// No description provided for @searchBudgetRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove the budget filter'**
  String get searchBudgetRemove;

  /// No description provided for @searchBudgetApply.
  ///
  /// In en, this message translates to:
  /// **'Apply the budget filter'**
  String get searchBudgetApply;

  /// No description provided for @searchBudgetNotApplicable.
  ///
  /// In en, this message translates to:
  /// **'Budget not applied — the listed prices are in {currency}'**
  String searchBudgetNotApplicable(Object currency);

  /// No description provided for @searchFilteredEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try widening the price range or clearing filters'**
  String get searchFilteredEmptyBody;

  /// No description provided for @searchErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection error'**
  String get searchErrorTitle;

  /// No description provided for @searchErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get searchErrorBody;

  /// No description provided for @pickerFromTitle.
  ///
  /// In en, this message translates to:
  /// **'From where?'**
  String get pickerFromTitle;

  /// No description provided for @pickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get pickerSearchHint;

  /// No description provided for @pickerNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get pickerNoMatches;

  /// No description provided for @flightRouteRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose where you are flying from and to first.'**
  String get flightRouteRequired;

  /// No description provided for @hotelDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get hotelDestination;

  /// No description provided for @hotelIdleTitle.
  ///
  /// In en, this message translates to:
  /// **'Find your perfect stay'**
  String get hotelIdleTitle;

  /// No description provided for @hotelIdleBody.
  ///
  /// In en, this message translates to:
  /// **'Enter a destination and your dates to see available rooms.'**
  String get hotelIdleBody;

  /// No description provided for @hotelEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No hotels found'**
  String get hotelEmptyTitle;

  /// No description provided for @hotelEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different destination or dates'**
  String get hotelEmptyBody;

  /// No description provided for @hotelDestinationRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a destination first.'**
  String get hotelDestinationRequired;

  /// No description provided for @hotelSortTopRated.
  ///
  /// In en, this message translates to:
  /// **'Top rated'**
  String get hotelSortTopRated;

  /// No description provided for @hotelRatingAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get hotelRatingAll;

  /// No description provided for @hotelLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading hotel'**
  String get hotelLoading;

  /// No description provided for @hotelFreeCancellation.
  ///
  /// In en, this message translates to:
  /// **'Free cancellation'**
  String get hotelFreeCancellation;

  /// No description provided for @hotelNightsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 night} other{{count} nights}}'**
  String hotelNightsCount(int count);

  /// No description provided for @hotelGuestsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 guest} other{{count} guests}}'**
  String hotelGuestsCount(int count);

  /// No description provided for @hotelRoomsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 room} other{{count} rooms}}'**
  String hotelRoomsCount(int count);

  /// No description provided for @cityStaysCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stay} other{{count} stays}}'**
  String cityStaysCount(num count);

  /// No description provided for @discoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discoverTitle;

  /// No description provided for @discoverMore.
  ///
  /// In en, this message translates to:
  /// **'Discover more'**
  String get discoverMore;

  /// No description provided for @hotelResultsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 stay} other{{count} stays}}'**
  String hotelResultsCount(int count);

  /// No description provided for @editSearch.
  ///
  /// In en, this message translates to:
  /// **'Edit search'**
  String get editSearch;

  /// No description provided for @hotelStarClass.
  ///
  /// In en, this message translates to:
  /// **'{count} star hotels'**
  String hotelStarClass(Object count);

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @hotelRatingSemantics.
  ///
  /// In en, this message translates to:
  /// **'{rating} stars, {count} reviews'**
  String hotelRatingSemantics(Object rating, Object count);

  /// No description provided for @unitNight.
  ///
  /// In en, this message translates to:
  /// **'night'**
  String get unitNight;

  /// No description provided for @unitDay.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get unitDay;

  /// No description provided for @unitPerson.
  ///
  /// In en, this message translates to:
  /// **'person'**
  String get unitPerson;

  /// No description provided for @cardTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'total'**
  String get cardTotalLabel;

  /// No description provided for @cardFromLabel.
  ///
  /// In en, this message translates to:
  /// **'from'**
  String get cardFromLabel;

  /// No description provided for @cardSaveLabel.
  ///
  /// In en, this message translates to:
  /// **'Save {amount}'**
  String cardSaveLabel(Object amount);

  /// No description provided for @cardTaxesIncludedLabel.
  ///
  /// In en, this message translates to:
  /// **'Taxes included'**
  String get cardTaxesIncludedLabel;

  /// No description provided for @cardTaxesExtraLabel.
  ///
  /// In en, this message translates to:
  /// **'Taxes extra'**
  String get cardTaxesExtraLabel;

  /// No description provided for @cardPerUnitSemantics.
  ///
  /// In en, this message translates to:
  /// **'Per {unit} {amount} {currency}'**
  String cardPerUnitSemantics(Object unit, Object amount, Object currency);

  /// No description provided for @cardPerUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'/{unit}'**
  String cardPerUnitLabel(Object unit);

  /// No description provided for @cardTotalSemantics.
  ///
  /// In en, this message translates to:
  /// **'Total {amount} {currency}'**
  String cardTotalSemantics(Object amount, Object currency);

  /// No description provided for @offerAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get offerAbout;

  /// No description provided for @offerAmenities.
  ///
  /// In en, this message translates to:
  /// **'Amenities'**
  String get offerAmenities;

  /// No description provided for @offerAircraft.
  ///
  /// In en, this message translates to:
  /// **'Aircraft'**
  String get offerAircraft;

  /// No description provided for @offerBaggage.
  ///
  /// In en, this message translates to:
  /// **'Baggage'**
  String get offerBaggage;

  /// No description provided for @offerBoard.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get offerBoard;

  /// No description provided for @offerCabin.
  ///
  /// In en, this message translates to:
  /// **'Cabin'**
  String get offerCabin;

  /// No description provided for @offerCancellation.
  ///
  /// In en, this message translates to:
  /// **'Cancellation policy'**
  String get offerCancellation;

  /// No description provided for @offerCarType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get offerCarType;

  /// No description provided for @offerCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check-in'**
  String get offerCheckIn;

  /// No description provided for @offerCheckOut.
  ///
  /// In en, this message translates to:
  /// **'Check-out'**
  String get offerCheckOut;

  /// No description provided for @offerDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get offerDestination;

  /// No description provided for @offerDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get offerDuration;

  /// No description provided for @offerFare.
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get offerFare;

  /// No description provided for @offerFeatures.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get offerFeatures;

  /// No description provided for @offerInclusions.
  ///
  /// In en, this message translates to:
  /// **'Inclusions'**
  String get offerInclusions;

  /// No description provided for @offerMileage.
  ///
  /// In en, this message translates to:
  /// **'Mileage'**
  String get offerMileage;

  /// No description provided for @offerNonRefundableRate.
  ///
  /// In en, this message translates to:
  /// **'Non-refundable rate'**
  String get offerNonRefundableRate;

  /// No description provided for @offerPickup.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get offerPickup;

  /// No description provided for @offerDropOff.
  ///
  /// In en, this message translates to:
  /// **'Drop-off'**
  String get offerDropOff;

  /// No description provided for @offerPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get offerPrice;

  /// No description provided for @offerPriceNote.
  ///
  /// In en, this message translates to:
  /// **'This is the provider\'s own total. We add nothing to it.'**
  String get offerPriceNote;

  /// No description provided for @offerProvider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get offerProvider;

  /// No description provided for @offerRating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get offerRating;

  /// No description provided for @offerRefundable.
  ///
  /// In en, this message translates to:
  /// **'Refundable'**
  String get offerRefundable;

  /// No description provided for @offerRefundableRate.
  ///
  /// In en, this message translates to:
  /// **'Refundable rate'**
  String get offerRefundableRate;

  /// No description provided for @offerRefundableYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get offerRefundableYes;

  /// No description provided for @offerRevalidated.
  ///
  /// In en, this message translates to:
  /// **'Revalidated at booking'**
  String get offerRevalidated;

  /// No description provided for @offerRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get offerRoom;

  /// No description provided for @offerSeats.
  ///
  /// In en, this message translates to:
  /// **'Seats'**
  String get offerSeats;

  /// No description provided for @offerStars.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get offerStars;

  /// No description provided for @offerTaxesFees.
  ///
  /// In en, this message translates to:
  /// **'Taxes & fees'**
  String get offerTaxesFees;

  /// No description provided for @offerTotalFromProvider.
  ///
  /// In en, this message translates to:
  /// **'Total (from the provider)'**
  String get offerTotalFromProvider;

  /// No description provided for @offerTransmission.
  ///
  /// In en, this message translates to:
  /// **'Transmission'**
  String get offerTransmission;

  /// No description provided for @offerBadgeCheapest.
  ///
  /// In en, this message translates to:
  /// **'Cheapest'**
  String get offerBadgeCheapest;

  /// No description provided for @offerBadgeFastest.
  ///
  /// In en, this message translates to:
  /// **'Fastest'**
  String get offerBadgeFastest;

  /// No description provided for @offerBadgeBestValue.
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get offerBadgeBestValue;

  /// No description provided for @offerWarningSelfTransfer.
  ///
  /// In en, this message translates to:
  /// **'Self-transfer'**
  String get offerWarningSelfTransfer;

  /// No description provided for @offerWarningAirportChange.
  ///
  /// In en, this message translates to:
  /// **'Airport change'**
  String get offerWarningAirportChange;

  /// No description provided for @offerWarningRiskyConnection.
  ///
  /// In en, this message translates to:
  /// **'Risky connection'**
  String get offerWarningRiskyConnection;

  /// No description provided for @offerWarningOvernight.
  ///
  /// In en, this message translates to:
  /// **'Overnight'**
  String get offerWarningOvernight;

  /// No description provided for @offerWarningLongLayover.
  ///
  /// In en, this message translates to:
  /// **'Long layover'**
  String get offerWarningLongLayover;

  /// No description provided for @offerLoadingFlight.
  ///
  /// In en, this message translates to:
  /// **'Loading flight'**
  String get offerLoadingFlight;

  /// No description provided for @offerSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get offerSaved;

  /// No description provided for @offerTaxesIncluded.
  ///
  /// In en, this message translates to:
  /// **'(included in price)'**
  String get offerTaxesIncluded;

  /// No description provided for @offerReviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 review} other{{count} reviews}}'**
  String offerReviewsCount(int count);

  /// No description provided for @offerPerNightStated.
  ///
  /// In en, this message translates to:
  /// **'the provider\'s own rate'**
  String get offerPerNightStated;

  /// No description provided for @offerPerNightDerived.
  ///
  /// In en, this message translates to:
  /// **'provider total ÷ {nights}'**
  String offerPerNightDerived(Object nights);

  /// No description provided for @offerCheckAvailability.
  ///
  /// In en, this message translates to:
  /// **'Check availability'**
  String get offerCheckAvailability;

  /// No description provided for @offerDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String offerDays(int count);

  /// No description provided for @offerStopsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Non-stop} =1{1 stop} other{{count} stops}}'**
  String offerStopsCount(int count);

  /// No description provided for @offerStopsWithAirport.
  ///
  /// In en, this message translates to:
  /// **'1 stop ({airport})'**
  String offerStopsWithAirport(Object airport);

  /// No description provided for @offerLayover.
  ///
  /// In en, this message translates to:
  /// **'{duration} layover'**
  String offerLayover(Object duration);

  /// No description provided for @offerSeatsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Only 1 seat left} other{Only {count} seats left}}'**
  String offerSeatsLeft(int count);

  /// No description provided for @offerCardTotal.
  ///
  /// In en, this message translates to:
  /// **'total {amount}'**
  String offerCardTotal(Object amount);

  /// No description provided for @offerFreeCancellationUntil.
  ///
  /// In en, this message translates to:
  /// **'Free cancellation until {date}'**
  String offerFreeCancellationUntil(Object date);

  /// No description provided for @offerCancellationFeeNote.
  ///
  /// In en, this message translates to:
  /// **'Cancellation fee after that: {fee}'**
  String offerCancellationFeeNote(Object fee);

  /// No description provided for @offerSemanticsFlightRoute.
  ///
  /// In en, this message translates to:
  /// **'Flight from {origin} to {destination}'**
  String offerSemanticsFlightRoute(Object origin, Object destination);

  /// No description provided for @offerSemanticsFlightNumber.
  ///
  /// In en, this message translates to:
  /// **'Flight {number}'**
  String offerSemanticsFlightNumber(Object number);

  /// No description provided for @offerSemanticsDeparts.
  ///
  /// In en, this message translates to:
  /// **'Departs at {time}'**
  String offerSemanticsDeparts(Object time);

  /// No description provided for @offerSemanticsArrives.
  ///
  /// In en, this message translates to:
  /// **'Arrives at {time}'**
  String offerSemanticsArrives(Object time);

  /// No description provided for @offerSemanticsDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration {duration}'**
  String offerSemanticsDuration(Object duration);

  /// No description provided for @offerSemanticsPrice.
  ///
  /// In en, this message translates to:
  /// **'Price {amount}'**
  String offerSemanticsPrice(Object amount);

  /// No description provided for @offerSemanticsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total {amount}'**
  String offerSemanticsTotal(Object amount);

  /// No description provided for @locationPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Use your location for the right departure airport'**
  String get locationPromptTitle;

  /// No description provided for @locationPromptBody.
  ///
  /// In en, this message translates to:
  /// **'We read your country once to suggest a departure airport. Your precise location is not saved in the app.'**
  String get locationPromptBody;

  /// No description provided for @locationPromptAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow location'**
  String get locationPromptAllow;

  /// No description provided for @locationPromptNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get locationPromptNotNow;

  /// No description provided for @locationPromptBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Location is blocked'**
  String get locationPromptBlockedTitle;

  /// No description provided for @locationPromptBlockedBody.
  ///
  /// In en, this message translates to:
  /// **'Allow location for TokiGo in the system settings to suggest your departure airport.'**
  String get locationPromptBlockedBody;

  /// No description provided for @locationPromptOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get locationPromptOpenSettings;

  /// No description provided for @locationPromptServiceOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Location services are off'**
  String get locationPromptServiceOffTitle;

  /// No description provided for @locationPromptServiceOffBody.
  ///
  /// In en, this message translates to:
  /// **'Turn on location services to suggest your departure airport.'**
  String get locationPromptServiceOffBody;

  /// No description provided for @locationPromptLocationSettings.
  ///
  /// In en, this message translates to:
  /// **'Location settings'**
  String get locationPromptLocationSettings;

  /// No description provided for @locationChooseCountry.
  ///
  /// In en, this message translates to:
  /// **'Choose country manually'**
  String get locationChooseCountry;

  /// No description provided for @locationCountrySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your country. Please try again.'**
  String get locationCountrySaveFailed;

  /// No description provided for @settingsCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get settingsCountry;

  /// No description provided for @settingsCountryNotSet.
  ///
  /// In en, this message translates to:
  /// **'Choose a country'**
  String get settingsCountryNotSet;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
