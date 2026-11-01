import {
  Injectable,
  Logger,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OAuth2Client, TokenPayload } from 'google-auth-library';

/// The subset of a verified Google ID token this API relies on.
export interface GoogleProfile {
  /// Google account id (`sub`) — stable, never reused.
  subject: string;
  email: string;
  emailVerified: boolean;
  displayName?: string;
  pictureUrl?: string;
}

const GENERIC_ERROR = 'Invalid Google credential.';

/// Verifies a Google-issued OIDC ID token and returns its claims.
///
/// Verification is delegated to `google-auth-library`, which checks the
/// signature against Google's rotating JWKS **and** the token's issuer,
/// audience and expiry. The audience list comes from `GOOGLE_CLIENT_ID`, so a
/// token minted for another application is rejected.
@Injectable()
export class GoogleTokenVerifier {
  private readonly logger = new Logger(GoogleTokenVerifier.name);
  private readonly client = new OAuth2Client();

  constructor(private readonly config: ConfigService) {}

  async verify(idToken: string): Promise<GoogleProfile> {
    const audiences = this.config.get<string[]>('google.clientIds') ?? [];
    if (audiences.length === 0) {
      // Fail closed: without a configured audience there is nothing to verify
      // the token against, so no Google credential can be trusted.
      throw new ServiceUnavailableException(
        'Google sign-in is not configured on this server.',
      );
    }

    let payload: TokenPayload | undefined;

    try {
      const ticket = await this.client.verifyIdToken({
        idToken,
        audience: audiences.length === 1 ? audiences[0] : audiences,
      });
      payload = ticket.getPayload() ?? undefined;
    } catch (error) {
      // Never surface library detail (key ids, clock skew, claims) to callers.
      this.logger.warn(
        `Google ID token rejected: ${
          error instanceof Error ? error.message : 'unknown error'
        }`,
      );
      throw new UnauthorizedException(GENERIC_ERROR);
    }

    if (!payload?.sub || !payload.email) {
      throw new UnauthorizedException(GENERIC_ERROR);
    }

    return {
      subject: payload.sub,
      email: payload.email.trim().toLowerCase(),
      emailVerified: payload.email_verified === true,
      displayName: payload.name,
      pictureUrl: payload.picture,
    };
  }
}
