# Google Sign-In

The app never sees or stores a Google password. The platform SDK returns a
Google-signed **ID token**, the app posts that token to `POST /auth/google`, the
backend verifies it and issues its own access/refresh pair. Nothing about the
user is trusted from the client.

```
Flutter (Credential Manager)  ──idToken──▶  POST /auth/google  ──▶  JWT pair
                                    (verified: signature, issuer,
                                     audience, expiry, verified email)
```

## 1. Google Cloud Console (one-time)

1. Create (or pick) a project at <https://console.cloud.google.com>.
2. **APIs & Services → OAuth consent screen**: User type *External*, app name,
   support email. While the app is in *Testing*, every account that may sign in
   must be added under **Test users**.
3. **Credentials → Create credentials → OAuth client ID → Android**
   - Package name: `com.tokigo.tokigo`
   - SHA-1: the fingerprint of the signing key. Debug keystore:

     ```bash
     keytool -list -v -keystore "$HOME/.android/debug.keystore" \
       -alias androiddebugkey -storepass android -keypass android
     ```

     A release keystore has a different fingerprint — register it too, or
     release builds fail with `clientConfigurationError`.
4. **Credentials → Create credentials → OAuth client ID → Web application**.
   No redirect URI is needed for the ID-token flow. Copy its client ID
   (`…apps.googleusercontent.com`); it is the **audience** everything else uses.

A client ID is a public identifier, not a secret. The client *secret* is never
used by this app and must not be committed.

## 2. Backend

```bash
# backend/.env
GOOGLE_CLIENT_ID=<web client id>[,...]   # comma-separate extra audiences
```

Rebuild and restart (`npm run build && node dist/main.js`). Empty
`GOOGLE_CLIENT_ID` disables the endpoint: `POST /auth/google` answers `503`
rather than accepting an unverified credential.

## 3. Flutter

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>
```

`google_auth_config.dart` also accepts the value pasted into its `defaultValue`
for plain `flutter run`/device runs. The "Continue with Google" control renders
only when a client ID was built in — no dead button.

## Behaviour worth knowing

- **First sign-in** creates the account (`users.google_id` = Google `sub`,
  no password hash) and signs in.
- **Returning sign-in** matches on `google_id` or on the email, case-insensitively.
- **An email that already has a password account is refused** (`409`). Without
  email verification, silently attaching Google to such an account would let
  whoever registered that address first keep a working credential on it. The
  UI tells the user to sign in with their password.
- Unverified Google emails, inactive accounts, and tokens failing
  signature/audience/issuer/expiry checks are all `401` with a generic message.
