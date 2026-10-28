import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserProfile } from '../../database/entities/user_profile.entity';

export interface ProfileView {
  userId: string;
  preferences: Record<string, any>;
  derived: Record<string, any>;
  countryCode?: string;
  countryConfidence?: string;
  personalizationEnabled: boolean;
  updatedAt: Date;
}

@Injectable()
export class ProfileService {
  constructor(
    @InjectRepository(UserProfile)
    private readonly profiles: Repository<UserProfile>,
  ) {}

  /** Returns the user's profile, creating a sensible default on first use. */
  async getOrCreate(userId: string): Promise<UserProfile> {
    const existing = await this.profiles.findOne({ where: { userId } });
    if (existing) return existing;
    const created = await this.profiles.save(
      this.profiles.create({ userId }),
    );
    return created;
  }

  async getView(userId: string): Promise<ProfileView> {
    const profile = await this.getOrCreate(userId);
    return this.toView(profile);
  }

  /** Merges explicit preferences (deep merge of scalar + array patch). */
  async updatePreferences(
    userId: string,
    patch: { preferences?: Record<string, any>; personalizationEnabled?: boolean },
  ): Promise<ProfileView> {
    const profile = await this.getOrCreate(userId);
    if (patch.preferences !== undefined) {
      profile.preferences = {
        ...(profile.preferences ?? {}),
        ...patch.preferences,
      };
    }
    if (patch.personalizationEnabled !== undefined) {
      profile.personalizationEnabled = patch.personalizationEnabled;
    }
    const saved = await this.profiles.save(profile);
    return this.toView(saved);
  }

  /** Engine-side update used by the events aggregator (not exposed publicly). */
  async updateDerived(
    userId: string,
    derived: Record<string, any>,
  ): Promise<UserProfile> {
    const profile = await this.getOrCreate(userId);
    profile.derived = { ...(profile.derived ?? {}), ...derived };
    return this.profiles.save(profile);
  }

  async setCountry(
    userId: string,
    countryCode: string,
    confidence: string,
  ): Promise<UserProfile> {
    const profile = await this.getOrCreate(userId);
    profile.countryCode = countryCode;
    profile.countryConfidence = confidence;
    return this.profiles.save(profile);
  }

  /** Updates the country only when the new detection is more confident. */
  async setCountryIfMoreConfident(
    userId: string,
    countryCode: string,
    confidence: string,
  ): Promise<UserProfile> {
    const profile = await this.getOrCreate(userId);
    const order = { low: 0, medium: 1, high: 2 } as const;
    const current = (profile.countryConfidence as keyof typeof order) ?? 'low';
    const incoming = confidence as keyof typeof order;
    if (order[incoming] >= order[current]) {
      profile.countryCode = countryCode;
      profile.countryConfidence = confidence;
      return this.profiles.save(profile);
    }
    return profile;
  }

  async findByCountry(countryCode: string): Promise<UserProfile[]> {
    return this.profiles.find({ where: { countryCode } });
  }

  private toView(profile: UserProfile): ProfileView {
    if (!profile) throw new NotFoundException('Profile not found.');
    return {
      userId: profile.userId,
      preferences: profile.preferences ?? {},
      derived: profile.derived ?? {},
      countryCode: profile.countryCode,
      countryConfidence: profile.countryConfidence,
      personalizationEnabled: profile.personalizationEnabled ?? true,
      updatedAt: profile.updatedAt,
    };
  }
}
