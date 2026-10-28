// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TokiGo';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navGroups => 'Groups';

  @override
  String get navExplore => 'Explore';

  @override
  String get navAi => 'AI Assistant';

  @override
  String get bag => 'My Trips';

  @override
  String get notifications => 'Notifications';

  @override
  String get profile => 'Profile';

  @override
  String get profileGuestTitle => 'You\'re browsing as a guest';

  @override
  String get profileGuestBody =>
      'Sign in to keep your trips, saved places and preferences.';

  @override
  String get profileTraveller => 'Traveller';

  @override
  String get profileErrorTitle => 'We couldn\'t load your account';

  @override
  String get back => 'Back';

  @override
  String get searchHint => 'Where to?';

  @override
  String get aiSearchHint => 'Where do you want to go?';

  @override
  String get aiSend => 'Send';

  @override
  String get aiOpenChat => 'Open TokiGo AI';

  @override
  String get aiHintPhrase1 => 'Ask Toki AI — Your Travel Assistant';

  @override
  String get aiHintPhrase2 => 'Where do you want to go?';

  @override
  String get aiHintPhrase3 => 'Hotels in Istanbul? Flights to Cairo?';

  @override
  String get aiSearchSheetHint => 'Where do you want to go?';

  @override
  String get aiSearchNoSuggestions =>
      'No suggestions right now. Try a different prompt.';

  @override
  String get aiSearchError => 'Something went wrong. Please try again.';

  @override
  String get aiSearchSuggestions => 'Suggestions';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String get clearAll => 'Clear all';

  @override
  String get aiSearchEditQuery => 'Edit';

  @override
  String aiSearchResultsFor(Object query) {
    return 'Results for \"$query\"';
  }

  @override
  String get aiSearchPersonalizedHint => 'Ordered by your preferences';

  @override
  String get aiSearchSort => 'Sort';

  @override
  String get aiSearchSortRecommended => 'Recommended';

  @override
  String get aiSearchSortPriceLow => 'Price: Low to High';

  @override
  String get aiSearchSortPriceHigh => 'Price: High to Low';

  @override
  String get aiSearchSortRating => 'Rating';

  @override
  String get aiSearchRefine => 'Refine';

  @override
  String get aiSearchRefineClear => 'Clear filters';

  @override
  String get aiSearchRefineTitle => 'Refine results';

  @override
  String get aiSearchApply => 'Apply';

  @override
  String get aiSearchFilterPriceMax => 'Max price';

  @override
  String get aiSearchFilterMinStars => 'Min stars';

  @override
  String get aiSearchFilterMaxStops => 'Max stops';

  @override
  String get aiSearchFilterMinSeats => 'Min seats';

  @override
  String get aiSearchFilterAny => 'Any';

  @override
  String get aiSearchCompare => 'Compare';

  @override
  String get aiSearchCompareMode => 'Select 2–3 to compare';

  @override
  String aiSearchCompareOpen(Object count) {
    return 'Compare ($count)';
  }

  @override
  String get aiSearchCompareTitle => 'Comparison';

  @override
  String get aiSearchCompareCancel => 'Cancel';

  @override
  String get aiSearchCompareSameType =>
      'Pick products of the same type to compare.';

  @override
  String get aiSearchCompareMissing => '—';

  @override
  String get cmpPrice => 'Price';

  @override
  String get cmpStars => 'Stars';

  @override
  String get cmpRating => 'Rating';

  @override
  String get cmpLocation => 'Location';

  @override
  String get cmpAmenities => 'Amenities';

  @override
  String get cmpCancellation => 'Cancellation';

  @override
  String get cmpAirline => 'Airline';

  @override
  String get cmpDuration => 'Duration';

  @override
  String get cmpStops => 'Stops';

  @override
  String get cmpBaggage => 'Baggage';

  @override
  String get cmpDeparture => 'Departure';

  @override
  String get cmpArrival => 'Arrival';

  @override
  String get cmpCategory => 'Category';

  @override
  String get cmpSeats => 'Seats';

  @override
  String get cmpBags => 'Bags';

  @override
  String get cmpTransmission => 'Transmission';

  @override
  String get cmpMileage => 'Mileage';

  @override
  String get cmpDestination => 'Destination';

  @override
  String get cmpInclusions => 'Inclusions';

  @override
  String get searchPromptTitle => 'Where to next?';

  @override
  String get searchPromptSubtitle =>
      'Plan a city break, beach escape or weekend getaway.';

  @override
  String get searchAllServices => 'All services';

  @override
  String homeHelloName(Object name) {
    return 'Hello, $name';
  }

  @override
  String get homeStaysTitle => 'Hotels recommended';

  @override
  String get homeContinuePlanning => 'Continue planning';

  @override
  String get homeWelcome => 'Welcome back';

  @override
  String get homeWelcomeSub => 'Trips and ideas picked for you';

  @override
  String get searchFlights => 'Flights';

  @override
  String get searchHotels => 'Hotels';

  @override
  String get searchCars => 'Cars Rental';

  @override
  String get searchPackages => 'Holidays';

  @override
  String get homeNavActivities => 'Activities';

  @override
  String get searchTransfers => 'Airport transfer';

  @override
  String get groupsTitle => 'Groups';

  @override
  String get groupsSubtitle => 'Plan together, travel together';

  @override
  String get viewAll => 'View all';

  @override
  String get continueAsGuest => 'Continue as guest';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get currency => 'Currency';

  @override
  String get wishlist => 'Wishlist';

  @override
  String get myTrips => 'My trips';

  @override
  String get tripDetails => 'Trip details';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get past => 'Past';

  @override
  String get tripsEmptyUpcomingTitle => 'No upcoming trips yet';

  @override
  String get tripsEmptyCancelledTitle => 'No cancelled bookings';

  @override
  String get tripsEmptyPastTitle => 'No past trips yet';

  @override
  String get tripsEmptyBody =>
      'Your confirmed bookings appear here automatically.';

  @override
  String tripTravellersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count travellers',
      one: '1 traveller',
    );
    return '$_temp0';
  }

  @override
  String get tripNotFoundTitle => 'Trip not found';

  @override
  String get tripNotFoundBody =>
      'This trip isn\'t in My Trips. Trips appear here once a booking is confirmed in the app.';

  @override
  String get tripStatusPending => 'Pending';

  @override
  String get tripStatusCancelled => 'Cancelled';

  @override
  String get tripStatusFailed => 'Failed';

  @override
  String get tripStatusDraft => 'Draft';

  @override
  String get tripTypeHotel => 'Hotel';

  @override
  String get tripTypeFlight => 'Flight';

  @override
  String get tripTypeCar => 'Car';

  @override
  String get tripTypePackage => 'Package';

  @override
  String get tripTypeBooking => 'Booking';

  @override
  String get readyToBook => 'Ready to book?';

  @override
  String get reviewBooking => 'Review booking';

  @override
  String get passengerDetails => 'Passenger details';

  @override
  String get addOns => 'Add-ons';

  @override
  String bookingStepOf(String current, String total) {
    return 'Step $current of $total';
  }

  @override
  String get checkoutPaymentMethod => 'Payment method';

  @override
  String get checkoutCard => 'Credit / debit card';

  @override
  String get checkoutWallet => 'Digital wallet';

  @override
  String get checkoutCardDetails => 'Card details';

  @override
  String get checkoutPriceBreakdown => 'Price breakdown';

  @override
  String get checkoutProcessing => 'Processing payment…';

  @override
  String get payment => 'Payment';

  @override
  String get confirmation => 'Confirmation';

  @override
  String get bookNow => 'Book now';

  @override
  String get total => 'Total';

  @override
  String get continueAction => 'Continue';

  @override
  String get adminPanel => 'Admin panel';

  @override
  String get adminContent => 'Home content';

  @override
  String get adminProviders => 'API providers';

  @override
  String get adminAddSection => 'Add section';

  @override
  String get adminAddCard => 'Add card';

  @override
  String get adminEditCard => 'Edit card';

  @override
  String get adminType => 'Card type';

  @override
  String get adminTitle => 'Title';

  @override
  String get adminSubtitle => 'Subtitle';

  @override
  String get adminImageUrl => 'Image URL';

  @override
  String get adminPrice => 'Price';

  @override
  String get adminCurrency => 'Currency';

  @override
  String get adminRating => 'Rating';

  @override
  String get adminBadge => 'Badge';

  @override
  String get adminActionLabel => 'Action label';

  @override
  String get adminStatus => 'Status';

  @override
  String get adminDraft => 'Draft';

  @override
  String get adminPublished => 'Published';

  @override
  String get adminVisible => 'Visible';

  @override
  String get adminDelete => 'Delete';

  @override
  String get adminMoveUp => 'Move up';

  @override
  String get adminMoveDown => 'Move down';

  @override
  String get adminSave => 'Save';

  @override
  String get adminCancel => 'Cancel';

  @override
  String get adminPreview => 'Live preview';

  @override
  String get adminHealthCheck => 'Health check';

  @override
  String get adminLatency => 'Latency';

  @override
  String get adminActive => 'Active';

  @override
  String get adminPriority => 'Priority';

  @override
  String get adminRefreshRegistry => 'Apply changes';

  @override
  String get adminEmpty => 'No content yet. Add your first section.';

  @override
  String get adminError => 'Something went wrong. Please retry.';

  @override
  String get adminRetry => 'Retry';

  @override
  String get adminLoading => 'Loading…';

  @override
  String get adminSaved => 'Saved';

  @override
  String get adminFlight => 'Flight';

  @override
  String get adminHotel => 'Hotel';

  @override
  String get adminCar => 'Car';

  @override
  String get adminPackage => 'Package';

  @override
  String get adminDestination => 'Destination';

  @override
  String get adminDeal => 'Deal';

  @override
  String get adminTabletOnlyTitle => 'Open the admin panel on a bigger screen';

  @override
  String get adminTabletOnlyBody =>
      'The admin tables need at least 480pt of width. Open TokiGo on a tablet or a desktop browser to manage content and providers.';

  @override
  String get adminTableSection => 'Section';

  @override
  String get adminTableCards => 'Cards';

  @override
  String get adminTableStatus => 'Status';

  @override
  String get adminTableProvider => 'Provider';

  @override
  String get adminTablePriority => 'Priority';

  @override
  String get adminTableLatency => 'Latency';

  @override
  String get adminHealthy => 'Healthy';

  @override
  String get adminUnhealthy => 'Unhealthy';

  @override
  String get adminUnknown => 'Unknown';

  @override
  String get adminFallback => 'Fallback';

  @override
  String get adminLayout => 'Layout';

  @override
  String get adminPriorityUp => 'Raise priority';

  @override
  String get adminPriorityDown => 'Lower priority';

  @override
  String get adminToggleCards => 'Show the section\'s cards';

  @override
  String get adminNoProviders =>
      'No provider is configured for this vertical yet.';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsAppLanguage => 'App language';

  @override
  String get settingsPreferences => 'Preferences';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsDangerZone => 'Danger zone';

  @override
  String get settingsVersion => 'Version';

  @override
  String get aiMemoryTitle => 'What I Know About You';

  @override
  String get aiMemorySubtitle =>
      'Facts you shared in AI chats. You can edit or remove them anytime.';

  @override
  String get aiMemorySignInPrompt =>
      'Sign in to see and manage what the AI remembers about you.';

  @override
  String get aiMemoryEmpty =>
      'Nothing yet. Facts you share with the AI assistant will appear here.';

  @override
  String get aiMemoryEdit => 'Edit';

  @override
  String get aiMemoryDelete => 'Delete';

  @override
  String get aiMemoryDeleted => 'Removed.';

  @override
  String get aiMemoryClearAll => 'Clear all';

  @override
  String get aiMemoryClearAllConfirm =>
      'Remove every fact listed here? Your profile and travel history are not affected.';

  @override
  String get aiMemoryClearedAll => 'All facts removed.';

  @override
  String get aiMemoryFieldDestination => 'Destination';

  @override
  String get aiMemoryFieldBudgetMin => 'Minimum budget';

  @override
  String get aiMemoryFieldBudgetMax => 'Maximum budget';

  @override
  String get aiMemoryFieldBudgetCurrency => 'Budget currency';

  @override
  String get aiMemoryBudgetCurrencyNone => 'No currency';

  @override
  String get aiMemoryFieldStyles => 'Travel styles';

  @override
  String get aiMemoryFieldStylesHelper => 'Separate styles with commas';

  @override
  String get aiMemoryMemoryButton => 'What I Know About You';

  @override
  String get voiceSearch => 'Voice search';

  @override
  String get voiceStarting => 'Starting voice search…';

  @override
  String get voiceStop => 'Stop voice search';

  @override
  String get voiceErrorPermission =>
      'Microphone permission is needed for voice search.';

  @override
  String get voiceErrorUnavailable =>
      'Voice search is not available on this device.';

  @override
  String get voiceErrorEmpty => 'Didn\'t catch that — try speaking again.';

  @override
  String get onboardingHeroTitle => 'Your Next Adventure Awaits';

  @override
  String get onboardingHeroBody =>
      'Book flights, hotels, and more — all in one place.';

  @override
  String get onboardingAiTitle => 'Your AI travel companion';

  @override
  String get onboardingAiBody =>
      'Ask anything: plan a weekend, find cheaper alternatives, compare offers.';

  @override
  String get onboardingBagTitle => 'All your trips in one bag';

  @override
  String get onboardingBagBody =>
      'Every booking lands in one place — with readiness checks and price watches.';

  @override
  String get onboardingGetStarted => 'Get started';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStartExploring => 'Start exploring';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingHaveAccount => 'Already have an account?';

  @override
  String get onboardingLogIn => 'Log in';

  @override
  String get packagesUnavailableTitle => 'Holidays are coming soon';

  @override
  String get packagesUnavailableBody =>
      'We are onboarding package providers. Flights and hotels are live today.';

  @override
  String get carsUnavailableTitle => 'Cars Rental is coming soon';

  @override
  String get carsUnavailableBody =>
      'We are onboarding car-rental providers. Flights and hotels are live today.';

  @override
  String get findFlights => 'Find flights';

  @override
  String get findHotels => 'Find hotels';

  @override
  String get packagesSubtitle => 'Curated multi-day programs';

  @override
  String get carsSubtitle => 'Self-drive rental cars';

  @override
  String get carsLiveSubtitle => 'Rental cars at your destination';

  @override
  String get aiSomethingWentWrong => 'Something went wrong. Please try again.';

  @override
  String get aiNoSuggestions =>
      'No suggestions right now. Try a different prompt.';

  @override
  String get aiTryAgain => 'Try again';

  @override
  String get aiSendPrompt => 'Send prompt';

  @override
  String get aiModeActive => 'AI mode active';

  @override
  String get aiTravelCopilot => 'Your travel co-pilot';

  @override
  String get viewList => 'List';

  @override
  String get viewMap => 'Map';

  @override
  String get sortResults => 'Sort results';

  @override
  String get bookingNoSelection => 'No booking selected';

  @override
  String get bookingStatusTitle => 'Status';

  @override
  String get bookingStepPreparing => 'Preparing booking';

  @override
  String get bookingStepValidatingPrice => 'Validating price';

  @override
  String get bookingStepReady => 'Ready to confirm';

  @override
  String get bookingPriceChanged => 'Price changed';

  @override
  String get bookingAcceptNewPrice => 'Accept new price';

  @override
  String get bookingPrepare => 'Prepare booking';

  @override
  String get bookingValidating => 'Validating…';

  @override
  String get bookingValidatePrice => 'Validate price';

  @override
  String get bookingConfirming => 'Confirming…';

  @override
  String get bookingViewTrip => 'View my trip';

  @override
  String get bookingOfferUnavailable =>
      'This offer is no longer available. Please pick another.';

  @override
  String get carPickupLocation => 'Pickup location';

  @override
  String get mapViewComingSoon => 'Map view coming soon';

  @override
  String get mapIntegrationUnavailable =>
      'Map integration is not yet available. Results are shown in list view.';

  @override
  String get carDropoffLocation => 'Dropoff location';

  @override
  String get carPickupHint => 'Pickup location';

  @override
  String get carDropoffHint => 'Dropoff location';

  @override
  String get carPickUpShort => 'Pick-up';

  @override
  String get carDropOffShort => 'Drop-off';

  @override
  String get carSearchCta => 'Search cars';

  @override
  String get carFindYourRide => 'Find your ride';

  @override
  String get carNoMatchesTitle => 'No matches for your filters';

  @override
  String get carNoCarsTitle => 'No cars found';

  @override
  String get carConnectionErrorTitle => 'Connection error';

  @override
  String get bookingAddTraveller => 'Add traveller';

  @override
  String get bookingContactInformation => 'Contact information';

  @override
  String get bookingRemoveTraveller => 'Remove traveller';

  @override
  String get bookingFirstName => 'First name';

  @override
  String get bookingLastName => 'Last name';

  @override
  String get bookingRequiredField => 'Required';

  @override
  String get bookingEmailLabel => 'Email';

  @override
  String get bookingPhoneLabel => 'Phone';

  @override
  String get bookingValidEmail => 'Enter a valid email';

  @override
  String get bookingValidPhone => 'Enter a valid phone';

  @override
  String get groupsCreateTrip => 'Create a group trip';

  @override
  String get groupsPlanTogether => 'Plan together, decide together';

  @override
  String get carIdleBody => 'Compare car rentals at pickup points worldwide';

  @override
  String get carNoMatchesBody =>
      'Try widening the price range or clearing filters';

  @override
  String get carNoCarsBody => 'Try a different location or dates';

  @override
  String get offlineShowingCached =>
      'You are offline — showing the last saved data';

  @override
  String get homeCompleteYourTrip => 'Complete your trip';

  @override
  String get homeFinishWhatYouStarted => 'Finish what you started';

  @override
  String homeForYourTripTo(Object destination) {
    return 'For your trip to $destination';
  }

  @override
  String homeBecauseYouViewed(Object title) {
    return 'Because you viewed $title';
  }

  @override
  String get homePicksRelatedToWhatYouSaw => 'Picks related to what you saw';

  @override
  String get homePickedForYou => 'Picked for you';

  @override
  String get homeBasedOnYourProfile => 'Based on your profile';

  @override
  String get homeBasedOnRecentSearches => 'Based on your recent searches';

  @override
  String get homeBasedOnWhatYouViewed => 'Based on what you viewed';

  @override
  String get homeYourFavoritesFirst => 'Your favourites first';

  @override
  String get homeMatchedToYourPreferences => 'Matched to your preferences';

  @override
  String get homeForYourUpcomingTrip => 'For your upcoming trip';

  @override
  String get homePopularNearYou => 'Popular near you';

  @override
  String get homeBecauseYouViewedThis => 'Because you viewed this';

  @override
  String get tripCancelBooking => 'Cancel booking';

  @override
  String get tripCancelTitle => 'Cancel this booking?';

  @override
  String get tripCancelBody =>
      'The provider decides whether this booking can be cancelled. If it cannot, it will say why.';

  @override
  String get tripCancelConfirm => 'Cancel booking';

  @override
  String get tripCancelKeep => 'Keep booking';

  @override
  String get tripCancelled => 'Booking cancelled';

  @override
  String get profileGuestSavedPlaces => 'Saved places';

  @override
  String get profileGuestSavedPlacesBody =>
      'The stays you saved with the heart are on this device — no account needed.';

  @override
  String get retry => 'Retry';

  @override
  String get addOnsProviderTitle => 'Add-ons are priced by the provider';

  @override
  String get addOnsProviderBody =>
      'Extra bags, seats and meals are sold by the airline for your specific fare. They will appear here with the airline\'s own prices once that feed is connected — we never estimate a price.';

  @override
  String get notificationsEmptyTitle => 'No notifications yet';

  @override
  String get notificationsEmptyBody =>
      'Booking updates, price alerts and check-in reminders will appear here once they really happen. We don\'t invent them.';

  @override
  String get notificationToday => 'Today';

  @override
  String get notificationEarlier => 'Earlier';

  @override
  String get notificationUnread => 'Unread';

  @override
  String get wishlistEmptyTitle => 'Nothing saved yet';

  @override
  String get wishlistEmptyBody =>
      'Tap the heart on a hotel, flight or package to keep it here. Saved items show the provider\'s own price.';

  @override
  String wishlistSavedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved',
      one: '1 saved',
    );
    return '$_temp0';
  }

  @override
  String get wishlistExploreStays => 'Explore stays';

  @override
  String get groupsEmptyTitle => 'Group trips are coming soon';

  @override
  String get groupsEmptyBody =>
      'Creating a trip, inviting friends and splitting the plan will open here once the group trips backend is connected.';

  @override
  String get exploreCitiesTitle => 'Cities for your mood';

  @override
  String get createNewTrip => 'Create a new trip';

  @override
  String get tripBuilderTitle => 'Plan your trip';

  @override
  String get tripBuilderCancel => 'Cancel trip planning';

  @override
  String get tripBuilderStartFromHome => 'Start by choosing a city from Home.';

  @override
  String get tripBuilderAddProducts => 'Add to your trip';

  @override
  String get tripBuilderSelected => 'Your trip selections';

  @override
  String get tripBuilderEmpty =>
      'Choose a hotel, flight, or car to add it here.';

  @override
  String get tripBuilderRemove => 'Remove from trip';

  @override
  String get tripBuilderTotal => 'Current total';

  @override
  String get tripBuilderTotalNote =>
      'This total adds the selected offers. Providers may use different currencies, and each item is booked and paid through its provider.';

  @override
  String get tripBuilderAddToTrip => 'Add to trip';

  @override
  String get homeEmptyTitle => 'No recommendations right now';

  @override
  String get homeEmptyBody =>
      'We don\'t have hotels to suggest yet. Search a destination instead — or try again in a moment.';

  @override
  String get homeErrorTitle => 'We couldn\'t reach the travel service';

  @override
  String get homeErrorBody =>
      'Your connection or the provider may be having a moment. Nothing is lost — try again.';

  @override
  String get checkoutNoBookingTitle => 'This booking isn\'t ready to pay for';

  @override
  String get checkoutNoBookingBody =>
      'There is no prepared booking for this trip, so there is nothing to charge. Go back to the booking review and prepare it again.';

  @override
  String get checkoutProviderPrice => 'Trip price (from the provider)';

  @override
  String get paymentFailedBody =>
      'Your payment was not completed, so nothing was booked and nothing was charged.';

  @override
  String get paymentUnavailableBody =>
      'Payment is not available right now, so nothing was booked. Please try again later.';

  @override
  String get paymentPendingBody =>
      'Your bank is still verifying this payment. The booking will be confirmed as soon as the payment completes.';

  @override
  String get bookingConfirmFailedBody =>
      'The payment was not completed, so the booking was not confirmed. Nothing was booked.';

  @override
  String get bookingConfirmLabel => 'Confirm booking';

  @override
  String payAmount(String amount) {
    return 'Pay $amount';
  }

  @override
  String get confirmationNoneTitle => 'No confirmed booking to show';

  @override
  String get confirmationNoneBody =>
      'This screen shows the booking the provider actually confirmed. Nothing is confirmed for this trip yet.';

  @override
  String get bookingConfirmedTitle => 'Booking confirmed';

  @override
  String get confirmationSubtitle =>
      'Keep this reference to manage your booking with the provider.';

  @override
  String get confirmationCopyReference => 'Copy booking reference';

  @override
  String get confirmationCopied => 'Copied';

  @override
  String get confirmationDeparture => 'Departure';

  @override
  String get confirmationArrival => 'Arrival';

  @override
  String get bookingReferenceLabel => 'Booking reference';

  @override
  String get bookingStatusConfirmed => 'Confirmed';

  @override
  String get statusLabel => 'Status';

  @override
  String get bookingTravellersLabel => 'Travellers';

  @override
  String get bookingBackHome => 'Back to home';

  @override
  String get flightSearchSubtitle => 'Search flights across providers';

  @override
  String get tripTypeOneWay => 'One-way';

  @override
  String get tripTypeMultiCity => 'Multi-city';

  @override
  String get flightAddLeg => 'Add another leg';

  @override
  String get flightRemoveLeg => 'Remove leg';

  @override
  String flightLegLabel(int n) {
    return 'Leg $n';
  }

  @override
  String get flightLegsIncomplete => 'Fill in every leg before searching';

  @override
  String get flightLegsMax => 'A multi-city trip can have up to 6 legs';

  @override
  String get tripTypeRoundTrip => 'Round-trip';

  @override
  String get fieldFrom => 'From';

  @override
  String get fieldTo => 'To';

  @override
  String get fieldDeparture => 'Departure';

  @override
  String get fieldReturn => 'Return';

  @override
  String get selectAirport => 'Select airport';

  @override
  String get selectAction => 'Select';

  @override
  String get pickDateHint => 'Select date';

  @override
  String get swapRoute => 'Swap origin and destination';

  @override
  String get cabinEconomy => 'Economy';

  @override
  String passengersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count passengers',
      one: '1 passenger',
    );
    return '$_temp0';
  }

  @override
  String get sortRecommended => 'Recommended';

  @override
  String get sortCheapest => 'Cheapest';

  @override
  String get sortFastest => 'Fastest';

  @override
  String get sortLongest => 'Longest';

  @override
  String get filtersAction => 'Filters';

  @override
  String get filtersReset => 'Reset';

  @override
  String get filtersApply => 'Apply filters';

  @override
  String get filterPriceRange => 'Price range';

  @override
  String get filterHotelClass => 'Hotel class';

  @override
  String get filterGuestScore => 'Guest score';

  @override
  String get filterStops => 'Stops';

  @override
  String get filterDirect => 'Direct';

  @override
  String get filterAny => 'Any';

  @override
  String get filterAirlines => 'Airlines';

  @override
  String get flightIdleTitle => 'Find your flight';

  @override
  String get flightIdleBody =>
      'Compare fares across airlines for your next trip';

  @override
  String get flightEmptyTitle => 'No flights found';

  @override
  String get flightEmptyBody => 'Try different dates or nearby airports';

  @override
  String get searchFilteredEmptyTitle => 'No matches for your filters';

  @override
  String searchBudgetCap(Object amount, Object currency) {
    return 'Up to $amount $currency';
  }

  @override
  String searchBudgetNoCurrency(Object amount) {
    return 'Budget $amount has no currency — not applied';
  }

  @override
  String get searchBudgetRemove => 'Remove the budget filter';

  @override
  String get searchBudgetApply => 'Apply the budget filter';

  @override
  String searchBudgetNotApplicable(Object currency) {
    return 'Budget not applied — the listed prices are in $currency';
  }

  @override
  String get searchFilteredEmptyBody =>
      'Try widening the price range or clearing filters';

  @override
  String get searchErrorTitle => 'Connection error';

  @override
  String get searchErrorBody => 'Something went wrong. Please try again.';

  @override
  String get pickerFromTitle => 'From where?';

  @override
  String get pickerSearchHint => 'Search…';

  @override
  String get pickerNoMatches => 'No matches';

  @override
  String get flightRouteRequired =>
      'Choose where you are flying from and to first.';

  @override
  String get hotelDestination => 'Destination';

  @override
  String get hotelIdleTitle => 'Find your perfect stay';

  @override
  String get hotelIdleBody =>
      'Enter a destination and your dates to see available rooms.';

  @override
  String get hotelEmptyTitle => 'No hotels found';

  @override
  String get hotelEmptyBody => 'Try a different destination or dates';

  @override
  String get hotelDestinationRequired => 'Enter a destination first.';

  @override
  String get hotelSortTopRated => 'Top rated';

  @override
  String get hotelRatingAll => 'All';

  @override
  String get hotelLoading => 'Loading hotel';

  @override
  String get hotelFreeCancellation => 'Free cancellation';

  @override
  String hotelNightsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nights',
      one: '1 night',
    );
    return '$_temp0';
  }

  @override
  String hotelGuestsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count guests',
      one: '1 guest',
    );
    return '$_temp0';
  }

  @override
  String hotelRoomsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rooms',
      one: '1 room',
    );
    return '$_temp0';
  }

  @override
  String cityStaysCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stays',
      one: '1 stay',
    );
    return '$_temp0';
  }

  @override
  String get discoverTitle => 'Discover';

  @override
  String get discoverMore => 'Discover more';

  @override
  String hotelResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stays',
      one: '1 stay',
    );
    return '$_temp0';
  }

  @override
  String get editSearch => 'Edit search';

  @override
  String hotelStarClass(Object count) {
    return '$count star hotels';
  }

  @override
  String get sortBy => 'Sort by';

  @override
  String hotelRatingSemantics(Object rating, Object count) {
    return '$rating stars, $count reviews';
  }

  @override
  String get unitNight => 'night';

  @override
  String get unitDay => 'day';

  @override
  String get unitPerson => 'person';

  @override
  String get cardTotalLabel => 'total';

  @override
  String get cardFromLabel => 'from';

  @override
  String cardSaveLabel(Object amount) {
    return 'Save $amount';
  }

  @override
  String get cardTaxesIncludedLabel => 'Taxes included';

  @override
  String get cardTaxesExtraLabel => 'Taxes extra';

  @override
  String cardPerUnitSemantics(Object unit, Object amount, Object currency) {
    return 'Per $unit $amount $currency';
  }

  @override
  String cardPerUnitLabel(Object unit) {
    return '/$unit';
  }

  @override
  String cardTotalSemantics(Object amount, Object currency) {
    return 'Total $amount $currency';
  }

  @override
  String get offerAbout => 'About';

  @override
  String get offerAmenities => 'Amenities';

  @override
  String get offerAircraft => 'Aircraft';

  @override
  String get offerBaggage => 'Baggage';

  @override
  String get offerBoard => 'Board';

  @override
  String get offerCabin => 'Cabin';

  @override
  String get offerCancellation => 'Cancellation policy';

  @override
  String get offerCarType => 'Type';

  @override
  String get offerCheckIn => 'Check-in';

  @override
  String get offerCheckOut => 'Check-out';

  @override
  String get offerDestination => 'Destination';

  @override
  String get offerDuration => 'Duration';

  @override
  String get offerFare => 'Fare';

  @override
  String get offerFeatures => 'Features';

  @override
  String get offerInclusions => 'Inclusions';

  @override
  String get offerMileage => 'Mileage';

  @override
  String get offerNonRefundableRate => 'Non-refundable rate';

  @override
  String get offerPickup => 'Pickup';

  @override
  String get offerDropOff => 'Drop-off';

  @override
  String get offerPrice => 'Price';

  @override
  String get offerPriceNote =>
      'This is the provider\'s own total. We add nothing to it.';

  @override
  String get offerProvider => 'Provider';

  @override
  String get offerRating => 'Rating';

  @override
  String get offerRefundable => 'Refundable';

  @override
  String get offerRefundableRate => 'Refundable rate';

  @override
  String get offerRefundableYes => 'Yes';

  @override
  String get offerRevalidated => 'Revalidated at booking';

  @override
  String get offerRoom => 'Room';

  @override
  String get offerSeats => 'Seats';

  @override
  String get offerStars => 'Stars';

  @override
  String get offerTaxesFees => 'Taxes & fees';

  @override
  String get offerTotalFromProvider => 'Total (from the provider)';

  @override
  String get offerTransmission => 'Transmission';

  @override
  String get offerBadgeCheapest => 'Cheapest';

  @override
  String get offerBadgeFastest => 'Fastest';

  @override
  String get offerBadgeBestValue => 'Best value';

  @override
  String get offerWarningSelfTransfer => 'Self-transfer';

  @override
  String get offerWarningAirportChange => 'Airport change';

  @override
  String get offerWarningRiskyConnection => 'Risky connection';

  @override
  String get offerWarningOvernight => 'Overnight';

  @override
  String get offerWarningLongLayover => 'Long layover';

  @override
  String get offerLoadingFlight => 'Loading flight';

  @override
  String get offerSaved => 'Saved';

  @override
  String get offerTaxesIncluded => '(included in price)';

  @override
  String offerReviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
    );
    return '$_temp0';
  }

  @override
  String get offerPerNightStated => 'the provider\'s own rate';

  @override
  String offerPerNightDerived(Object nights) {
    return 'provider total ÷ $nights';
  }

  @override
  String get offerCheckAvailability => 'Check availability';

  @override
  String offerDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String offerStopsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stops',
      one: '1 stop',
      zero: 'Non-stop',
    );
    return '$_temp0';
  }

  @override
  String offerStopsWithAirport(Object airport) {
    return '1 stop ($airport)';
  }

  @override
  String offerLayover(Object duration) {
    return '$duration layover';
  }

  @override
  String offerSeatsLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Only $count seats left',
      one: 'Only 1 seat left',
    );
    return '$_temp0';
  }

  @override
  String offerCardTotal(Object amount) {
    return 'total $amount';
  }

  @override
  String offerFreeCancellationUntil(Object date) {
    return 'Free cancellation until $date';
  }

  @override
  String offerCancellationFeeNote(Object fee) {
    return 'Cancellation fee after that: $fee';
  }

  @override
  String offerSemanticsFlightRoute(Object origin, Object destination) {
    return 'Flight from $origin to $destination';
  }

  @override
  String offerSemanticsFlightNumber(Object number) {
    return 'Flight $number';
  }

  @override
  String offerSemanticsDeparts(Object time) {
    return 'Departs at $time';
  }

  @override
  String offerSemanticsArrives(Object time) {
    return 'Arrives at $time';
  }

  @override
  String offerSemanticsDuration(Object duration) {
    return 'Duration $duration';
  }

  @override
  String offerSemanticsPrice(Object amount) {
    return 'Price $amount';
  }

  @override
  String offerSemanticsTotal(Object amount) {
    return 'Total $amount';
  }

  @override
  String get locationPromptTitle =>
      'Use your location for the right departure airport';

  @override
  String get locationPromptBody =>
      'We read your country once to suggest a departure airport. Your precise location is not saved in the app.';

  @override
  String get locationPromptAllow => 'Allow location';

  @override
  String get locationPromptNotNow => 'Not now';

  @override
  String get locationPromptBlockedTitle => 'Location is blocked';

  @override
  String get locationPromptBlockedBody =>
      'Allow location for TokiGo in the system settings to suggest your departure airport.';

  @override
  String get locationPromptOpenSettings => 'Open settings';

  @override
  String get locationPromptServiceOffTitle => 'Location services are off';

  @override
  String get locationPromptServiceOffBody =>
      'Turn on location services to suggest your departure airport.';

  @override
  String get locationPromptLocationSettings => 'Location settings';

  @override
  String get locationChooseCountry => 'Choose country manually';

  @override
  String get locationCountrySaveFailed =>
      'Couldn\'t save your country. Please try again.';

  @override
  String get settingsCountry => 'Country';

  @override
  String get settingsCountryNotSet => 'Choose a country';
}
