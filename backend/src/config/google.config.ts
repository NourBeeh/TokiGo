import { registerAs } from '@nestjs/config';

/// Google Sign-In configuration.
///
/// `GOOGLE_CLIENT_ID` is a comma-separated list of the OAuth *client IDs* whose
/// ID tokens this API accepts as proof of identity. In practice this is the
/// **web** OAuth client ID (the Android/iOS clients request their ID token
/// against it via `serverClientId`), plus any additional audience you rotate in.
///
/// Leaving it empty disables Google sign-in entirely: `/auth/google` then fails
/// closed with 503 instead of accepting an unverified credential.
export default registerAs('google', () => {
  const clientIds = (process.env.GOOGLE_CLIENT_ID ?? '')
    .split(',')
    .map((id) => id.trim())
    .filter((id) => id.length > 0);

  return { clientIds, enabled: clientIds.length > 0 };
});
