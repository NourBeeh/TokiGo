import {
  Body,
  Controller,
  Get,
  Patch,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Request } from 'express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { UpdateProfilePreferencesDto } from '../../common/dto/profile.dto';
import { ProfileService } from './profile.service';
import { DerivedPreferenceProfileService } from '../memory/derived_preference_profile.service';
import { ExplicitPreferenceSignalService } from '../memory/explicit_preference_signal.service';

/**
 * User profile for personalization (workstream R). Requires a valid JWT.
 * Guards read the user id from the request (JwtStrategy attaches the entity).
 */
@UseGuards(JwtAuthGuard)
@Controller('profile')
export class ProfileController {
  constructor(
    private readonly profileService: ProfileService,
    private readonly derivedService: DerivedPreferenceProfileService,
    private readonly explicitSignalService: ExplicitPreferenceSignalService,
  ) {}

  @Get('me')
  async me(@Req() req: Request) {
    const view = await this.profileService.getView(userId(req));
    // Phase 2B — attach the computed Derived Preference Profile (additive,
    // backward-compatible field). buildForUserSafe degrades to an empty
    // profile on failure, so /profile/me can never break because of it.
    // PH-7 — attach the separate Explicit Preference Signal (also additive,
    // null when personalization is disabled / no signal / on failure). This
    // is the ONLY place explicit conversation memories may influence Home
    // Ranking; DerivedPreferenceProfile semantics stay untouched.
    return {
      ...view,
      derivedPreferences: await this.derivedService.buildForUserSafe(
        userId(req),
        view,
      ),
      explicitPreferences: await this.explicitSignalService.buildForUserSafe(
        userId(req),
        view.personalizationEnabled,
      ),
    };
  }

  @Patch('me')
  async update(@Req() req: Request, @Body() dto: UpdateProfilePreferencesDto) {
    const id = userId(req);
    if (dto.countryCode) {
      await this.profileService.setCountryIfMoreConfident(
        id,
        dto.countryCode.toUpperCase(),
        dto.countryConfidence ?? 'low',
      );
    }
    if (dto.preferences !== undefined || dto.personalizationEnabled !== undefined) {
      return this.profileService.updatePreferences(id, dto);
    }
    return this.profileService.getView(id);
  }
}

/** Passport's Express.User is an empty interface; the JWT strategy attaches
 * the full user entity, so the id is safely readable here. */
function userId(req: Request): string {
  const user = req.user as { id?: string } | undefined;
  if (!user?.id) throw new Error('Authenticated request missing user id.');
  return user.id;
}
