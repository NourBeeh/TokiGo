import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/**
 * Optional JWT authentication.
 *
 * A valid bearer token is resolved and attached to `request.user`; a missing or
 * invalid token is NOT an error — the route handler decides what an anonymous
 * caller may do.
 *
 * This exists because `POST /offers/revalidate` has two legitimate anonymous
 * callers in the current mobile client:
 *   - the Home live-validation pass, which runs before sign-in; and
 *   - `OfferRevalidationService`, which posts without an Authorization header.
 *
 * Rather than break those flows, the guard makes identity available when a
 * token is present, and the controller gates the operations that must never be
 * anonymous (the Nuitee hotel prebook, which creates a real inventory hold).
 */
@Injectable()
export class OptionalJwtAuthGuard extends AuthGuard('jwt') {
  handleRequest<TUser = unknown>(
    _err: unknown,
    user: TUser | undefined,
  ): TUser | undefined {
    // Returning undefined (instead of throwing) lets the request through with
    // `request.user` unset.
    return user ?? undefined;
  }
}
